# Room Booking Physical PostgreSQL Design

> Trạng thái: physical schema v1 cho vertical slice Room Booking.
>
> Artifacts:
>
> - Prisma mapping: `apps/api/prisma/schema.prisma`
> - Migration: `apps/api/prisma/migrations/20261014000100_room_booking_foundation/migration.sql`

## 1. Quyết định vật lý

| Chủ đề | Quyết định |
|---|---|
| PostgreSQL | Version 16 |
| ID | UUID do PostgreSQL tạo bằng `gen_random_uuid()` |
| Time | `timestamptz(6)`, application truyền/nhận UTC |
| Time range | `tstzrange` nửa mở `[)` được trigger materialize từ `starts_at`, `ends_at` |
| Money | `bigint amount_minor` + `char(3) currency` |
| Policy snapshot | `jsonb` immutable, có `snapshot_schema_version` |
| Optimistic concurrency | Integer `version` trên Room, Time Block và Booking |
| ORM | Prisma cho mapping/query thông thường |
| Constraint nâng cao | Custom SQL migration, không cố mô phỏng bằng application code |
| Event delivery | Transactional outbox trong cùng PostgreSQL transaction |
| Isolation mặc định | `READ COMMITTED` + explicit row locks + constraint; retry lỗi concurrency |

## 2. Extension

Migration bật:

- `pgcrypto` cho `gen_random_uuid()`;
- `btree_gist` để kết hợp UUID equality và range overlap trong GiST.

Production role chạy migration cần quyền tạo extension, hoặc DBA phải provision trước.

## 3. Phân nhóm bảng

### Reference/Foundation

- `institutions`
- `campuses`
- `app_users`
- `rooms`
- `booking_policy_versions`

`app_users` là projection/reference tối thiểu, không thay thế toàn bộ Identity system.

### Availability

- `room_timeline_guards`
- `room_time_blocks`
- `room_check_in_credentials`

### Room Booking

- `room_bookings`
- `booking_actor_guards`
- `booking_status_history`
- `booking_check_ins`
- `booking_payment_references`

### Platform

- `idempotency_records`
- `outbox_messages`
- `audit_records`

## 4. Chống trùng lịch

PostgreSQL bảo vệ bằng ba lớp:

1. `room_timeline_guards` cung cấp row cố định để serialize mọi mutation timeline của Room.
2. Trigger `room_time_blocks_prepare_and_validate` khóa guard, materialize `tstzrange` và
   kiểm tra booking không overlap bất kỳ active block nào.
3. Exclusion constraint `room_time_blocks_no_booking_overlap` là defense-in-depth cho hai
   booking được ghi cạnh tranh.

Official Occupancy và Administrative Block có thể overlap nhau. Cả hai đều xung đột với
Booking. Mọi writer, kể cả import job, đi qua cùng trigger nên không phụ thuộc việc developer
nhớ gọi đúng service lock.

SQLSTATE `23P01` được mapper chuyển thành `ROOM_SLOT_UNAVAILABLE` hoặc
`CONCURRENT_MODIFICATION` tùy command context.

## 5. Giới hạn booking theo sinh viên

Mỗi `app_users` tự động có một `booking_actor_guards` row. Use case tạo hoặc kết thúc booking:

1. lock guard `FOR UPDATE`;
2. đếm booking trong `PENDING_PAYMENT`, `CONFIRMED`, `CHECKED_IN`;
3. áp dụng `active_booking_limit` từ policy;
4. ghi transition trong cùng transaction.

Không lưu counter để tránh drift. Index `(institution_id, booker_id, status, starts_at)` hỗ
trợ phép đếm và danh sách booking.

## 6. Tenant consistency

Mọi bảng nghiệp vụ có `institution_id`. Foreign key cơ bản bảo vệ resource tồn tại; custom
trigger bảo vệ các reference phải thuộc cùng trường:

- Room và Campus;
- Time Block và Room/Campus;
- Booking với Room, Campus, Booker, Policy và Time Block;
- history/check-in/payment reference với Booking.

Application vẫn bắt buộc thêm tenant predicate ở query. Trigger là safety net, không thay
thế authorization. Row-Level Security được hoãn cho đến khi mô hình multi-tenant production
được duyệt; nếu bật sau này, migration role và worker role phải có policy riêng.

## 7. Booking và Time Block 1:1

Ứng dụng sinh `booking_id` trước, sau đó trong một transaction:

1. insert Time Block với `source_type=ROOM_BOOKING` và `source_reference=booking_id`;
2. insert Booking tham chiếu `time_block_id`;
3. constraint trigger deferred xác minh institution, room, campus và time range giống nhau.

Deferred validation giải quyết thứ tự insert mà không bỏ integrity. Unique index trên booking
source và `room_bookings.time_block_id` bảo đảm quan hệ 1:1.

## 8. Check constraint quan trọng

- Time range có `starts_at < ends_at`.
- Active block không có `released_at`; released block bắt buộc có.
- Capacity, attendee count, version và policy limits hợp lệ.
- Money không âm và currency có ba chữ cái in hoa.
- `PENDING_PAYMENT` bắt buộc có `hold_expires_at`.
- Policy snapshot/outbox payload là JSON object.
- Check-in QR bắt buộc credential; staff override bắt buộc reason.
- Idempotency state và completion timestamp nhất quán.

State transition graph vẫn được domain enforce vì CHECK constraint không phù hợp để mô tả
lifecycle nhiều bước. Mỗi update dùng `WHERE id = ? AND version = ?` rồi tăng `version`.

## 9. Index strategy

### Availability

- Partial GiST trên active Time Block và `time_range`.
- B-tree theo institution/room/state và source reference.

### Student/Admin query

- Booker + status + starts_at.
- Campus/Room + time range + status.

### Worker

- Partial index cho `PENDING_PAYMENT` theo hold deadline.
- Partial index cho `CONFIRMED` theo starts_at để xử lý no-show.
- Partial index cho `CHECKED_IN` theo ends_at để complete.
- Partial index outbox `PENDING/FAILED` theo next attempt.

Worker claim batch bằng `FOR UPDATE SKIP LOCKED`, commit batch nhỏ và retry riêng từng item.

## 10. Prisma và custom SQL

Prisma không biểu diễn đầy đủ:

- GiST exclusion constraint;
- PostgreSQL trigger/function;
- partial index;
- append-only protection;
- `tstzrange` generated/materialized behavior.

Vì vậy:

- `time_range` được khai báo `Unsupported("tstzrange")?` trong Prisma;
- application không ghi trực tiếp field này;
- trigger luôn tạo range trước khi CHECK chạy;
- mọi migration phải dùng `prisma migrate ... --create-only`, review SQL rồi bổ sung custom SQL;
- không dùng `prisma db push` cho production hoặc shared environment;
- CI phải apply toàn bộ migration lên PostgreSQL sạch, sau đó chạy integration test.

Prisma `BigInt` không JSON-serialize trực tiếp. API mapper phải kiểm tra giá trị nằm trong
safe integer trước khi chuyển thành OpenAPI `integer amount_minor`.

## 11. Error mapping

| PostgreSQL signal | Application error |
|---|---|
| `23P01` overlap | `ROOM_SLOT_UNAVAILABLE` |
| unique idempotency key | replay kết quả hoặc `OPERATION_KEY_REUSED` sau khi so fingerprint |
| optimistic update count = 0 | `CONCURRENT_MODIFICATION` |
| `23514` domain/tenant check | internal mapping cụ thể; không trả raw SQL message |
| `23503` missing reference | validation/not-found tùy trust boundary |
| `40001` serialization failure | retry transaction có giới hạn |
| `40P01` deadlock | retry transaction có jitter; ghi metric |

Không trả constraint name, SQL hoặc nội dung exception database ra client.

## 12. Transaction và lock order

Thứ tự chuẩn:

```text
Idempotency Record
→ Booking Actor Guard
→ Room Timeline Guard
→ Room Booking
```

Transaction không cần một lock bỏ qua nó nhưng không đảo thứ tự còn lại. Không gọi network,
payment provider hoặc push service trong transaction.

## 13. Migration workflow

Development:

```powershell
cd apps/api
npm install
npx prisma validate
npx prisma migrate dev --create-only --name <change>
# review và bổ sung custom SQL
npx prisma migrate dev
```

Deployment:

```powershell
npx prisma migrate deploy
npx prisma generate
```

Migration đã deploy không được sửa. Thay đổi tiếp theo luôn tạo migration mới có forward fix.

## 14. Verification bắt buộc

Integration test trên PostgreSQL thật phải chứng minh:

1. Hai transaction đặt cùng phòng/slot chỉ một transaction thành công.
2. Booking xung đột Official Occupancy hoặc Admin Block bị từ chối.
3. Official và Admin Block được phép overlap nhau.
4. Hai request đồng thời của cùng sinh viên không vượt quota.
5. Release block và terminal transition là atomic.
6. Payment outcome, scheduler và idempotency retry không tạo transition trùng.
7. Cross-tenant reference bị từ chối ở database.
8. History và audit không update/delete được.
9. Outbox được ghi cùng transaction và worker claim không xử lý trùng.
10. Query plan availability/list/worker dùng index mong đợi.

## 15. Việc chưa làm trong migration này

- Seed dữ liệu thật của trường.
- RLS policy.
- Partition/archival.
- Payment ledger đầy đủ.
- Room feature/catalog và opening-hours schema đầy đủ.
- Import staging tables cho CSV/SIS.
- Database roles và grant production.

Các phần trên được thêm bằng migration độc lập sau khi vertical slice cơ bản chạy ổn định.

