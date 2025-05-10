import 'package:flutter/material.dart';
import '../widgets/common_background.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Example state for toggles
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _soundAlertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CommonBackground(
        child: Stack(
          // Use Stack for Back Button
          children: [
            Column(
              children: [
                // Header Title
                const SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Center(
                      child: Text(
                        'Notification Settings',
                        style: TextStyle(
                            color: Color(0xFFE07A5F),
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                // Settings Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 20.0),
                    children: [
                      _buildSwitchItem(
                        context,
                        Icons.notifications_active_outlined,
                        'Push Notifications',
                        _pushNotificationsEnabled,
                        (value) =>
                            setState(() => _pushNotificationsEnabled = value),
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchItem(
                        context,
                        Icons.mail_outline,
                        'Email Notifications',
                        _emailNotificationsEnabled,
                        (value) =>
                            setState(() => _emailNotificationsEnabled = value),
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchItem(
                        context,
                        Icons.volume_up_outlined,
                        'Sound Alerts',
                        _soundAlertsEnabled,
                        (value) => setState(() => _soundAlertsEnabled = value),
                      ),
                      // Add more settings as needed
                    ],
                  ),
                ),
              ],
            ),
            // Back Button
            const Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: BackButton(color: Color(0xFFE07A5F)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build switch list tile
  Widget _buildSwitchItem(BuildContext context, IconData icon, String title,
      bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white.withAlpha((255 * 0.8).round())),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.orange, // Customize switch color
          inactiveTrackColor: Colors.white30,
        ),
        onTap: () => onChanged(!value), // Allow tapping row
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
