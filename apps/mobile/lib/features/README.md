# Features

Mỗi thư mục feature dùng layout `data/`, `domain/`, `presentation/` khi thật sự cần:

- `auth`
- `home`
- `rooms`
- `library`
- `events`
- `store`
- `payments`
- `profile`
- `notifications`

Feature giao tiếp qua domain contract hoặc app router; không import trực tiếp internals của nhau.

