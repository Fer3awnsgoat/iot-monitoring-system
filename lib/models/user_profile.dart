// Simple model for user profile data
enum UserRole { admin, user }

class UserProfile {
  final String name;
  final String email;
  final String language;
  final bool isDarkMode;
  final UserRole role;
  String? phoneNumber;
  String? company;
  String? jobTitle;
  String? avatar; // URL or asset path

  UserProfile({
    required this.name,
    required this.email,
    this.phoneNumber,
    this.company,
    this.jobTitle,
    this.language = 'en',
    this.isDarkMode = false,
    this.avatar,
    this.role = UserRole.user,
  });

  bool get isAdmin => role == UserRole.admin;

  // Convert UserProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'username': name,
      'email': email,
      'language': language,
      'isDarkMode': isDarkMode,
      'role': role.toString().split('.').last,
    };
  }

  // Create UserProfile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['username'] ?? 'Unknown User',
      email: json['email'] ?? 'no-email@example.com',
      language: json['language'] ?? 'en',
      isDarkMode: json['isDarkMode'] ?? false,
      role: json['role'] == 'admin' ? UserRole.admin : UserRole.user,
    );
  }
}
