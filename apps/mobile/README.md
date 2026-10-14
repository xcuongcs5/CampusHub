# Campus Hub Mobile

Project Flutter độc lập dành cho ứng dụng sinh viên.

## Ranh giới

- Chỉ chứa Dart/Flutter source, test, asset và cấu hình mobile.
- Không import hoặc tham chiếu source của NestJS backend.
- Giao tiếp backend qua REST API version hóa.
- Client/model có thể được generate từ OpenAPI nhưng thuộc project này.
- Có build number, release và CI/CD riêng.

## Demo hiện có

- Đăng nhập và đăng ký theo phong cách form card tối giản.
- Trang chủ và điều hướng 5 nhóm chức năng.
- Danh sách phòng, chọn khung giờ và xác nhận đặt phòng.
- Tìm sách và gửi yêu cầu chuẩn bị trước.
- Danh sách sự kiện và form đăng ký cá nhân/đội thi.
- Catalog vật phẩm và giỏ hàng mẫu.

Đăng nhập và đăng ký gọi NestJS API thật. Các feature còn lại hiện dùng dữ liệu cục bộ trong
`lib/demo/demo_data.dart`.

Android Emulator mặc định gọi `http://10.0.2.2:3000/api/v1`. Có thể đổi endpoint khi chạy:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 `
  --dart-define=INSTITUTION_CODE=CAMPUS
```

Với thiết bị Android thật, thay `10.0.2.2` bằng địa chỉ IPv4 LAN của máy chạy NestJS. Chỉ debug
build cho phép HTTP local; production phải sử dụng HTTPS.

## Mở bằng Android Studio

1. Chọn **Open** và mở trực tiếp thư mục `apps/mobile`.
2. Chờ Android Studio hoàn tất Gradle sync và Flutter pub get.
3. Chọn một Android Emulator hoặc thiết bị thật.
4. Chạy cấu hình `main.dart`.

## Phát triển bằng terminal

```powershell
flutter pub get
flutter test
flutter run
```

Không đặt credential hoặc backend secret trong ứng dụng. Base URL và public client config
được cung cấp theo từng flavor/environment.

