# Domain model — chưa thiết kế

Tài liệu domain model chi tiết được chủ động hoãn cho đến khi bản phân rã nghiệp vụ được
duyệt. Việc này tránh khóa sớm hệ thống vào entity, bảng hoặc endpoint chưa phản ánh đúng
quy trình của nhà trường.

Thứ tự tài liệu:

1. [Phân rã nghiệp vụ](business-architecture.md)
2. [Kiến trúc phần mềm](architecture.md)
3. Domain model và state machine chi tiết
4. API contract
5. Database logical model
6. Database physical schema và migration

Domain model tổng thể ở bước 3 chỉ bắt đầu sau khi các quyết định P0 trong tài liệu nghiệp
vụ được chốt. Vertical slice đầu tiên đã được mô tả tại
[Room Booking Domain — MVP](room-booking-domain.md). Tài liệu này sẽ mở rộng dần sau khi
từng domain được duyệt; nó vẫn chưa chứa chi tiết HTTP hoặc cấu trúc bảng vật lý.

Application boundary của vertical slice đầu tiên nằm tại
[Room Booking Application Contract](room-booking-application-contract.md).

REST và logical persistence design nằm tại
[Room Booking REST API](room-booking-rest-api.md) và
[Room Booking Logical Data Model](room-booking-logical-data-model.md).

