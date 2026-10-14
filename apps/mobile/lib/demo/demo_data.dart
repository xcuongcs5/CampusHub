import 'package:flutter/material.dart';

class DemoRoom {
  const DemoRoom({
    required this.name,
    required this.building,
    required this.capacity,
    required this.price,
    required this.features,
    required this.availableSlots,
    required this.color,
    required this.icon,
  });

  final String name;
  final String building;
  final int capacity;
  final int price;
  final List<String> features;
  final List<String> availableSlots;
  final Color color;
  final IconData icon;
}

class DemoBook {
  const DemoBook({
    required this.title,
    required this.author,
    required this.category,
    required this.available,
    required this.color,
    required this.code,
  });

  final String title;
  final String author;
  final String category;
  final int available;
  final Color color;
  final String code;
}

class DemoEvent {
  const DemoEvent({
    required this.title,
    required this.date,
    required this.location,
    required this.category,
    required this.description,
    required this.isTeamEvent,
    required this.fee,
    required this.color,
    required this.icon,
  });

  final String title;
  final String date;
  final String location;
  final String category;
  final String description;
  final bool isTeamEvent;
  final int fee;
  final Color color;
  final IconData icon;
}

class DemoProduct {
  const DemoProduct({
    required this.name,
    required this.price,
    required this.category,
    required this.color,
    required this.icon,
  });

  final String name;
  final int price;
  final String category;
  final Color color;
  final IconData icon;
}

abstract final class DemoData {
  static const rooms = [
    DemoRoom(
      name: 'Phòng A-101',
      building: 'Tòa A · Tầng 1',
      capacity: 12,
      price: 20000,
      features: ['TV 65”', 'Bảng trắng', 'Điều hòa'],
      availableSlots: ['09:00', '10:30', '13:30'],
      color: Color(0xFF4C7DF0),
      icon: Icons.meeting_room_rounded,
    ),
    DemoRoom(
      name: 'Learning Space 3',
      building: 'Thư viện · Tầng 3',
      capacity: 8,
      price: 0,
      features: ['Màn hình', 'Ổ cắm', 'Cách âm'],
      availableSlots: ['08:00', '14:00', '16:00'],
      color: Color(0xFF28A69A),
      icon: Icons.auto_awesome_mosaic_rounded,
    ),
    DemoRoom(
      name: 'Phòng B-204',
      building: 'Tòa B · Tầng 2',
      capacity: 24,
      price: 35000,
      features: ['Máy chiếu', 'Micro', 'Bảng trắng'],
      availableSlots: ['11:00', '15:30'],
      color: Color(0xFFF39B55),
      icon: Icons.co_present_rounded,
    ),
  ];

  static const books = [
    DemoBook(
      title: 'Clean Architecture',
      author: 'Robert C. Martin',
      category: 'Công nghệ',
      available: 3,
      color: Color(0xFF4169A8),
      code: '005.1 MAR',
    ),
    DemoBook(
      title: 'Designing Data-Intensive Applications',
      author: 'Martin Kleppmann',
      category: 'Công nghệ',
      available: 1,
      color: Color(0xFF8B5E3C),
      code: '005.74 KLE',
    ),
    DemoBook(
      title: 'Tư duy nhanh và chậm',
      author: 'Daniel Kahneman',
      category: 'Kỹ năng',
      available: 5,
      color: Color(0xFFB55353),
      code: '153.4 KAH',
    ),
  ];

  static const events = [
    DemoEvent(
      title: 'Campus Innovation Challenge 2026',
      date: '24 THG 10 · 08:00',
      location: 'Hội trường A',
      category: 'Cuộc thi',
      description:
          'Cùng đồng đội xây dựng giải pháp số giúp trải nghiệm đại học tốt hơn.',
      isTeamEvent: true,
      fee: 0,
      color: Color(0xFF5C5FEF),
      icon: Icons.emoji_events_rounded,
    ),
    DemoEvent(
      title: 'Đêm nhạc Chào Tân Sinh Viên',
      date: '02 THG 11 · 19:00',
      location: 'Sân vận động',
      category: 'Văn hóa',
      description:
          'Một đêm âm nhạc, ánh sáng và những khoảnh khắc đáng nhớ cùng cộng đồng sinh viên.',
      isTeamEvent: false,
      fee: 50000,
      color: Color(0xFFE05B88),
      icon: Icons.music_note_rounded,
    ),
    DemoEvent(
      title: 'Workshop: CV nổi bật trong 6 giây',
      date: '08 THG 11 · 14:00',
      location: 'Phòng B-204',
      category: 'Workshop',
      description:
          'Thực hành tối ưu CV cùng chuyên gia tuyển dụng và nhận phản hồi trực tiếp.',
      isTeamEvent: false,
      fee: 0,
      color: Color(0xFF28A69A),
      icon: Icons.work_outline_rounded,
    ),
  ];

  static const products = [
    DemoProduct(
      name: 'Áo polo Campus',
      price: 189000,
      category: 'Đồng phục',
      color: Color(0xFF284B7B),
      icon: Icons.checkroom_rounded,
    ),
    DemoProduct(
      name: 'Bình nước inox',
      price: 129000,
      category: 'Phụ kiện',
      color: Color(0xFF2E9E91),
      icon: Icons.local_drink_rounded,
    ),
    DemoProduct(
      name: 'Mũ lưỡi trai',
      price: 99000,
      category: 'Phụ kiện',
      color: Color(0xFFE8894C),
      icon: Icons.sports_baseball_rounded,
    ),
    DemoProduct(
      name: 'Sổ tay Campus',
      price: 49000,
      category: 'Văn phòng phẩm',
      color: Color(0xFF8065B4),
      icon: Icons.menu_book_rounded,
    ),
  ];
}

String formatVnd(int value) {
  if (value == 0) return 'Miễn phí';
  final digits = value.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write('.');
    output.write(digits[index]);
  }
  return '${output.toString()}đ';
}
