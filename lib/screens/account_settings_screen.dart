import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/common_background.dart';
import '../config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_profile.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  // State for Admin User Management
  List<UserProfile> _allUsers = [];
  bool _isFetchingUsers = true;
  String? _usersError;

  @override
  void initState() {
    super.initState();
    // Load current user email
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _emailController.text = authProvider.userProfile?.email ?? '';

    // Fetch all users if admin
    if (authProvider.userProfile?.isAdmin ?? false) {
      _fetchAllUsers();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    // TODO: Dispose other controllers if added for admin section
    super.dispose();
  }

  Future<void> _fetchAllUsers() async {
    setState(() {
      _isFetchingUsers = true;
      _usersError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        setState(() {
          _usersError = 'Authentication token not found.';
          _isFetchingUsers = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(Config.allUsersEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> userData = jsonDecode(response.body);
        setState(() {
          _allUsers =
              userData.map((json) => UserProfile.fromJson(json)).toList();
          _isFetchingUsers = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _usersError = errorData['error'] ?? 'Failed to fetch users.';
          _isFetchingUsers = false;
        });
      }
    } catch (e) {
      setState(() {
        _usersError = 'Network error: ${e.toString()}';
        _isFetchingUsers = false;
      });
    }
  }

  Future<void> _changeEmail() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _isError = false;
    });

    final newEmail = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text.trim();

    if (newEmail.isEmpty || currentPassword.isEmpty) {
      setState(() {
        _isLoading = false;
        _message = 'Please fill in all fields.';
        _isError = true;
      });
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _message = 'Authentication token not found.';
        _isError = true;
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
            '${Config.baseUrl}/auth/change-email'), // Assuming a new endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'newEmail': newEmail,
          'currentPassword': currentPassword,
        }),
      );

      if (response.statusCode == 200) {
        // Update email in AuthProvider
        // await authProvider.updateEmail(newEmail); // Need to check AuthProvider for update method
        setState(() {
          _message = 'Email updated successfully!';
          _isError = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _message = errorData['error'] ?? 'Failed to change email.';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Network error: ${e.toString()}';
        _isError = true;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showEditUserDialog(UserProfile user) {
    // TODO: Implement edit user logic
    UserRole _selectedRole = user.role;

    final _editEmailController = TextEditingController(text: user.email);
    final _adminPasswordController = TextEditingController();
    bool _isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${user.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email field
              TextField(
                controller: _editEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Role:'),
                  const SizedBox(width: 8),
                  DropdownButton<UserRole>(
                    value: _selectedRole,
                    items: UserRole.values.map((role) {
                      return DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (UserRole? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              // TODO: Add other editable fields as needed
              const SizedBox(height: 16),
              // Admin password confirmation
              TextField(
                controller: _adminPasswordController,
                decoration: InputDecoration(
                  labelText: 'Your Password (Admin)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Made async to await the http call
                setState(() {
                  _isSaving = true; // Show loading indicator
                });

                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final token = authProvider.token;

                final newEmail = _editEmailController.text.trim();
                final adminPassword = _adminPasswordController.text.trim();

                if (newEmail.isEmpty || adminPassword.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Please fill in email and your password.')),
                    );
                    setState(() {
                      _isSaving = false;
                    });
                  }
                  return;
                }

                // Check if role or email has changed
                final roleChanged = _selectedRole != user.role;
                final emailChanged = newEmail != user.email;

                if (!roleChanged && !emailChanged) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No changes to save.')),
                    );
                    Navigator.pop(context); // Close dialog if no changes
                  }
                  return;
                }

                // Handle role change if needed
                if (roleChanged) {
                  try {
                    final response = await http.put(
                      Uri.parse(
                          '${Config.baseUrl}/admin/users/${user.id}/role'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode(
                          {'role': _selectedRole.toString().split('.').last}),
                    );

                    if (mounted) {
                      if (response.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Role updated for ${user.name}')),
                        );
                        // Update the user in the local list
                        _updateUserRoleInList(user.id!, _selectedRole,
                            newEmail); // Also pass new email
                        // Don't close dialog yet, as email might also change
                      } else {
                        final errorData = jsonDecode(response.body);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to update role: ${errorData['error'] ?? response.statusCode}')),
                        );
                        setState(() {
                          _isSaving = false;
                        });
                        return; // Stop if role update failed
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Network error updating role: ${e.toString()}')),
                      );
                      setState(() {
                        _isSaving = false;
                      });
                    }
                    return; // Stop if role update failed
                  }
                }

                // Handle email change if needed
                if (emailChanged) {
                  // TODO: Implement backend endpoint for admin to change user email
                  // This will require a new backend route like PUT /admin/users/:userId/email
                  // and verification of the admin's password.
                  try {
                    final emailResponse = await http.put(
                      Uri.parse(
                          '${Config.baseUrl}/admin/users/${user.id}/email'), // New endpoint
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode({
                        'newEmail': newEmail,
                        'adminPassword': adminPassword,
                      }),
                    );

                    if (mounted) {
                      if (emailResponse.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Email updated for ${user.name}')),
                        );
                        // Update email in local list if role wasn't changed, otherwise it was updated above
                        if (!roleChanged) {
                          _updateUserRoleInList(user.id!, user.role, newEmail);
                        }
                        Navigator.pop(context); // Close dialog
                      } else {
                        final errorData = jsonDecode(emailResponse.body);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to update email: ${errorData['error'] ?? emailResponse.statusCode}')),
                        );
                        // Keep dialog open on failure
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Network error updating email: ${e.toString()}')),
                      );
                      // Keep dialog open on failure
                    }
                  }
                } else if (roleChanged) {
                  // If only role changed, close dialog after successful role update
                  Navigator.pop(context);
                }

                setState(() {
                  _isSaving = false;
                }); // Hide loading indicator
              },
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dispose controllers after dialog is closed
      _editEmailController.dispose();
      _adminPasswordController.dispose();
    });
  }

  // Helper to update user role and email in the local list
  void _updateUserRoleInList(String userId, UserRole newRole, String newEmail) {
    final index = _allUsers.indexWhere((user) => user.id == userId);
    if (index != -1) {
      setState(() {
        // Create a new UserProfile with updated role and email
        _allUsers[index] = UserProfile(
          id: _allUsers[index].id,
          name: _allUsers[index].name,
          email: newEmail, // Use the new email
          language: _allUsers[index].language,
          isDarkMode: _allUsers[index].isDarkMode,
          role: newRole,
          phoneNumber: _allUsers[index].phoneNumber,
          company: _allUsers[index].company,
          jobTitle: _allUsers[index].jobTitle,
          avatar: _allUsers[index].avatar,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: CommonBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Text(
                'Change Email',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'New Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _changeEmail,
                      child: const Text('Change Email'),
                    ),
              const SizedBox(height: 16),
              if (_message != null)
                Text(
                  _message!,
                  style: TextStyle(color: _isError ? Colors.red : Colors.green),
                  textAlign: TextAlign.center,
                ),

              // Admin section will be added here later
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.userProfile?.isAdmin ?? false) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        Text(
                          'Admin: Manage Users',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isFetchingUsers)
                          const Center(child: CircularProgressIndicator())
                        else if (_usersError != null)
                          Center(
                            child: Text(
                              _usersError!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else if (_allUsers.isEmpty)
                          const Center(
                            child: Text(
                              'No users found.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap:
                                true, // Important for nested ListView in Column/ListView
                            physics:
                                NeverScrollableScrollPhysics(), // Disable scrolling for nested ListView
                            itemCount: _allUsers.length,
                            itemBuilder: (context, index) {
                              final user = _allUsers[index];
                              // TODO: Add edit functionality
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(user.name),
                                  subtitle: Text(
                                      '${user.email} - ${user.role.toString().split('.').last}'),
                                  trailing: IconButton(
                                    icon: Icon(Icons.edit),
                                    onPressed: () {
                                      _showEditUserDialog(user);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  } else {
                    // Return an empty container if not admin
                    return Container();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
