import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart'; // Import the model
import '../models/device.dart';
import '../config.dart';

const String baseUrl = "http://10.0.2.2:3001";

// Placeholder AccountProvider
class AccountProvider with ChangeNotifier {
  final _prefs = SharedPreferences.getInstance();
  final _storage = const FlutterSecureStorage();
  UserProfile? _profile;
  bool _twoFactorEnabled = false;
  bool _biometricsEnabled = false;
  bool _locationEnabled = false;
  final List<Device> _connectedDevices = [
    Device(name: 'Android Emulator', id: 'emulator-1', type: 'emulator'),
    Device(name: 'Chrome Browser', id: 'chrome-1', type: 'browser'),
  ];

  // --- Getters ---
  UserProfile? get profile => _profile;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get locationEnabled => _locationEnabled;
  List<Device> get connectedDevices => List.unmodifiable(_connectedDevices);

  // --- Methods ---

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await _prefs;
    _twoFactorEnabled = prefs.getBool('2fa_enabled') ?? false;
    _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
    _locationEnabled = prefs.getBool('location_enabled') ?? false;
    notifyListeners();
  }

  // Update profile
  Future<void> updateProfile(UserProfile newProfile) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(newProfile.toJson()),
      );

      if (response.statusCode == 200) {
        _profile = newProfile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  // Toggle 2FA
  Future<void> toggleTwoFactor(bool enabled) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool('2fa_enabled', enabled);
      _twoFactorEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling 2FA: $e');
    }
  }

  // Toggle biometrics
  Future<void> toggleBiometrics(bool enabled) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool('biometrics_enabled', enabled);
      _biometricsEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling biometrics: $e');
    }
  }

  // Toggle location services
  Future<void> toggleLocation(bool enabled) async {
    try {
      final prefs = await _prefs;
      await prefs.setBool('location_enabled', enabled);
      _locationEnabled = enabled;
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling location: $e');
    }
  }

  // Add a connected device
  Future<void> addDevice(Device device) async {
    if (!_connectedDevices.any((d) => d.id == device.id)) {
      _connectedDevices.add(device);
      notifyListeners();
      debugPrint('Device added: ${device.name}');
    }
  }

  // Remove a connected device
  Future<void> removeDevice(Device device) async {
    try {
      // Get authentication token
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        debugPrint('No auth token found for device removal');
        return;
      }

      // Call backend to deregister device
      final response = await http.delete(
        Uri.parse('${Config.baseUrl}/user/devices/${device.id}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Only remove from local list if backend deregistration was successful
        _connectedDevices.removeWhere((d) => d.id == device.id);
        notifyListeners();
        debugPrint('Device removed successfully: ${device.name}');
      } else {
        debugPrint('Failed to remove device: ${response.body}');
        throw Exception('Failed to remove device from server');
      }
    } catch (e) {
      debugPrint('Error removing device: $e');
      rethrow; // Re-throw to let the UI handle the error
    }
  }
}
