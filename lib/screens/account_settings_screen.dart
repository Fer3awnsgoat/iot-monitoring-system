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
    // Initialize controllers with current user data
    final _editEmailController = TextEditingController(text: user.email);
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    final _adminPasswordController = TextEditingController();
    UserRole _selectedRole = user.role;
    String? _passwordError = null; // Clear previous errors
    bool _isSaving = false;

    debugPrint(
        'AccountSettingsScreen: Showing edit user dialog for ${user.name}');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white, // Set dialog background to white
          title: Text('Edit ${user.name}',
              style: TextStyle(color: Colors.black87)), // Adjust title color
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email field
                TextField(
                  controller: _editEmailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    labelStyle:
                        TextStyle(color: Colors.black54), // Adjust label color
                    prefixIconColor: Colors.black54, // Adjust icon color
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.black38), // Adjust border color
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Colors.blueAccent), // Adjust focused color
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                      color: Colors.black87), // Adjust input text color
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Role:',
                        style: TextStyle(
                            color: Colors.black87)), // Adjust text color
                    const SizedBox(width: 8),
                    DropdownButton<UserRole>(
                      value: _selectedRole,
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(role.toString().split('.').last,
                              style: TextStyle(
                                  color: Colors
                                      .black87)), // Adjust dropdown text color
                        );
                      }).toList(),
                      onChanged: (UserRole? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedRole = newValue;
                          });
                        }
                      },
                      dropdownColor:
                          Colors.white, // Adjust dropdown menu background
                      style: TextStyle(
                          color: Colors
                              .black87), // Adjust selected item text color
                    ),
                  ],
                ),
                // TODO: Add other editable fields as needed
                const SizedBox(height: 16),
                // Password fields
                Text('Change Password (Optional)',
                    style: TextStyle(
                        color: Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    labelStyle: TextStyle(color: Colors.black54),
                    prefixIconColor: Colors.black54,
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black38)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black38)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent)),
                    errorText: _passwordError,
                  ),
                  obscureText: true,
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    labelStyle: TextStyle(color: Colors.black54),
                    prefixIconColor: Colors.black54,
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black38)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black38)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                  obscureText: true,
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                // Admin password confirmation
                TextField(
                  controller: _adminPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Your Password (Admin)',
                    prefixIcon: Icon(Icons.lock_outline),
                    labelStyle: TextStyle(color: Colors.black54),
                    prefixIconColor: Colors.black54,
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black38)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black38)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                  obscureText: true,
                  style: TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint(
                    'AccountSettingsScreen: Cancel button pressed in edit user dialog');
                // Dispose controllers before closing dialog
                // debugPrint(
                //     'AccountSettingsScreen: Disposing _editEmailController');
                // _editEmailController.dispose();
                // debugPrint(
                //     'AccountSettingsScreen: Disposing _newPasswordController');
                // _newPasswordController.dispose();
                // debugPrint(
                //     'AccountSettingsScreen: Disposing _confirmPasswordController');
                // _confirmPasswordController.dispose();
                // debugPrint(
                //     'AccountSettingsScreen: Disposing _adminPasswordController');
                // _adminPasswordController.dispose();
                debugPrint('AccountSettingsScreen: Popping edit user dialog');
                Navigator.of(context).pop();
              },
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
            TextButton(
              onPressed: () async {
                // Made async to await the http call
                setState(() {
                  _isSaving = true; // Show loading indicator
                  _passwordError = null; // Clear previous password error
                });

                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final token = authProvider.token;

                final newEmail = _editEmailController.text.trim();
                final newPassword = _newPasswordController.text;
                final confirmPassword = _confirmPasswordController.text;
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
                final passwordChanged =
                    newPassword.isNotEmpty; // Check if password fields are used

                // Validate password if changed
                if (passwordChanged) {
                  if (newPassword != confirmPassword) {
                    setState(() {
                      _passwordError = 'Passwords do not match.';
                      _isSaving = false;
                    });
                    return;
                  }
                  // Add more password validation (e.g., length) if needed
                }

                if (!roleChanged && !emailChanged && !passwordChanged) {
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
                        // Update the user in the local list - email updated later if needed
                        _updateUserInList(user.id!, _selectedRole,
                            user.email); // Use old email for now
                        // Don't close dialog yet, as email/password might also change
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
                        // Update email in local list if role wasn't changed
                        if (!roleChanged) {
                          _updateUserInList(user.id!, user.role, newEmail);
                        } else {
                          // If role also changed, update email in the item already updated for role
                          final index =
                              _allUsers.indexWhere((u) => u.id == user.id);
                          if (index != -1) {
                            setState(() {
                              _allUsers[index] = UserProfile(
                                id: _allUsers[index].id,
                                name: _allUsers[index].name,
                                email: newEmail, // Update email
                                language: _allUsers[index].language,
                                isDarkMode: _allUsers[index].isDarkMode,
                                role:
                                    _allUsers[index].role, // Keep updated role
                                phoneNumber: _allUsers[index].phoneNumber,
                                company: _allUsers[index].company,
                                jobTitle: _allUsers[index].jobTitle,
                                avatar: _allUsers[index].avatar,
                              );
                            });
                          }
                        }
                        // Don't close dialog yet, as password might also change
                      } else {
                        final errorData = jsonDecode(emailResponse.body);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to update email: ${errorData['error'] ?? emailResponse.statusCode}')),
                        );
                        setState(() {
                          _isSaving = false;
                        });
                        return; // Stop if email update failed
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Network error updating email: ${e.toString()}')),
                      );
                      setState(() {
                        _isSaving = false;
                      });
                    }
                    return; // Stop if email update failed
                  }
                }

                // Handle password change if needed
                if (passwordChanged) {
                  // TODO: Implement backend endpoint for admin to change user password
                  // This will require a new backend route like PUT /admin/users/:userId/password
                  // and verification of the admin's password.
                  try {
                    final passwordResponse = await http.put(
                      Uri.parse(
                          '${Config.baseUrl}/admin/users/${user.id}/password'), // New endpoint
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode({
                        'newPassword': newPassword,
                        'adminPassword': adminPassword,
                      }),
                    );

                    if (mounted) {
                      if (passwordResponse.statusCode == 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Password updated for ${user.name}')),
                        );
                        // Password change doesn't affect local UserProfile object visible in list
                        // Close dialog only after all changes are attempted/successful
                      } else {
                        final errorData = jsonDecode(passwordResponse.body);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to update password: ${errorData['error'] ?? passwordResponse.statusCode}')),
                        );
                        setState(() {
                          _isSaving = false;
                        });
                        return; // Stop if password update failed
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Network error updating password: ${e.toString()}')),
                      );
                      setState(() {
                        _isSaving = false;
                      });
                    }
                    return; // Stop if password update failed
                  }
                }

                // Close dialog if at least one change was attempted and successful
                if (roleChanged || emailChanged || passwordChanged) {
                  if (mounted && _isSaving == false) {
                    // Check _isSaving to ensure no pending operation
                    Navigator.pop(context);
                  }
                }

                setState(() {
                  _isSaving = false;
                }); // Hide loading indicator
              },
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blueAccent)), // Adjust color
                    )
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.blueAccent)), // Adjust button color
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dispose controllers after dialog is closed
      _editEmailController.dispose();
      _newPasswordController.dispose();
      _confirmPasswordController.dispose();
      _adminPasswordController.dispose();
    });
  }

  // Helper to update user role and email in the local list
  void _updateUserInList(String userId, UserRole newRole, String newEmail) {
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
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.userProfile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Accounts' : 'My Account'),
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
