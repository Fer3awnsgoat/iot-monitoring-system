// Simple model to store notification data
class Notification {
  final String id;
  final String type;
  final String message;
  final DateTime timestamp;
  final bool read;

  Notification({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.read = false,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['_id'] ?? json['id'],
      type: json['type'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      read: json['read'] ?? false,
    );
  }

  // Convert to JSON for sending to backend
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
    };
  }
}
