import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../demo/demo_data.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  var _cartCount = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Campus Shop',
                              style: TextStyle(
                                color: AppTheme.navy,
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Mang một phần Campus theo bạn mỗi ngày.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _showCart,
                        icon: Badge(
                          isLabelVisible: _cartCount > 0,
                          label: Text('$_cartCount'),
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 118,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF0985A), Color(0xFFE96767)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Bộ sưu tập 2026',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Thiết kế mới · Số lượng giới hạn',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            sliver: SliverGrid.builder(
              itemCount: DemoData.products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: .72,
              ),
              itemBuilder: (context, index) {
                final product = DemoData.products[index];
                return _ProductCard(
                  product: product,
                  onAdd: () {
                    setState(() => _cartCount++);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã thêm ${product.name} vào giỏ.'),
                        duration: const Duration(milliseconds: 900),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_rounded,
                size: 52, color: AppTheme.blue),
            const SizedBox(height: 12),
            Text(
              _cartCount == 0
                  ? 'Giỏ hàng đang trống'
                  : 'Bạn có $_cartCount sản phẩm',
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Demo giỏ hàng đã sẵn sàng. Thanh toán sẽ được nối API ở giai đoạn tiếp theo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _cartCount == 0 ? null : () => Navigator.pop(context),
                child: const Text('Tiếp tục thanh toán'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final DemoProduct product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: product.color.withValues(alpha: .11),
              child: Icon(product.icon, size: 66, color: product.color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.category,
                  style: TextStyle(
                    color: product.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatVnd(product.price),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: onAdd,
                      tooltip: 'Thêm vào giỏ',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_rounded, size: 19),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
