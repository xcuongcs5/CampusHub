# Room Booking REST API v1 — Design

> Source of truth có thể đọc bởi công cụ nằm tại
> [`apps/api/openapi/room-booking.v1.yaml`](../apps/api/openapi/room-booking.v1.yaml).
>
> Tài liệu này giải thích các quyết định transport. Domain và application contract vẫn là
> nguồn quyết định nghiệp vụ; REST chỉ ánh xạ chúng sang HTTP.

## 1. Phạm vi

API v1 hỗ trợ:

- tìm phòng khả dụng;
- tạo và xem Room Booking;
- liệt kê booking của sinh viên hiện tại;
- hủy và check-in;
- nhân viên tra cứu, check-in ngoại lệ và thu hồi booking.

Không đưa vào API mobile/admin công khai:

- command hết hạn hold, no-show và hoàn thành của scheduler;
- kết quả thanh toán đã xác minh từ Payment module;
- outbox/domain event;
- thao tác trực tiếp với slot hoặc trạng thái Booking.

Các luồng trên gọi application contract nội bộ, không đi vòng qua REST public.

## 2. Quy ước chung

### Base path và version

```text
/api/v1
```

Breaking change tạo version mới. Thêm field optional hoặc enum được chuẩn bị trước có thể
được phát hành tương thích trong v1.

### Authentication

Mọi operation yêu cầu Bearer access token. Backend lấy actor, institution và quyền từ token
đã xác minh/session; không nhận các giá trị này từ request body.

### Thời gian và tiền

- Timestamp dùng RFC 3339 có timezone, production chuẩn hóa UTC.
- Khoảng thời gian dùng quy ước nửa mở `[starts_at, ends_at)`.
- Tiền dùng `amount_minor` là số nguyên và `currency`, không dùng floating point.

### Naming

- JSON field dùng `snake_case`.
- Resource URL dùng danh từ số nhiều.
- ID là opaque string; client không phân tích cấu trúc ID.

### Success response

Không bọc dữ liệu đơn trong envelope `data`. List response có `items` và `next_cursor`.
Response Booking trả `ETag` để hỗ trợ conditional request về sau.

### Error response

Dùng `application/problem+json`, tương thích RFC 9457:

```json
{
  "type": "https://campus-hub.example/problems/room-slot-unavailable",
  "title": "Room slot unavailable",
  "status": 409,
  "detail": "Khung giờ vừa được người khác đặt.",
  "code": "ROOM_SLOT_UNAVAILABLE",
  "correlation_id": "01J...",
  "errors": []
}
```

`code` là contract ổn định cho Flutter. `detail` dùng để hỗ trợ người dùng nhưng client
không điều khiển logic bằng cách so sánh message.

## 3. Endpoint sinh viên

| Method | Path | Application contract |
|---|---|---|
| `GET` | `/rooms/availability` | `SearchAvailableRooms` |
| `POST` | `/room-bookings` | `RequestRoomBooking` |
| `GET` | `/room-bookings/{booking_id}` | `GetRoomBooking` |
| `GET` | `/me/room-bookings` | `ListMyRoomBookings` |
| `POST` | `/room-bookings/{booking_id}/cancellation` | `CancelRoomBooking` |
| `POST` | `/room-bookings/{booking_id}/check-in` | `CheckInRoomBooking` |

### Tạo booking

`POST /room-bookings` nhận đúng dữ liệu do sinh viên lựa chọn:

```json
{
  "room_id": "room_opaque_id",
  "starts_at": "2026-10-20T02:00:00Z",
  "ends_at": "2026-10-20T04:00:00Z",
  "attendee_count": 4,
  "purpose": "Ôn thi giữa kỳ"
}
```

Request không nhận `booker_id`, giá, trạng thái, deadline hoặc institution. Response `201`
có thể là `CONFIRMED` với phòng miễn phí hoặc `PENDING_PAYMENT` với `payment_action`.

### Hủy dưới dạng subresource

Dùng `/cancellation` thay vì `PATCH status=CANCELLED` để thể hiện ý định nghiệp vụ, cho phép
gửi lý do và trả cancellation outcome. Client không được cập nhật trạng thái tùy ý.

### Check-in

QR cung cấp `room_check_in_token`. Server vẫn kiểm tra actor, room, trạng thái và cửa sổ
thời gian. Token không chứa dữ liệu cá nhân ở dạng đọc được.

## 4. Endpoint nhân viên

| Method | Path | Application contract |
|---|---|---|
| `GET` | `/admin/room-bookings` | `ListOperationalBookings` |
| `POST` | `/admin/room-bookings/{booking_id}/staff-check-in` | `StaffCheckInRoomBooking` |
| `POST` | `/admin/room-bookings/{booking_id}/revocation` | `RevokeRoomBooking` |

Prefix `/admin` không tự cấp quyền. Mỗi operation kiểm tra permission và campus scope.
Check-in ngoại lệ và revoke bắt buộc có lý do; revoke dùng reason code chuẩn để báo cáo.

## 5. Idempotency và retry

Mọi `POST` yêu cầu header:

```text
Idempotency-Key: <unique opaque key>
```

Quy tắc:

- cùng actor, operation và key với cùng request trả lại kết quả đã commit;
- dùng lại key với nội dung khác trả `409 OPERATION_KEY_REUSED`;
- Flutter giữ key khi retry do timeout/mất mạng, nhưng tạo key mới cho ý định mới;
- server lưu cả success và lỗi đã commit phù hợp trong khoảng retention;
- webhook/payment adapter có idempotency riêng theo provider reference.

`GET` vốn idempotent và không dùng header này.

## 6. Concurrency

- Search availability không giữ phòng.
- `POST /room-bookings` kiểm tra lại availability tại write boundary.
- Hai request cạnh tranh cùng slot: một request thành công, request còn lại nhận
  `409 ROOM_SLOT_UNAVAILABLE`.
- Booking response có `version` và `ETag`; v1 chưa bắt buộc Flutter gửi `If-Match` cho action.
- Application layer vẫn kiểm tra version/state và có thể trả `409 CONCURRENT_MODIFICATION`.

## 7. Pagination và filter

List dùng cursor opaque:

```text
?limit=20&cursor=<opaque>
```

- `limit` mặc định 20, tối đa 100.
- Cursor gắn với filter và sort; client không chỉnh sửa cursor.
- Thứ tự của booking sinh viên: `starts_at` giảm dần trong nhóm lịch sử và tăng dần trong
  nhóm sắp tới.
- Admin list yêu cầu khoảng thời gian để tránh truy vấn không giới hạn.

## 8. HTTP status mapping

| Status | Dùng khi |
|---:|---|
| `200` | Query hoặc action thành công |
| `201` | Booking được tạo |
| `400` | Request không parse được hoặc sai cú pháp cơ bản |
| `401` | Chưa xác thực/token không hợp lệ |
| `403` | Actor không có quyền |
| `404` | Resource không tồn tại hoặc không được phép biết nó tồn tại |
| `409` | Xung đột slot, state, version hoặc idempotency key |
| `422` | Request hợp lệ về cú pháp nhưng vi phạm policy nghiệp vụ |
| `429` | Vượt rate limit |
| `503` | Dependency tạm thời không khả dụng, ví dụ khởi tạo payment |

## 9. Correlation và observability

- Client có thể gửi `X-Correlation-Id`; server xác thực format hoặc tự sinh mới.
- Server luôn trả `X-Correlation-Id` ở success và error.
- Correlation ID đi qua Payment, Notification, worker và event envelope.
- Không dùng correlation ID làm idempotency key.

## 10. Cache

- Availability response dùng `Cache-Control: private, no-store` trong MVP vì thay đổi nhanh.
- Booking detail và list cũng `private, no-store`.
- Static room metadata có thể cache riêng ở module Facility sau này.
- CDN/proxy không được cache response chứa dữ liệu sinh viên.

## 11. Rate limit ban đầu

| Nhóm | Baseline |
|---|---:|
| Search availability | 60 request/phút/actor |
| Tạo booking | 10 request/phút/actor |
| Check-in/hủy | 20 request/phút/actor |
| Admin mutation | 30 request/phút/actor |

Giới hạn là cấu hình vận hành. Khi trả `429`, server gửi `Retry-After` nếu xác định được.

## 12. Security checklist

- Không nhận `institution_id`, `booker_id`, price hoặc permission từ mobile payload.
- Validate thời gian, độ dài `purpose`, `reason_detail` và token.
- Query luôn scope theo actor trước khi trả dữ liệu.
- Admin scope theo permission và campus.
- Không log access token, QR token, payment action hoặc raw personal payload.
- OpenAPI example không dùng dữ liệu thật.
- CORS chỉ cho origin được cấu hình; mobile vẫn cần token hợp lệ.

## 13. Quyết định chưa thuộc Room Booking API

- Payment provider callback được thiết kế trong Payment API, không thêm vào spec này.
- Import lịch CSV/Excel thuộc Facility/Integration API.
- CRUD Room và policy thuộc Admin/Facility API.
- Push token thuộc Notification/Device API.
- Các API trên được thiết kế sau mà không mở quyền cập nhật trực tiếp Booking.

## 14. Điều kiện hoàn thành REST design

- OpenAPI lint/validate thành công trong CI.
- Mọi operation có security, success và Problem Details response.
- Flutter có thể dựng client/mock từ spec mà không cần biết database.
- Application error code đều có HTTP mapping.
- Payment team xác nhận `payment_action` không làm lộ secret.
- Security review xác nhận scope sinh viên/nhân viên.
- Contract test được tạo trước khi implement controller.

