import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/demo_widgets.dart';
import '../../../demo/demo_data.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sự kiện Campus',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Khám phá, kết nối và tạo nên dấu ấn của bạn.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: const [
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: FilterChip(
                        label: Text('Tất cả'),
                        selected: true,
                        onSelected: null),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child:
                        FilterChip(label: Text('Cuộc thi'), onSelected: null),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child:
                        FilterChip(label: Text('Workshop'), onSelected: null),
                  ),
                  FilterChip(label: Text('Văn hóa'), onSelected: null),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            sliver: SliverList.separated(
              itemCount: DemoData.events.length,
              separatorBuilder: (context, index) => const SizedBox(height: 15),
              itemBuilder: (context, index) {
                final event = DemoData.events[index];
                return _EventCard(
                  event: event,
                  onRegister: () => _openRegistration(context, event),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRegistration(BuildContext context, DemoEvent event) async {
    final registered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EventRegistrationSheet(event: event),
    );
    if (registered == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng ký “${event.title}” thành công!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onRegister});

  final DemoEvent event;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 116,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [event.color, event.color.withValues(alpha: .65)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 18,
                  bottom: -12,
                  child: Icon(
                    event.icon,
                    size: 105,
                    color: Colors.white.withValues(alpha: .18),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: StatusPill(
                    label: event.category,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 15,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 17),
                      const SizedBox(width: 6),
                      Text(
                        event.date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.grey, height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 17, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(event.location, style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    if (event.isTeamEvent)
                      const StatusPill(
                          label: 'Đội thi', icon: Icons.groups_rounded)
                    else
                      Text(
                        formatVnd(event.fee),
                        style: TextStyle(
                          color: event.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRegister,
                    child: const Text('Đăng ký tham gia'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRegistrationSheet extends StatefulWidget {
  const _EventRegistrationSheet({required this.event});

  final DemoEvent event;

  @override
  State<_EventRegistrationSheet> createState() =>
      _EventRegistrationSheetState();
}

class _EventRegistrationSheetState extends State<_EventRegistrationSheet> {
  var _asTeam = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đăng ký sự kiện',
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(widget.event.title,
                style: const TextStyle(color: Colors.grey)),
            if (widget.event.isTeamEvent) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false,
                        label: Text('Cá nhân'),
                        icon: Icon(Icons.person_rounded)),
                    ButtonSegment(
                        value: true,
                        label: Text('Đội thi'),
                        icon: Icon(Icons.groups_rounded)),
                  ],
                  selected: {_asTeam},
                  onSelectionChanged: (value) =>
                      setState(() => _asTeam = value.first),
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: _asTeam ? 'Họ và tên nhóm trưởng' : 'Họ và tên',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            const TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email sinh viên',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            if (_asTeam) ...[
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Tên đội thi',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Thành viên trong đội',
                  hintText: 'Mỗi thành viên một dòng',
                  prefixIcon: Icon(Icons.group_add_outlined),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined,
                      color: AppTheme.blue),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Phí tham gia',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  Text(
                    formatVnd(widget.event.fee),
                    style: const TextStyle(
                        color: AppTheme.navy, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(widget.event.fee > 0
                    ? 'Tiếp tục thanh toán'
                    : 'Hoàn tất đăng ký'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
