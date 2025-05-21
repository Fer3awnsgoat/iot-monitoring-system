import 'package:flutter/material.dart';
import '../notification_service.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import '../widgets/custom_bottom_nav.dart';

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
  late PageController _pageController;

  // List of main screens
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Initialize screens
    _screens = [
      const DashboardScreen(),
      const AnalyticsScreen(),
      const NotificationsScreen(),
      const SettingsScreen(),
    ];
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
