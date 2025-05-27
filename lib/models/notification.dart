// Simple model to store notification data
class AppNotification {
  final String type; // 'gas', 'temperature', or 'sound'
  final String status; // 'normal', 'warning', or 'danger'
  final String message; // The notification message
  final double value; // The sensor value that triggered the notification
  final DateTime timestamp; // When the notification was created

  AppNotification({
    required this.type,
    required this.status,
    required this.message,
    required this.value,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Convert to JSON for sending to backend
  Map<String, dynamic> toJson() => {
        'type': type,
        'status': status,
        'message': message,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
      };
}
