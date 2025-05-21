import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/notification.dart'
    as app_notification; // Import with a prefix
import '../config.dart'; // Assuming you have a config file for your API base URL

class NotificationProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  List<app_notification.Notification> _notifications =
      []; // Use the prefixed name
  bool _isLoading = false;
  String? _error;

  List<app_notification.Notification> get notifications =>
      _notifications; // Use the prefixed name
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchNotifications() async {
    debugPrint('Fetching notifications...');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _error = 'No authentication token found';
        debugPrint('Error: $_error');
        return;
      }

      final url = Uri.parse(
          Config.notificationsEndpoint); // Use the correct endpoint from Config
      debugPrint('Fetching from URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> notificationsJson = json.decode(response.body);
        _notifications = notificationsJson
            .map((json) => app_notification.Notification.fromJson(json))
            .toList(); // Use the prefixed name
        debugPrint('Fetched ${_notifications.length} notifications');
      } else {
        _error = 'Failed to load notifications: ${response.statusCode}';
        debugPrint('Error: $_error');
      }
    } catch (e) {
      _error = 'Error fetching notifications: ${e.toString()}';
      debugPrint('Exception: $_error');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    debugPrint('Deleting notification: $id');
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _error = 'No authentication token found';
        debugPrint('Error: $_error');
        return;
      }

      final url = Uri.parse(
          '${Config.notificationsEndpoint}/$id'); // Use the correct endpoint from Config
      debugPrint('Delete URL: $url');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('Delete response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _notifications.removeWhere((notification) => notification.id == id);
        debugPrint('Notification deleted successfully');
        notifyListeners();
      } else {
        _error = 'Failed to delete notification: ${response.statusCode}';
        debugPrint('Delete error: $_error');
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error deleting notification: ${e.toString()}';
      debugPrint('Delete exception: $_error');
      notifyListeners();
    }
  }

  // You might add other methods like markAsRead, etc.
}
