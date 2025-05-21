import 'package:flutter/material.dart';
import '../notification_service.dart';
import '../widgets/common_background.dart';
import '../models/notification.dart' as app_notification;
import '../providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<NotificationProvider>(context, listen: false)
            .fetchNotifications());
  }

  Future<void> _refreshNotifications() async {
    await Provider.of<NotificationProvider>(context, listen: false)
        .fetchNotifications();
  }

  Future<void> _deleteNotification(String id) async {
    await Provider.of<NotificationProvider>(context, listen: false)
        .deleteNotification(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: CommonBackground(
        child: Column(
          children: [
            // Header Title with Refresh Button
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
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
                    IconButton(
                      icon: Icon(Icons.refresh, color: Color(0xFFE07A5F)),
                      onPressed: _refreshNotifications,
                    ),
                  ],
                ),
              ),
            ),
            // Main content
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  if (notificationProvider.isLoading) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (notificationProvider.notifications.isEmpty) {
                    return Center(
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
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16.0),
                    itemCount: notificationProvider.notifications.length,
                    itemBuilder: (context, index) {
                      final notification =
                          notificationProvider.notifications[index];
                      Color statusColor;
                      switch (notification.type) {
                        case 'gas':
                          statusColor = Colors.red;
                          break;
                        case 'temperature':
                          statusColor = Colors.orange;
                          break;
                        case 'sound':
                          statusColor = Colors.blue;
                          break;
                        default:
                          statusColor = Colors.grey;
                      }

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8.0),
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
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4.0),
                              Text(
                                '${notification.type.toUpperCase()} - ${DateFormat('yyyy-MM-dd HH:mm').format(notification.timestamp)}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12.0),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () =>
                                _deleteNotification(notification.id),
                          ),
                        ),
                      );
                    },
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

// You will need to create or update NotificationProvider and app_notification.Notification model
// in your providers/ and models/ directories respectively.
// The app_notification.Notification model should at least have 'id', 'type', 'message', and 'timestamp' fields.
// The NotificationProvider should have fetchNotifications and deleteNotification methods
// which interact with your backend API.
