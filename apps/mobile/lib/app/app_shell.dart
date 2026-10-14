import 'package:flutter/material.dart';

import '../features/events/presentation/events_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/rooms/presentation/rooms_screen.dart';
import '../features/store/presentation/store_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({this.displayName = 'Minh Anh', super.key});

  final String displayName;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onNavigate: _selectPage, displayName: widget.displayName),
      const RoomsScreen(),
      const LibraryScreen(),
      const EventsScreen(),
      const StoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room_rounded),
            label: 'Phòng',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library_rounded),
            label: 'Thư viện',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Sự kiện',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Cửa hàng',
          ),
        ],
      ),
    );
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }
}
