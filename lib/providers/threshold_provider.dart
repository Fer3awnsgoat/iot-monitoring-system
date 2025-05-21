import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../notification_service.dart';
import '../config.dart';
import 'dart:async';

class ThresholdProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final _storage = const FlutterSecureStorage();

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

  // Getters
  double get gasThreshold => _gasThreshold;
  double get tempThreshold => _tempThreshold;
  double get soundThreshold => _soundThreshold;

  double get gasWarningThreshold => _gasWarningThreshold;
  double get tempWarningThreshold => _tempWarningThreshold;
  double get soundWarningThreshold => _soundWarningThreshold;

  double get gasDangerThreshold => _gasDangerThreshold;
  double get tempDangerThreshold => _tempDangerThreshold;
  double get soundDangerThreshold => _soundDangerThreshold;

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load thresholds from server
  Future<void> loadThresholds() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _error = 'Not authenticated';
        return;
      }

      final response = await http.get(
        Uri.parse(Config.thresholdsEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Failed to load thresholds');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Add null checks and default values
        final gasData = data['gas'] ?? {};
        final tempData = data['temperature'] ?? {};
        final soundData = data['sound'] ?? {};

        // Update thresholds from new structure with null safety
        _gasThreshold = (gasData['normal'] ?? 300.0).toDouble();
        _gasWarningThreshold = (gasData['warning'] ?? 450.0).toDouble();
        _gasDangerThreshold = (gasData['danger'] ?? 600.0).toDouble();

        _tempThreshold = (tempData['normal'] ?? 30.0).toDouble();
        _tempWarningThreshold = (tempData['warning'] ?? 40.0).toDouble();
        _tempDangerThreshold = (tempData['danger'] ?? 50.0).toDouble();

        _soundThreshold = (soundData['normal'] ?? 60.0).toDouble();
        _soundWarningThreshold = (soundData['warning'] ?? 80.0).toDouble();
        _soundDangerThreshold = (soundData['danger'] ?? 100.0).toDouble();

        // Validate thresholds
        _validateThresholdRelationships();

        // Update notification service
        _updateNotificationServiceThresholds();
      } else {
        _error = 'Failed to load thresholds: ${response.statusCode}';
        // Set default values if fetch fails
        _setDefaultThresholds();
      }
    } catch (e) {
      _error = 'Error loading thresholds: $e';
      // Set default values if there's an error
      _setDefaultThresholds();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setDefaultThresholds() {
    _gasThreshold = 300.0;
    _gasWarningThreshold = 450.0;
    _gasDangerThreshold = 600.0;

    _tempThreshold = 30.0;
    _tempWarningThreshold = 40.0;
    _tempDangerThreshold = 50.0;

    _soundThreshold = 60.0;
    _soundWarningThreshold = 80.0;
    _soundDangerThreshold = 100.0;

    _updateNotificationServiceThresholds();
  }

  // Save thresholds to server
  Future<void> saveThresholds({
    required double gasThreshold,
    required double tempThreshold,
    required double soundThreshold,
    required double gasWarningThreshold,
    required double tempWarningThreshold,
    required double soundWarningThreshold,
    required double gasDangerThreshold,
    required double tempDangerThreshold,
    required double soundDangerThreshold,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _error = 'Not authenticated';
        return;
      }

      // Validate thresholds locally first
      if (!_validateThresholdValues(
        gas: gasThreshold,
        gasWarning: gasWarningThreshold,
        gasDanger: gasDangerThreshold,
        temp: tempThreshold,
        tempWarning: tempWarningThreshold,
        tempDanger: tempDangerThreshold,
        sound: soundThreshold,
        soundWarning: soundWarningThreshold,
        soundDanger: soundDangerThreshold,
      )) {
        return;
      }

      final response = await http
          .post(
        Uri.parse(Config.thresholdsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'gas': {
            'normal': gasThreshold,
            'warning': gasWarningThreshold,
            'danger': gasDangerThreshold,
          },
          'temperature': {
            'normal': tempThreshold,
            'warning': tempWarningThreshold,
            'danger': tempDangerThreshold,
          },
          'sound': {
            'normal': soundThreshold,
            'warning': soundWarningThreshold,
            'danger': soundDangerThreshold,
          },
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Failed to save thresholds');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update local values
        _gasThreshold = gasThreshold;
        _gasWarningThreshold = gasWarningThreshold;
        _gasDangerThreshold = gasDangerThreshold;

        _tempThreshold = tempThreshold;
        _tempWarningThreshold = tempWarningThreshold;
        _tempDangerThreshold = tempDangerThreshold;

        _soundThreshold = soundThreshold;
        _soundWarningThreshold = soundWarningThreshold;
        _soundDangerThreshold = soundDangerThreshold;

        print('Thresholds updated successfully: $data');

        // Update notification service
        _updateNotificationServiceThresholds();
      } else {
        _error = 'Failed to save thresholds: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error saving thresholds: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _validateThresholdRelationships() {
    if (_gasThreshold >= _gasWarningThreshold ||
        _gasWarningThreshold >= _gasDangerThreshold) {
      _error = 'Invalid gas thresholds: normal < warning < danger required';
    }
    if (_tempThreshold >= _tempWarningThreshold ||
        _tempWarningThreshold >= _tempDangerThreshold) {
      _error =
          'Invalid temperature thresholds: normal < warning < danger required';
    }
    if (_soundThreshold >= _soundWarningThreshold ||
        _soundWarningThreshold >= _soundDangerThreshold) {
      _error = 'Invalid sound thresholds: normal < warning < danger required';
    }
  }

  bool _validateThresholdValues({
    required double gas,
    required double gasWarning,
    required double gasDanger,
    required double temp,
    required double tempWarning,
    required double tempDanger,
    required double sound,
    required double soundWarning,
    required double soundDanger,
  }) {
    if (gas >= gasWarning || gasWarning >= gasDanger) {
      _error = 'Invalid gas thresholds: normal < warning < danger required';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    if (temp >= tempWarning || tempWarning >= tempDanger) {
      _error =
          'Invalid temperature thresholds: normal < warning < danger required';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    if (sound >= soundWarning || soundWarning >= soundDanger) {
      _error = 'Invalid sound thresholds: normal < warning < danger required';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    return true;
  }

  void _updateNotificationServiceThresholds() {
    _notificationService.setThresholds(
      gasThreshold: _gasThreshold,
      tempThreshold: _tempThreshold,
      soundThreshold: _soundThreshold,
      gasWarningThreshold: _gasWarningThreshold,
      tempWarningThreshold: _tempWarningThreshold,
      soundWarningThreshold: _soundWarningThreshold,
      gasDangerThreshold: _gasDangerThreshold,
      tempDangerThreshold: _tempDangerThreshold,
      soundDangerThreshold: _soundDangerThreshold,
    );
  }
}
