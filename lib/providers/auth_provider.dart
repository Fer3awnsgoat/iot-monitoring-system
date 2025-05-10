import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../config.dart';

// Placeholder AuthProvider
class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  UserProfile? _userProfile;
  String? _token;

  bool get isAuthenticated => _userProfile != null;
  UserProfile? get userProfile => _userProfile;

  Future<void> login(String token, UserProfile profile) async {
    _token = token;
    _userProfile = profile;
    await _storage.write(key: 'auth_token', value: token);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _userProfile = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return false;

      _token = token;
      await _fetchUserProfile();
      return true;
    } catch (e) {
      debugPrint('Auto login error: $e');
      return false;
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/user/profile'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _userProfile = UserProfile(
          name: data['username'] ?? 'Unknown User',
          email: data['email'] ?? 'no-email@example.com',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }
}
