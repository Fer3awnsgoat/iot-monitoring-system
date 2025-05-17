import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../models/pending_user.dart';
import '../providers/auth_provider.dart';
import '../widgets/common_background.dart';
import '../config.dart';

class RegistrationRequestsScreen extends StatefulWidget {
  const RegistrationRequestsScreen({super.key});

  @override
  State<RegistrationRequestsScreen> createState() =>
      _RegistrationRequestsScreenState();
}

class _RegistrationRequestsScreenState
    extends State<RegistrationRequestsScreen> {
  bool _isLoading = true;
  String? _error;
  List<PendingUser> _pendingUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
  }

  Future<void> _fetchPendingUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.isAuthenticated
          ? await const FlutterSecureStorage().read(key: 'auth_token')
          : null;

      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/admin/pending-registrations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _pendingUsers = data.map((json) => PendingUser.fromJson(json)).toList();
      } else {
        final data = jsonDecode(response.body);
        _error = data['error'] ?? 'Failed to load pending registrations';
      }
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processRegistration(String id, String decision) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.isAuthenticated
          ? await const FlutterSecureStorage().read(key: 'auth_token')
          : null;

      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${Config.baseUrl}/admin/registration-decision/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'decision': decision,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decision == 'approve'
                ? 'Registration approved successfully'
                : 'Registration rejected'),
            backgroundColor:
                decision == 'approve' ? Colors.green : Colors.orange,
          ),
        );

        await _fetchPendingUsers();
      } else {
        if (!mounted) return;

        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Action failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CommonBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: SafeArea(
                        child: BackButton(color: Color(0xFFE07A5F)),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Registration Requests',
                        style: TextStyle(
                            color: Color(0xFFE07A5F),
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon:
                            const Icon(Icons.refresh, color: Color(0xFFE07A5F)),
                        onPressed: _fetchPendingUsers,
                        tooltip: 'Refresh Requests',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPendingUsers,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _pendingUsers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchPendingUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_pendingUsers.isEmpty) {
      return const Center(
        child: Text(
          'No pending registration requests',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final pendingUser = _pendingUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: const Color(0xFF1565C0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFF9800),
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pendingUser.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pendingUser.email,
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Requested on: ${_formatDate(pendingUser.createdAt)}',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showConfirmDialog(
                        pendingUser.id,
                        pendingUser.username,
                        'reject',
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showConfirmDialog(
                        pendingUser.id,
                        pendingUser.username,
                        'approve',
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showConfirmDialog(
      String id, String username, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'approve' ? 'Approve Registration' : 'Reject Registration',
        ),
        content: Text(
          'Are you sure you want to $action the registration request for $username?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action == 'approve' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _processRegistration(id, action);
    }
  }
}
