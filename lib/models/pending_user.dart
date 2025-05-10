class PendingUser {
  final String id;
  final String username;
  final String email;
  final String status;
  final DateTime createdAt;

  PendingUser({
    required this.id,
    required this.username,
    required this.email,
    required this.status,
    required this.createdAt,
  });

  factory PendingUser.fromJson(Map<String, dynamic> json) {
    return PendingUser(
      id: json['_id'],
      username: json['username'],
      email: json['email'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
