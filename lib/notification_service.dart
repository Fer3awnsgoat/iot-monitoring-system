import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/notification.dart';
import 'config.dart';
import 'dart:async';

class NotificationService {
  // Storage for secure data
  final _storage = const FlutterSecureStorage();

  // Hardcoded default thresholds
  static const double _defaultGasThreshold = 300.0;
  static const double _defaultTempThreshold = 30.0;
  static const double _defaultSoundThreshold = 60.0;

  static const double _defaultGasWarningThreshold = 450.0;
  static const double _defaultTempWarningThreshold = 40.0;
  static const double _defaultSoundWarningThreshold = 80.0;

  static const double _defaultGasDangerThreshold = 600.0;
  static const double _defaultTempDangerThreshold = 50.0;
  static const double _defaultSoundDangerThreshold = 100.0;

  // Current active thresholds (can be updated from backend/UI)
  double _gasThreshold = _defaultGasThreshold;
  double _tempThreshold = _defaultTempThreshold;
  double _soundThreshold = _defaultSoundThreshold;

  double _gasWarningThreshold = _defaultGasWarningThreshold;
  double _tempWarningThreshold = _defaultTempWarningThreshold;
  double _soundWarningThreshold = _defaultSoundWarningThreshold;

  double _gasDangerThreshold = _defaultGasDangerThreshold;
  double _tempDangerThreshold = _defaultTempDangerThreshold;
  double _soundDangerThreshold = _defaultSoundDangerThreshold;

  // Track last notified states to prevent duplicates
  String? _lastNotifiedGasState;
  String? _lastNotifiedTempState;
  String? _lastNotifiedSoundState;

  // List to store notifications in memory
  final List<AppNotification> _notifications = [];

  // Getter for notifications
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // Getter for thresholds that makes sure all fields are used
  Map<String, Map<String, double>> get currentThresholds => {
        'gas': {
          'normal': _gasThreshold,
          'warning': _gasWarningThreshold,
          'danger': _gasDangerThreshold,
        },
        'temperature': {
          'normal': _tempThreshold,
          'warning': _tempWarningThreshold,
          'danger': _tempDangerThreshold,
        },
        'sound': {
          'normal': _soundThreshold,
          'warning': _soundWarningThreshold,
          'danger': _soundDangerThreshold,
        },
      };

  // Initialize and sync thresholds from backend
  Future<void> initializeThresholds() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        debugPrint('No auth token found for threshold sync');
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
          throw TimeoutException('Failed to fetch thresholds');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Add null checks and default values
        final gasData = data['gas'] ?? {};
        final tempData = data['temperature'] ?? {};
        final soundData = data['sound'] ?? {};

        setThresholds(
          gasThreshold: (gasData['normal'] ?? _defaultGasThreshold).toDouble(),
          tempThreshold:
              (tempData['normal'] ?? _defaultTempThreshold).toDouble(),
          soundThreshold:
              (soundData['normal'] ?? _defaultSoundThreshold).toDouble(),
          gasWarningThreshold:
              (gasData['warning'] ?? _defaultGasWarningThreshold).toDouble(),
          tempWarningThreshold:
              (tempData['warning'] ?? _defaultTempWarningThreshold).toDouble(),
          soundWarningThreshold:
              (soundData['warning'] ?? _defaultSoundWarningThreshold)
                  .toDouble(),
          gasDangerThreshold:
              (gasData['danger'] ?? _defaultGasDangerThreshold).toDouble(),
          tempDangerThreshold:
              (tempData['danger'] ?? _defaultTempDangerThreshold).toDouble(),
          soundDangerThreshold:
              (soundData['danger'] ?? _defaultSoundDangerThreshold).toDouble(),
        );
      } else {
        debugPrint('Failed to fetch thresholds: ${response.body}');
        // Set default values if fetch fails
        setThresholds(
          gasThreshold: _defaultGasThreshold,
          tempThreshold: _defaultTempThreshold,
          soundThreshold: _defaultSoundThreshold,
          gasWarningThreshold: _defaultGasWarningThreshold,
          tempWarningThreshold: _defaultTempWarningThreshold,
          soundWarningThreshold: _defaultSoundWarningThreshold,
          gasDangerThreshold: _defaultGasDangerThreshold,
          tempDangerThreshold: _defaultTempDangerThreshold,
          soundDangerThreshold: _defaultSoundDangerThreshold,
        );
      }
    } catch (e) {
      debugPrint('Error syncing thresholds: $e');
      // Set default values if there's an error
      setThresholds(
        gasThreshold: _defaultGasThreshold,
        tempThreshold: _defaultTempThreshold,
        soundThreshold: _defaultSoundThreshold,
        gasWarningThreshold: _defaultGasWarningThreshold,
        tempWarningThreshold: _defaultTempWarningThreshold,
        soundWarningThreshold: _defaultSoundWarningThreshold,
        gasDangerThreshold: _defaultGasDangerThreshold,
        tempDangerThreshold: _defaultTempDangerThreshold,
        soundDangerThreshold: _defaultSoundDangerThreshold,
      );
    }
  }

  // Method to update thresholds externally
  void setThresholds({
    required double gasThreshold,
    required double tempThreshold,
    required double soundThreshold,
    required double gasWarningThreshold,
    required double tempWarningThreshold,
    required double soundWarningThreshold,
    required double gasDangerThreshold,
    required double tempDangerThreshold,
    required double soundDangerThreshold,
  }) {
    // Update active thresholds
    _gasThreshold = gasThreshold;
    _tempThreshold = tempThreshold;
    _soundThreshold = soundThreshold;

    _gasWarningThreshold = gasWarningThreshold;
    _tempWarningThreshold = tempWarningThreshold;
    _soundWarningThreshold = soundWarningThreshold;

    _gasDangerThreshold = gasDangerThreshold;
    _tempDangerThreshold = tempDangerThreshold;
    _soundDangerThreshold = soundDangerThreshold;

    debugPrint('NotificationService active thresholds updated');
  }

  // Process sensor data and trigger notifications if needed
  Future<void> processSensorData({
    double? gasLevel,
    double? temperature,
    double? soundLevel,
  }) async {
    debugPrint('NotificationService: Starting to process sensor data');
    debugPrint(
        'Current values - Gas: $gasLevel, Temp: $temperature, Sound: $soundLevel');

    // Create a list to store all notifications that need to be created
    List<Map<String, dynamic>> notificationsToCreate = [];

    // Determine current state for each sensor
    String? currentGasState;
    if (gasLevel != null) {
      if (gasLevel >= _gasDangerThreshold) {
        currentGasState = 'danger';
      } else if (gasLevel >= _gasWarningThreshold) {
        currentGasState = 'warning';
      } else {
        currentGasState = 'normal';
      }
      debugPrint(
          'Gas state: $currentGasState (Value: $gasLevel, Warning: $_gasWarningThreshold, Danger: $_gasDangerThreshold)');
    }

    String? currentTempState;
    if (temperature != null) {
      if (temperature >= _tempDangerThreshold) {
        currentTempState = 'danger';
      } else if (temperature >= _tempWarningThreshold) {
        currentTempState = 'warning';
      } else {
        currentTempState = 'normal';
      }
      debugPrint(
          'Temperature state: $currentTempState (Value: $temperature, Warning: $_tempWarningThreshold, Danger: $_tempDangerThreshold)');
    }

    String? currentSoundState;
    if (soundLevel != null) {
      if (soundLevel >= _soundDangerThreshold) {
        currentSoundState = 'danger';
      } else if (soundLevel >= _soundWarningThreshold) {
        currentSoundState = 'warning';
      } else {
        currentSoundState = 'normal';
      }
      debugPrint(
          'Sound state: $currentSoundState (Value: $soundLevel, Warning: $_soundWarningThreshold, Danger: $_soundDangerThreshold)');
    }

    // Process gas level against thresholds if state changed
    if (gasLevel != null && currentGasState != null) {
      if (currentGasState != _lastNotifiedGasState) {
        notificationsToCreate.add({
          'type': 'gas',
          'status': currentGasState,
          'message': currentGasState == 'danger'
              ? 'Gas level is critically high: ${gasLevel.toStringAsFixed(2)}ppm'
              : currentGasState == 'warning'
                  ? 'Gas level is high: ${gasLevel.toStringAsFixed(2)}ppm'
                  : 'Gas level is normal: ${gasLevel.toStringAsFixed(2)}ppm',
          'value': gasLevel,
        });
        _lastNotifiedGasState = currentGasState;
      }
    }

    // Process temperature against thresholds if state changed
    if (temperature != null && currentTempState != null) {
      if (currentTempState != _lastNotifiedTempState) {
        notificationsToCreate.add({
          'type': 'temperature',
          'status': currentTempState,
          'message': currentTempState == 'danger'
              ? 'Temperature is critically high: ${temperature.toStringAsFixed(1)}°C'
              : currentTempState == 'warning'
                  ? 'Temperature is high: ${temperature.toStringAsFixed(1)}°C'
                  : 'Temperature is normal: ${temperature.toStringAsFixed(1)}°C',
          'value': temperature,
        });
        _lastNotifiedTempState = currentTempState;
      }
    }

    // Process sound level against thresholds if state changed
    if (soundLevel != null && currentSoundState != null) {
      if (currentSoundState != _lastNotifiedSoundState) {
        notificationsToCreate.add({
          'type': 'sound',
          'status': currentSoundState,
          'message': currentSoundState == 'danger'
              ? 'Sound level is critically high: ${soundLevel.toStringAsFixed(1)}dB'
              : currentSoundState == 'warning'
                  ? 'Sound level is high: ${soundLevel.toStringAsFixed(1)}dB'
                  : 'Sound level is normal: ${soundLevel.toStringAsFixed(1)}dB',
          'value': soundLevel,
        });
        _lastNotifiedSoundState = currentSoundState;
      }
    }

    // Only proceed if there are notifications to create
    if (notificationsToCreate.isNotEmpty) {
      debugPrint(
          'NotificationService: Creating ${notificationsToCreate.length} notifications');

      // Create all notifications in a single batch
      for (var notificationData in notificationsToCreate) {
        try {
          await _createNotification(
            type: notificationData['type'],
            status: notificationData['status'],
            message: notificationData['message'],
            value: notificationData['value'],
          );
        } catch (e) {
          debugPrint('NotificationService: Error creating notification: $e');
          // Continue with other notifications even if one fails
        }
      }
    } else {
      debugPrint('NotificationService: No new notifications needed');
    }
  }

  // Private method to create and store notifications
  Future<void> _createNotification({
    required String type,
    required String status,
    required String message,
    required double value,
  }) async {
    debugPrint(
        'NotificationService: Creating notification for $type with status $status');

    // Create notification object
    final notification = AppNotification(
      type: type,
      status: status,
      message: message,
      value: value,
    );

    // Add to in-memory list
    _notifications.add(notification);

    // Send to backend for email notification
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        debugPrint('NotificationService: No auth token found for notification');
        return;
      }

      final response = await http
          .post(
        Uri.parse(Config.notificationsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': type,
          'status': status,
          'message': message,
          'value': value,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      )
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Notification request timed out');
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
            'NotificationService: Failed to send notification: ${response.statusCode} - ${response.body}');
      } else {
        debugPrint('NotificationService: Notification sent successfully');
      }
    } catch (e) {
      debugPrint('NotificationService: Error sending notification: $e');
      // Don't rethrow the error, just log it
    }
  }

  // Clear all notifications and reset last notified states
  void clearNotifications() {
    _notifications.clear();
    _lastNotifiedGasState = null;
    _lastNotifiedTempState = null;
    _lastNotifiedSoundState = null;
  }
}
