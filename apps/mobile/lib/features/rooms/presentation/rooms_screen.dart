import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/demo_widgets.dart';
import '../../../demo/demo_data.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  var _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tìm phòng học',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    StatusPill(
                      label: 'Cập nhật trực tiếp',
                      icon: Icons.sync_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn phòng trống và giữ lịch ngay lập tức.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 18),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên phòng hoặc tòa nhà',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      const labels = [
                        'Hôm nay',
                        'Ngày mai',
                        'Miễn phí',
                        '≥ 10 chỗ'
                      ];
                      return ChoiceChip(
                        label: Text(labels[index]),
                        selected: _selectedFilter == index,
                        onSelected: (_) =>
                            setState(() => _selectedFilter = index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              itemCount: DemoData.rooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) => _RoomCard(
                room: DemoData.rooms[index],
                onBook: () => _openBooking(DemoData.rooms[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBooking(DemoRoom room) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _BookingSheet(room: room),
    );
    if (booked == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã giữ ${room.name} thành công!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onBook});

  final DemoRoom room;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: room.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(room.icon, color: room.color, size: 28),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${room.building} · ${room.capacity} người',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatVnd(room.price),
                  style: TextStyle(
                    color: room.price == 0 ? AppTheme.cyan : AppTheme.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: room.features
                  .map(
                    (feature) => Chip(
                      label: Text(feature),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: const Color(0xFFF1F4F8),
                      labelStyle: const TextStyle(fontSize: 11),
                    ),
                  )
                  .toList(),
            ),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 17, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Còn trống: ${room.availableSlots.join(' · ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                FilledButton(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(84, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Đặt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.room});

  final DemoRoom room;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late String _slot = widget.room.availableSlots.first;
  var _attendees = 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            Text(
              'Đặt ${widget.room.name}',
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(widget.room.building,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 22),
            const Text('Ngày', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 14),
              tileColor: Color(0xFFF5F7FB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              leading: Icon(Icons.calendar_today_rounded, color: AppTheme.blue),
              title: Text('Thứ Năm, 15/10/2026'),
              trailing: Icon(Icons.expand_more_rounded),
            ),
            const SizedBox(height: 18),
            const Text('Giờ bắt đầu',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              children: widget.room.availableSlots
                  .map(
                    (slot) => ChoiceChip(
                      label: Text(slot),
                      selected: _slot == slot,
                      onSelected: (_) => setState(() => _slot = slot),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Số người',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton.filledTonal(
                  onPressed: _attendees > 1
                      ? () => setState(() => _attendees--)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '$_attendees',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _attendees < widget.room.capacity
                      ? () => setState(() => _attendees++)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const TextField(
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Mục đích sử dụng',
                hintText: 'Ví dụ: Học nhóm môn Lập trình mobile',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng thanh toán',
                          style: TextStyle(color: Colors.grey)),
                      Text(
                        formatVnd(widget.room.price),
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: const Text('Xác nhận đặt'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
