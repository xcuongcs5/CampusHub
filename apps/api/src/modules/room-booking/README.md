# Room Booking module

Module NestJS này độc lập với Flutter và hiện triển khai lớp domain/application đầu tiên.

## Cấu trúc

```text
room-booking/
|-- domain/
|   |-- booking-time-range.ts
|   |-- money.ts
|   |-- room-booking.aggregate.ts
|   |-- room-booking.errors.ts
|   `-- room-booking.types.ts
|-- application/
    |-- request-room-booking.use-case.ts
    `-- room-booking.ports.ts
`-- infrastructure/
    |-- prisma-json.codec.ts
    `-- prisma-room-booking-unit-of-work.ts
```

Domain không import NestJS, Prisma, HTTP hoặc SDK thanh toán. Application chỉ phụ thuộc các
port. Prisma/PostgreSQL adapter hiện thực transaction, idempotency, repository và outbox.

## RequestRoomBooking

Use case hiện tại thực hiện:

1. kiểm tra operation key và tạo request fingerprint;
2. chạy trong idempotent unit of work;
3. khóa quota của Booker và kiểm tra eligibility;
4. đọc Room/Policy, kiểm tra active booking limit;
5. tạo aggregate và claim Time Block;
6. lưu Booking + outbox atomically;
7. khởi tạo Payment sau commit nếu phòng có phí;
8. compensation hold và idempotent operation nếu Payment initialization thất bại.

## Kiểm thử

Unit test không cần database:

```bash
npm test -- --runInBand
```

Integration test chỉ được phép chạy trên database tên `campus_hub_test`:

```bash
npm run test:integration
```

## Chưa triển khai trong source runtime

- Payment adapter;
- REST controller và Problem Details mapper;
- cancel/check-in/revoke/scheduler use cases;
- module wiring/dependency injection cho runtime.

