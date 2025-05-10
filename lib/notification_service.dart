import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/notification.dart';
import 'config.dart';

class NotificationService {
  // Storage for secure data
  final _storage = const FlutterSecureStorage();

  // Normal thresholds (maximum value for normal state)
  double _gasThreshold = 300.0;
  double _tempThreshold = 30.0;
  double _soundThreshold = 60.0;

  // Warning thresholds (maximum value before becoming dangerous)
  double _gasWarningThreshold = 450.0;
  double _tempWarningThreshold = 40.0;
  double _soundWarningThreshold = 80.0;

  // Danger thresholds (value that triggers an alert)
  double _gasDangerThreshold = 600.0;
  double _tempDangerThreshold = 50.0;
  double _soundDangerThreshold = 100.0;

  // List to store notifications in memory
  final List<AppNotification> _notifications = [];

  // Getter for notifications
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // Method to update thresholds externally
  void setThresholds({
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
  }) {
    // Update normal thresholds
    _gasThreshold = gasThreshold;
    _tempThreshold = tempThreshold;
    _soundThreshold = soundThreshold;

    // Update warning thresholds
    _gasWarningThreshold = gasWarningThreshold;
    _tempWarningThreshold = tempWarningThreshold;
    _soundWarningThreshold = soundWarningThreshold;

    // Update danger thresholds
    _gasDangerThreshold = gasDangerThreshold;
    _tempDangerThreshold = tempDangerThreshold;
    _soundDangerThreshold = soundDangerThreshold;

    debugPrint('NotificationService thresholds updated');
  }

  // Process sensor data and trigger notifications if needed
  Future<void> processSensorData({
    double? gasLevel,
    double? temperature,
    double? soundLevel,
  }) async {
    // Process gas level against thresholds
    if (gasLevel != null) {
      if (gasLevel > _gasDangerThreshold) {
        await _createNotification(
          type: 'gas',
          status: 'dangerous',
          message: 'Gas level is too high: ${gasLevel.toStringAsFixed(2)}ppm',
          value: gasLevel,
        );
      } else if (gasLevel > _gasWarningThreshold) {
        await _createNotification(
          type: 'gas',
          status: 'warning',
          message: 'Gas level is high: ${gasLevel.toStringAsFixed(2)}ppm',
          value: gasLevel,
        );
      } else if (gasLevel > _gasThreshold) {
        await _createNotification(
          type: 'gas',
          status: 'normal',
          message: 'Gas level is normal: ${gasLevel.toStringAsFixed(2)}ppm',
          value: gasLevel,
        );
      }
    }

    // Process temperature against thresholds
    if (temperature != null) {
      if (temperature > _tempDangerThreshold) {
        await _createNotification(
          type: 'temperature',
          status: 'dangerous',
          message:
              'Temperature is too high: ${temperature.toStringAsFixed(1)}°C',
          value: temperature,
        );
      } else if (temperature > _tempWarningThreshold) {
        await _createNotification(
          type: 'temperature',
          status: 'warning',
          message: 'Temperature is high: ${temperature.toStringAsFixed(1)}°C',
          value: temperature,
        );
      } else if (temperature > _tempThreshold) {
        await _createNotification(
          type: 'temperature',
          status: 'normal',
          message: 'Temperature is normal: ${temperature.toStringAsFixed(1)}°C',
          value: temperature,
        );
      }
    }

    // Process sound level against thresholds
    if (soundLevel != null) {
      if (soundLevel > _soundDangerThreshold) {
        await _createNotification(
          type: 'sound',
          status: 'dangerous',
          message:
              'Sound level is too high: ${soundLevel.toStringAsFixed(1)}dB',
          value: soundLevel,
        );
      } else if (soundLevel > _soundWarningThreshold) {
        await _createNotification(
          type: 'sound',
          status: 'warning',
          message: 'Sound level is high: ${soundLevel.toStringAsFixed(1)}dB',
          value: soundLevel,
        );
      } else if (soundLevel > _soundThreshold) {
        await _createNotification(
          type: 'sound',
          status: 'normal',
          message: 'Sound level is normal: ${soundLevel.toStringAsFixed(1)}dB',
          value: soundLevel,
        );
      }
    }
  }

  // Private method to create and store notifications
  Future<void> _createNotification({
    required String type,
    required String status,
    required String message,
    required double value,
  }) async {
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
        debugPrint('No auth token found for notification');
        return;
      }

      final response = await http.post(
        Uri.parse('${Config.baseUrl}/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(notification.toJson()),
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to send notification to backend: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  // Clear all notifications
  void clearNotifications() {
    _notifications.clear();
  }
}
