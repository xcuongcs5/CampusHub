# Campus Hub

Nền tảng mobile giúp trường đại học quản lý phòng học trống, yêu cầu giữ sách,
sự kiện sinh viên và cửa hàng vật phẩm thương hiệu.

## Quyết định kiến trúc

- Mobile: Flutter, tổ chức theo feature và Clean Architecture ở mức vừa đủ.
- Backend: NestJS modular monolith; chỉ thiết kế API sau khi chốt nghiệp vụ.
- Dữ liệu: PostgreSQL là nguồn dữ liệu chuẩn; Redis cho cache, lock và job có hạn.
- File: S3-compatible object storage cho ảnh sự kiện/sản phẩm.
- Thông báo: Firebase Cloud Messaging.
- Thanh toán: adapter để có thể dùng VNPay, MoMo hoặc cổng của nhà trường.
- Triển khai: Docker khi phát triển; dịch vụ managed khi production.

Thứ tự duyệt thiết kế hiện tại:

1. [Phân rã nghiệp vụ](docs/business-architecture.md)
2. [Kiến trúc phần mềm](docs/architecture.md)
3. [Room Booking domain cho MVP](docs/room-booking-domain.md)
4. [Room Booking application contract](docs/room-booking-application-contract.md)
5. [Domain model tổng thể — đang hoãn](docs/domain-model.md)
6. [Room Booking REST API design](docs/room-booking-rest-api.md)
7. [OpenAPI v1 source](apps/api/openapi/room-booking.v1.yaml)
8. [Room Booking logical data model](docs/room-booking-logical-data-model.md)
9. [Room Booking physical PostgreSQL design](docs/room-booking-postgresql-design.md)
10. [Prisma schema](apps/api/prisma/schema.prisma) và custom migration

## Cấu trúc repository

```text
.
|-- apps/
|   |-- mobile/                  # Project Flutter độc lập
|   `-- api/                     # Project NestJS độc lập
|-- docs/                        # Tài liệu duyệt kiến trúc/nghiệp vụ
`-- infrastructure/             # Docker cho local development
```

`apps/mobile` và `apps/api` là **hai project riêng**, không phải hai package phụ thuộc nhau:

- mỗi project có dependency manifest, source, test, environment và release lifecycle riêng;
- Flutter không import source TypeScript và NestJS không chứa source Dart;
- không tạo shared runtime package giữa hai project;
- giao tiếp duy nhất qua REST/OpenAPI đã version hóa;
- build, CI/CD và deployment độc lập;
- có thể tách mỗi thư mục thành Git repository riêng mà không đổi kiến trúc.

Root workspace chỉ giữ tài liệu và hạ tầng local phục vụ phát triển đồng thời. Nó không
biến hai ứng dụng thành một deployable unit.

## Bắt đầu sau khi duyệt kiến trúc

```powershell
# Hạ tầng local
docker compose -f infrastructure/docker-compose.yml up -d

# Backend
cd apps/api
npm install
npm run start:dev

# Mobile
cd apps/mobile
flutter pub get
flutter run
```

Project Android đã được generate trong `apps/mobile/android` và có thể mở trực tiếp
thư mục `apps/mobile` bằng Android Studio để chạy bản demo dữ liệu cục bộ.

