import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rating_dialog/rating_dialog.dart' as rating_dialog;
import '../providers/auth_provider.dart';
import 'alert_thresholds_screen.dart';
import 'notification_settings_screen.dart';
import 'account_settings_screen.dart';
import 'registration_requests_screen.dart';
import 'database_stats_screen.dart';

class MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  MenuItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });
}

class MenuSection {
  final String title;
  final List<MenuItem> items;

  MenuSection({required this.title, required this.items});
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<MenuSection> menuSections;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    _updateMenuSections(authProvider);
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF15355E),
          ),
        ),
        child: rating_dialog.RatingDialog(
          initialRating: 1.0,
          title: const Text(
            'Rate Climcare',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          message: const Text(
            'We would love to hear your feedback! Your opinion helps us improve our service.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white70),
          ),
          submitButtonText: 'Submit',
          commentHint: 'Tell us your thoughts...',
          onCancelled: () => debugPrint('Rating dialog cancelled'),
          onSubmitted: (response) {
            debugPrint(
              'Rating: ${response.rating}, Comment: ${response.comment}',
            );
            // TODO: Handle the rating submission
          },
          starColor: Colors.orange,
        ),
      ),
    );
  }

  void _updateMenuSections(AuthProvider authProvider) {
    final generalItems = [
      MenuItem(
        icon: Icons.person_outline,
        title: authProvider.userProfile?.isAdmin ?? false
            ? 'Accounts'
            : 'My Account',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AccountSettingsScreen(),
            ),
          );
        },
      ),
      MenuItem(
        icon: Icons.notifications_none_outlined,
        title: 'Notifications',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationSettingsScreen(),
            ),
          );
        },
      ),
    ];

    // Admin specific items
    final adminItems = <MenuItem>[];
    if (authProvider.userProfile?.isAdmin ?? false) {
      adminItems.add(
        MenuItem(
          icon: Icons.thermostat_outlined,
          title: 'Alert Thresholds',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AlertThresholdScreen(),
              ),
            );
          },
        ),
      );
      adminItems.add(
        MenuItem(
          icon: Icons.how_to_reg_outlined,
          title: 'Registration Requests',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistrationRequestsScreen(),
              ),
            );
          },
        ),
      );
      adminItems.add(
        MenuItem(
          icon: Icons.storage_outlined,
          title: 'Database Stats',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DatabaseStatsScreen(),
              ),
            );
          },
        ),
      );
    }

    // Add logout option
    generalItems.add(
      MenuItem(
        icon: Icons.logout_outlined,
        title: 'Logout',
        onTap: () async {
          final navigator = Navigator.of(context);
          await Provider.of<AuthProvider>(context, listen: false).logout();
          if (!mounted) return;
          navigator.pushNamedAndRemoveUntil('/', (route) => false);
        },
      ),
    );

    menuSections = [
      MenuSection(
        title: 'General',
        items: generalItems,
      ),
      // Add Admin section only if there are admin items
      if (adminItems.isNotEmpty)
        MenuSection(
          title: 'Admin Tools',
          items: adminItems,
        ),
      MenuSection(
        title: 'Feedback',
        items: [
          MenuItem(
            icon: Icons.star_outline,
            title: 'Rate App',
            onTap: _showRatingDialog,
          ),
          MenuItem(
            icon: Icons.chat_bubble_outline,
            title: 'Send Feedback',
            onTap: () {
              /* TODO: Implement feedback mechanism */
            },
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    // Adjust breakpoint if needed
    final isSmallScreen = screenWidth < 360 || screenHeight < 600;

    return Scaffold(
      extendBody: true, // Allow background to extend behind nav bar
      backgroundColor:
          Colors.transparent, // Make Scaffold background transparent
      body: Stack(
        children: [
          // Add the background elements first
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF001D54), Color(0xFF000000)],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/images/worldmap.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Existing content Column
          Column(
            children: [
              const SafeArea(
                bottom: false,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Center(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                          color: Color(0xFFE07A5F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    // Rebuild menu sections if auth state changes
                    _updateMenuSections(authProvider);

                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12.0 : 20.0,
                        vertical: isSmallScreen ? 10.0 : 15.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...menuSections.map(
                            (section) => _buildSection(section),
                          ),
                          const SizedBox(height: 48), // Add space at the bottom
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(MenuSection section) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 4.0,
          ), // Align with list tile content
          child: Text(
            section.title,
            style: TextStyle(
              color: Colors.orange,
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        ...section.items.map((item) => _buildItem(item)),
        SizedBox(height: isSmallScreen ? 16 : 24),
      ],
    );
  }

  Widget _buildItem(MenuItem item) {
    return _buildSettingsTile(
      icon: item.icon,
      title: item.title,
      onTap: item.onTap ?? () {},
      trailing: item.trailing,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Container(
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 5 : 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25), // Slightly transparent white
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: isSmallScreen,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
        ),
        visualDensity: isSmallScreen
            ? const VisualDensity(horizontal: -2, vertical: -2)
            : VisualDensity.standard,
        leading: Icon(icon, color: Colors.white.withAlpha((255 * 0.8).round())),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        trailing:
            trailing ?? const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.white.withAlpha(30),
        splashColor: Colors.white.withAlpha(40),
      ),
    );
  }
}

// Optional: Placeholder NavigationItem class if needed elsewhere,
// otherwise it can be removed if only used within the reference file.
/*
class NavigationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final Function()? onClick;

  const NavigationItem({
    Key? key,
    required this.icon,
    required this.title,
    this.isSelected = false,
    this.onClick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12, vertical: isSmallScreen ? 6 : 8),
      child: InkWell(
        onTap: onClick,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: isSmallScreen ? 40 : 50,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.orange.withAlpha((255 * 0.2).round())
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.orange
                    : Colors.white.withAlpha((255 * 0.7).round()),
                size: isSmallScreen ? 20 : 24,
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.orange
                        : Colors.white.withAlpha((255 * 0.7).round()),
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withAlpha((255 * 0.5).round()),
                size: isSmallScreen ? 16 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
