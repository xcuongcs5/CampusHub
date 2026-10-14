# Authentication module

Authentication cho ứng dụng sinh viên, tách độc lập khỏi Flutter client.

## Endpoints

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

Access token là JWT có thời hạn 15 phút. Refresh token là opaque token có thời hạn 30 ngày,
được lưu dưới dạng SHA-256 và rotate sau mỗi lần sử dụng. Mật khẩu được băm bằng bcrypt cost 12.

`institutionCode` hiện là một phần của request vì backend hỗ trợ nhiều trường. Mobile client của
một trường cụ thể có thể cung cấp giá trị này từ public environment configuration thay vì yêu cầu
sinh viên nhập lại.

Chạy `npm run prisma:seed` để tạo dữ liệu phát triển idempotent với mã trường `CAMPUS`.
