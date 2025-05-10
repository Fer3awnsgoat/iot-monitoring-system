import 'package:flutter/material.dart';
import '../widgets/common_background.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CommonBackground(
        child: Stack(
          // Use Stack to overlay BackButton
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
                        'Account Settings',
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
                      _buildSettingsItem(
                          context, Icons.person_outline, 'Edit Profile', () {
                        /* TODO: Navigate to edit profile */
                      }),
                      const SizedBox(height: 10),
                      _buildSettingsItem(context, Icons.email_outlined, 'Email',
                          () {
                        /* TODO: Show email or edit */
                      }, trailingText: 'user@example.com'), // Example
                      const SizedBox(height: 10),
                      _buildSettingsItem(
                          context, Icons.phone_outlined, 'Phone Number', () {
                        /* TODO: Add/Edit phone */
                      }, trailingText: 'Not Set'),
                      const SizedBox(height: 10),
                      _buildSettingsItem(
                          context, Icons.lock_outline, 'Change Password', () {
                        Navigator.pushNamed(
                            context, '/change-password'); // Example navigation
                      }),
                      const SizedBox(height: 10),
                      _buildSettingsItem(
                          context, Icons.delete_outline, 'Delete Account', () {
                        /* TODO: Show delete confirmation */
                      }, color: Colors.redAccent),
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

  // Helper to build list tile for settings
  Widget _buildSettingsItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap,
      {String? trailingText, Color? color}) {
    final itemColor = color ?? Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: itemColor.withAlpha((255 * 0.8).round())),
        title: Text(title, style: TextStyle(color: itemColor, fontSize: 16)),
        trailing: trailingText != null
            ? Text(trailingText,
                style: const TextStyle(color: Colors.white70, fontSize: 14))
            : Icon(Icons.chevron_right,
                color: itemColor.withAlpha((255 * 0.6).round())),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
