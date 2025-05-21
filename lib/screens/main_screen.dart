import 'package:flutter/material.dart';
import '../notification_service.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import '../widgets/custom_bottom_nav.dart';
import '../providers/notification_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  final NotificationService notificationService;

  const MainScreen({
    super.key,
    required this.notificationService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // List of main screens
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Initialize screens
    _screens = [
      const DashboardScreen(),
      const AnalyticsScreen(),
      NotificationsScreen(), // Removed const since it's not a const constructor
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
        ),
      ],
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
