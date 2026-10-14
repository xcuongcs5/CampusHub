# Domain modules

Tạo các module độc lập theo ranh giới nghiệp vụ:

`identity`, `institutions`, `rooms`, `bookings`, `library`, `events`, `commerce`,
`payments`, `notifications`, `admin`, `integrations`.

Mỗi module sở hữu controller, application service/use case, domain model và persistence
adapter của mình. Không truy cập repository nội bộ của module khác; gọi public service
hoặc phát domain event qua transactional outbox.

Module đầu tiên đang được triển khai tại [room-booking](room-booking/README.md).

