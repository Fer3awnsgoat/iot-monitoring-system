import 'package:flutter/material.dart';
import '../notification_service.dart';
import '../widgets/common_background.dart';

class NotificationsScreen extends StatelessWidget {
  final NotificationService notificationService;

  const NotificationsScreen({
    super.key,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    final notifications = notificationService.notifications;
    return Scaffold(
      extendBody: true, // Allow background to extend behind nav bar
      body: CommonBackground(
        child: Column(
          children: [
            // Header Title (same as other screens)
            const SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Center(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                        color: Color(0xFFE07A5F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            // Main content
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 100, color: Colors.white.withAlpha(150)),
                          const SizedBox(height: 24),
                          const Text(
                            'No Notification Here',
                            style: TextStyle(
                                fontSize: 22,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        Color statusColor;
                        switch (notification.status) {
                          case 'dangerous':
                            statusColor = Colors.red;
                            break;
                          case 'warning':
                            statusColor = Colors.orange;
                            break;
                          case 'normal':
                            statusColor = Colors.green;
                            break;
                          default:
                            statusColor = Colors.grey;
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor,
                              child: Icon(
                                _getIconForType(notification.type),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              notification.message,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${notification.type} - ${notification.timestamp.toString()}',
                            ),
                            trailing: Text(
                              notification.status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'gas':
        return Icons.gas_meter;
      case 'temperature':
        return Icons.thermostat;
      case 'sound':
        return Icons.volume_up;
      default:
        return Icons.notifications;
    }
  }
}
