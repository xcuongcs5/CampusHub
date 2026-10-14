import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/demo_widgets.dart';
import '../../../demo/demo_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.onNavigate,
    required this.displayName,
    super.key,
  });

  final ValueChanged<int> onNavigate;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          _buildHeroCard(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Dịch vụ sinh viên'),
          const SizedBox(height: 12),
          _buildServices(),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Sắp diễn ra',
            action: 'Xem tất cả',
            onAction: () => onNavigate(3),
          ),
          const SizedBox(height: 10),
          _buildUpcomingEvent(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Hoạt động của bạn'),
          const SizedBox(height: 10),
          _buildActivity(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.blue, AppTheme.cyan],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text(
              'CH',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chào buổi sáng,',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                '$displayName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Badge(
            smallSize: 7,
            child: Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12345B), Color(0xFF176BCE)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blue.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusPill(
                  label: '3 phòng đang trống',
                  color: Color(0xFF70E1D4),
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Cần không gian\nđể học nhóm?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đặt phòng trong chưa đầy một phút.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: () => onNavigate(1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Tìm phòng ngay'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.blue,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.groups_2_rounded,
            size: 86,
            color: Color(0x554FD1C5),
          ),
        ],
      ),
    );
  }

  Widget _buildServices() {
    const services = [
      (Icons.meeting_room_rounded, 'Đặt phòng', Color(0xFF4C7DF0), 1),
      (Icons.auto_stories_rounded, 'Mượn sách', Color(0xFF28A69A), 2),
      (Icons.celebration_rounded, 'Sự kiện', Color(0xFFE05B88), 3),
      (Icons.shopping_bag_rounded, 'Campus Shop', Color(0xFFF39B55), 4),
    ];
    return Row(
      children: services.map((service) {
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onNavigate(service.$4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: service.$3.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(service.$1, color: service.$3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUpcomingEvent() {
    final event = DemoData.events.first;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onNavigate(3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 70,
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(event.icon, color: event.color, size: 31),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.date,
                      style: TextStyle(
                        color: event.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.cyan.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppTheme.cyan),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clean Architecture',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sẵn sàng nhận · Còn 2 giờ 15 phút',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const StatusPill(label: 'Đã chuẩn bị'),
          ],
        ),
      ),
    );
  }
}
