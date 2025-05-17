import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../notification_service.dart'; // Adjusted import path
import '../config.dart';

class ThresholdProvider with ChangeNotifier {
  // Notification service instance
  final NotificationService _notificationService = NotificationService();

  // Normal thresholds
  double _gasThreshold = 300.0;
  double _tempThreshold = 30.0;
  double _soundThreshold = 60.0;

  // Warning thresholds
  double _gasWarningThreshold = 450.0;
  double _tempWarningThreshold = 40.0;
  double _soundWarningThreshold = 80.0;

  // Danger thresholds
  double _gasDangerThreshold = 600.0;
  double _tempDangerThreshold = 50.0;
  double _soundDangerThreshold = 100.0;

  bool _isLoading = false;
  String? _error;
  bool _verified = false; // Track if the last update was verified successfully

  // Getters for normal thresholds
  double get gasThreshold => _gasThreshold;
  double get tempThreshold => _tempThreshold;
  double get soundThreshold => _soundThreshold;

  // Getters for warning thresholds
  double get gasWarningThreshold => _gasWarningThreshold;
  double get tempWarningThreshold => _tempWarningThreshold;
  double get soundWarningThreshold => _soundWarningThreshold;

  // Getters for danger thresholds
  double get gasDangerThreshold => _gasDangerThreshold;
  double get tempDangerThreshold => _tempDangerThreshold;
  double get soundDangerThreshold => _soundDangerThreshold;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get verified => _verified; // Add getter for verification status

  // Load thresholds from server
  Future<void> loadThresholds() async {
    _isLoading = true;
    _error = null;
    _verified = false;
    notifyListeners();

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (token == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/thresholds'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Normal thresholds
        _gasThreshold = (data['gasThreshold'] ?? 300.0).toDouble();
        _tempThreshold = (data['tempThreshold'] ?? 30.0).toDouble();
        _soundThreshold = (data['soundThreshold'] ?? 60.0).toDouble();

        // Warning thresholds
        _gasWarningThreshold =
            (data['gasWarningThreshold'] ?? 450.0).toDouble();
        _tempWarningThreshold =
            (data['tempWarningThreshold'] ?? 40.0).toDouble();
        _soundWarningThreshold =
            (data['soundWarningThreshold'] ?? 80.0).toDouble();

        // Danger thresholds
        _gasDangerThreshold = (data['gasDangerThreshold'] ?? 600.0).toDouble();
        _tempDangerThreshold = (data['tempDangerThreshold'] ?? 50.0).toDouble();
        _soundDangerThreshold =
            (data['soundDangerThreshold'] ?? 100.0).toDouble();

        // Validate threshold relationships
        _validateThresholdRelationships();

        // Update thresholds in notification service
        _updateNotificationServiceThresholds();

        _verified = true; // Assume initial load is verified
      } else {
        _error = 'Failed to load thresholds';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Validate threshold relationships (normal < warning < dangerous)
  void _validateThresholdRelationships() {
    // Gas thresholds validation
    if (_gasThreshold >= _gasWarningThreshold ||
        _gasWarningThreshold >= _gasDangerThreshold) {
      _error =
          'Invalid gas threshold values: normal < warning < dangerous required';
    }

    // Temperature thresholds validation
    if (_tempThreshold >= _tempWarningThreshold ||
        _tempWarningThreshold >= _tempDangerThreshold) {
      _error =
          'Invalid temperature threshold values: normal < warning < dangerous required';
    }

    // Sound thresholds validation
    if (_soundThreshold >= _soundWarningThreshold ||
        _soundWarningThreshold >= _soundDangerThreshold) {
      _error =
          'Invalid sound threshold values: normal < warning < dangerous required';
    }
  }

  // Save thresholds to server (admin only)
  Future<void> saveThresholds({
    // Normal thresholds
    required double gasThreshold,
    required double tempThreshold,
    required double soundThreshold,
    // Warning thresholds
    required double gasWarningThreshold,
    required double tempWarningThreshold,
    required double soundWarningThreshold,
    // Danger thresholds
    required double gasDangerThreshold,
    required double tempDangerThreshold,
    required double soundDangerThreshold,
  }) async {
    _isLoading = true;
    _error = null;
    _verified = false;
    notifyListeners();

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (token == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Local validation before sending to server
      if (gasThreshold >= gasWarningThreshold ||
          gasWarningThreshold >= gasDangerThreshold ||
          tempThreshold >= tempWarningThreshold ||
          tempWarningThreshold >= tempDangerThreshold ||
          soundThreshold >= soundWarningThreshold ||
          soundWarningThreshold >= soundDangerThreshold) {
        _error =
            'Invalid threshold values: thresholds must follow pattern normal < warning < dangerous';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.post(
        Uri.parse('${Config.baseUrl}/admin/thresholds'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          // Normal thresholds
          'gasThreshold': gasThreshold,
          'tempThreshold': tempThreshold,
          'soundThreshold': soundThreshold,
          // Warning thresholds
          'gasWarningThreshold': gasWarningThreshold,
          'tempWarningThreshold': tempWarningThreshold,
          'soundWarningThreshold': soundWarningThreshold,
          // Danger thresholds
          'gasDangerThreshold': gasDangerThreshold,
          'tempDangerThreshold': tempDangerThreshold,
          'soundDangerThreshold': soundDangerThreshold,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if the server verified the threshold updates
        _verified = data['verified'] ?? false;

        if (!_verified) {
          _error = 'Thresholds saved but verification failed. Please refresh.';
          _isLoading = false;
          notifyListeners();
          return;
        }

        // Update local values from the server response to ensure they match
        final thresholds = data['thresholds'];

        // Normal thresholds
        _gasThreshold = (thresholds['gasThreshold'] ?? 300.0).toDouble();
        _tempThreshold = (thresholds['tempThreshold'] ?? 30.0).toDouble();
        _soundThreshold = (thresholds['soundThreshold'] ?? 60.0).toDouble();

        // Warning thresholds
        _gasWarningThreshold =
            (thresholds['gasWarningThreshold'] ?? 450.0).toDouble();
        _tempWarningThreshold =
            (thresholds['tempWarningThreshold'] ?? 40.0).toDouble();
        _soundWarningThreshold =
            (thresholds['soundWarningThreshold'] ?? 80.0).toDouble();

        // Danger thresholds
        _gasDangerThreshold =
            (thresholds['gasDangerThreshold'] ?? 600.0).toDouble();
        _tempDangerThreshold =
            (thresholds['tempDangerThreshold'] ?? 50.0).toDouble();
        _soundDangerThreshold =
            (thresholds['soundDangerThreshold'] ?? 100.0).toDouble();

        // Update thresholds in notification service
        _updateNotificationServiceThresholds();
      } else {
        final data = jsonDecode(response.body);
        _error = data['error'] ?? 'Failed to update thresholds';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to update thresholds in notification service
  void _updateNotificationServiceThresholds() {
    _notificationService.setThresholds(
      // Normal thresholds
      gasThreshold: _gasThreshold,
      tempThreshold: _tempThreshold,
      soundThreshold: _soundThreshold,
      // Warning thresholds
      gasWarningThreshold: _gasWarningThreshold,
      tempWarningThreshold: _tempWarningThreshold,
      soundWarningThreshold: _soundWarningThreshold,
      // Danger thresholds
      gasDangerThreshold: _gasDangerThreshold,
      tempDangerThreshold: _tempDangerThreshold,
      soundDangerThreshold: _soundDangerThreshold,
    );
  }
}
