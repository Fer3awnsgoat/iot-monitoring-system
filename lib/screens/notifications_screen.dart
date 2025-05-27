import 'package:flutter/material.dart';
import '../widgets/common_background.dart';
import '../config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;
  final _dateFormat = DateFormat('MMM d, y HH:mm');
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 0;
        _hasMore = true;
        _notifications = [];
      });
    }

    if (!_hasMore) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        setState(() {
          _error = 'Please log in to view notifications';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(
            '${Config.notificationsEndpoint}?page=$_currentPage&limit=$_pageSize'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> newNotifications = jsonDecode(response.body);
        setState(() {
          if (refresh) {
            _notifications = newNotifications;
          } else {
            _notifications.addAll(newNotifications);
          }
          _hasMore = newNotifications.length == _pageSize;
          _currentPage++;
          _isLoading = false;
          _error = null;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Session expired. Please log in again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load notifications. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'No timestamp';
    try {
      final date = DateTime.parse(timestamp);
      return _dateFormat.format(date);
    } catch (e) {
      return 'Invalid timestamp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: CommonBackground(
        child: Column(
          children: [
            // Header Title
            const SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Center(
                  child: Text(
                    'Notifications',
                    style: TextStyle(
                        color: Color(0xFFE07A5F),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            // Main content
            Expanded(
              child: _isLoading && _notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 100,
                                  color: Colors.white.withAlpha(150)),
                              const SizedBox(height: 24),
                              Text(
                                _error!,
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    _fetchNotifications(refresh: true),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : !_isLoading && _notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_off_outlined,
                                      size: 100,
                                      color: Colors.white.withAlpha(150)),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'No Notification Here',
                                    style: TextStyle(
                                        fontSize: 22,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () =>
                                  _fetchNotifications(refresh: true),
                              child: ListView.builder(
                                itemCount:
                                    _notifications.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _notifications.length) {
                                    _fetchNotifications();
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final notification = _notifications[index];
                                  final uniqueKey = Key(
                                      notification['_id'] ?? index.toString());

                                  // Make status color logic robust
                                  String status = (notification['status']
                                          ?.toString()
                                          .toLowerCase()
                                          .trim() ??
                                      '');
                                  Color statusColor;
                                  switch (status) {
                                    case 'danger':
                                    case 'dangerous':
                                      statusColor = Colors.red;
                                      break;
                                    case 'warning':
                                      statusColor = Colors.orange;
                                      break;
                                    case 'normal':
                                      statusColor = Colors.green;
                                      break;
                                    default:
                                      statusColor = Colors.grey;
                                  }

                                  // Build custom card layout
                                  return Dismissible(
                                    key: uniqueKey,
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20.0),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (direction) {
                                      setState(() {
                                        _notifications.removeAt(index);
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Notification dismissed')),
                                      );
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      color: Colors.blueGrey[800],
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${notification['type'] ?? 'Unknown'} Alerts',
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _formatTimestamp(notification[
                                                      'timestamp']),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              notification['message'] ??
                                                  'No message',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (notification['value'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Text(
                                                  '*${notification['value']}',
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
