import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/demo_widgets.dart';
import '../../../demo/demo_data.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final books = DemoData.books
        .where(
          (book) => book.title.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thư viện',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đặt trước để sách được chuẩn bị khi bạn tới.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 18),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Tên sách, tác giả hoặc mã tài liệu',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE6F8F4), Color(0xFFF2FBFA)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: AppTheme.cyan),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sách đặt trước được giữ tối đa 3 giờ sau khi nhân viên xác nhận.',
                          style: TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: books.isEmpty
                ? const EmptyDemoState(
                    message: 'Không tìm thấy đầu sách phù hợp.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: books.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) => _BookCard(
                      book: books[index],
                      onReserve: () => _reserve(books[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _reserve(DemoBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.bookmark_add_rounded, color: AppTheme.cyan),
        title: const Text('Đặt mượn trước?'),
        content: Text(
          '“${book.title}” sẽ được nhân viên chuẩn bị. Bạn cần đến quầy trong vòng 3 giờ sau khi nhận thông báo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi yêu cầu. Thư viện sẽ sớm xác nhận.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onReserve});

  final DemoBook book;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 98,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: book.color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: book.color.withValues(alpha: .25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.auto_stories_rounded, color: Colors.white),
                  Text(
                    book.category.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(book.author,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      StatusPill(
                        label: 'Còn ${book.available} cuốn',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const Spacer(),
                      Text(book.code,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: onReserve,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40)),
                      child: const Text('Đặt mượn trước'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
