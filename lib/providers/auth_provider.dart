import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../config.dart';
import 'dart:async';

// Placeholder AuthProvider
class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  UserProfile? _userProfile;
  String? _token;

  bool get isAuthenticated => _userProfile != null;
  UserProfile? get userProfile => _userProfile;
  String? get token => _token;

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

  Future<void> updateEmail(String newEmail) async {
    if (_userProfile != null) {
      _userProfile = UserProfile(
        name: _userProfile!.name,
        email: newEmail,
        role: _userProfile!.role,
      );
      notifyListeners();
    }
  }

  Future<bool> tryAutoLogin() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return false;

      _token = token;

      // Add timeout duration directly (no need for separate exception)
      await _fetchUserProfile().timeout(
        const Duration(seconds: 10),
      );

      return true;
    } on TimeoutException catch (e, s) {
      if (Config.debugLoggingEnabled) {
        debugPrint('Auth Provider: Auto login timeout: $e');
        debugPrint('Stack trace: $s');
      }
      return false;
    } catch (e, s) {
      if (Config.debugLoggingEnabled) {
        debugPrint('Auth Provider: Auto login error: $e');
        debugPrint('Stack trace: $s');
      }
      return false;
    }
  }

  Future<void> _fetchUserProfile() async {
    final url = '${Config.baseUrl}/user/profile';
    if (Config.debugLoggingEnabled) {
      debugPrint('Auth Provider: Attempting to fetch user profile from $url');
    }
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));

      if (Config.debugLoggingEnabled) {
        debugPrint(
            'Auth Provider: Profile fetch response status: ${response.statusCode}');
        debugPrint(
            'Auth Provider: Profile fetch response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _userProfile = UserProfile(
          name: data['username'] ?? 'Unknown User',
          email: data['email'] ?? 'no-email@example.com',
        );
        notifyListeners();
      } else {
        if (Config.debugLoggingEnabled) {
          debugPrint(
              'Auth Provider: Failed to fetch profile. Status: ${response.statusCode}');
        }
      }
    } on TimeoutException catch (e, s) {
      if (Config.debugLoggingEnabled) {
        debugPrint('Auth Provider: Timeout fetching profile from $url: $e');
        debugPrint('Stack trace: $s');
      }
    } catch (e, s) {
      if (Config.debugLoggingEnabled) {
        debugPrint('Auth Provider: Error fetching profile from $url: $e');
        debugPrint('Stack trace: $s');
      }
    }
  }
}
