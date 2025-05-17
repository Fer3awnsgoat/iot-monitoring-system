import 'dart:convert'; // For json encoding/decoding
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // HTTP package
import 'package:provider/provider.dart'; // Import provider
import 'package:apppfe/providers/auth_provider.dart'; // Import AuthProvider
import 'package:apppfe/models/user_profile.dart'; // Import UserProfile
import '../config.dart';
import 'dart:io';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('Attempting login to: ${Config.loginEndpoint}');

      final response = await http
          .post(
            Uri.parse(Config.loginEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': _usernameController.text,
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await Provider.of<AuthProvider>(context, listen: false).login(
          data['token'],
          UserProfile(
            name: data['user']['username'],
            email: data['user']['email'],
            role: data['user']['role'] == 'admin'
                ? UserRole.admin
                : UserRole.user,
          ),
        );
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        // Enhanced error handling
        final errorMessage = _parseErrorResponse(response);
        _showErrorSnackBar(errorMessage);
      }
    } on SocketException catch (e) {
      debugPrint('Network Error: ${e.message}');
      _showErrorSnackBar('Network error: Could not reach server');
    } on TimeoutException catch (e) {
      debugPrint('Timeout Error: ${e.message}');
      _showErrorSnackBar('Request timed out. Please check your connection.');
    } catch (e) {
      debugPrint('Unexpected Error: $e');
      _showErrorSnackBar('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseErrorResponse(http.Response response) {
    try {
      final errorBody = json.decode(response.body);
      return errorBody['message'] ?? 'Login failed: Unknown error';
    } catch (_) {
      return 'Login failed with status ${response.statusCode}';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with map image
          Positioned.fill(
            child: Container(
              color: const Color(0xFF001D54), // Darker blue background
              child: Opacity(
                opacity: 0.15, // Slightly higher opacity
                child: Image.asset(
                  'assets/images/worldmap.png',
                  fit: BoxFit.cover,
                  scale: 0.95, // Increased scale value to unzoom a bit
                  alignment: Alignment.center, // Center the zoomed image
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint(
                      'Error loading worldmap.png for background: $error',
                    );
                    return Container();
                  },
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Top container with logo and welcome text
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: const BoxDecoration(
                  color: Colors
                      .transparent, // Make container transparent to show background
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: double.infinity),
                          // LEONI text centered
                          Center(
                            child: ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Color(0xFFFF5722), // Orange
                                    Color(
                                      0xFFFF5722,
                                    ), // Orange (end of first segment)
                                    Color(0xFF834046), // Burgundy/maroon
                                    Color(
                                      0xFF834046,
                                    ), // Burgundy/maroon (end of second segment)
                                    Color(0xFF104BB5), // Blue
                                  ],
                                  stops: [
                                    0.0, // Start with orange
                                    0.41, // Orange ends at 41%
                                    0.42, // Burgundy starts at 42%
                                    0.82, // Burgundy ends at 82%
                                    0.83, // Blue starts at 83%
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'LEONI',
                                style: TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Hello text left-aligned with padding
                          const Padding(
                            padding: EdgeInsets.only(left: 20.0),
                            child: Text(
                              'Hello !',
                              style: TextStyle(
                                fontSize: 50,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: RichText(
                              text: const TextSpan(
                                text: 'welcome to ',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: 'ClimCare',
                                    style: TextStyle(color: Color(0xFFFF5722)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Login form
              Expanded(
                child: Container(
                  color: const Color(0xFF043388),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9800), // Changed to orange
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Username field
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(
                                0xFF1565C0,
                              ), // Dark blue background
                              hintText: 'Username',
                              hintStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Colors.white70,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(
                                0xFF1565C0,
                              ), // Dark blue background
                              hintText: 'Password',
                              hintStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Colors.white70,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Create Account and Forgot Password row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                child: const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    color: Color(0xFFFF9800),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Login button
                          Center(
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Color(0xFFFF9800),
                                  )
                                : SizedBox(
                                    width: 200,
                                    height: 45,
                                    child: ElevatedButton(
                                      onPressed: _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF9800,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            25,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'LOGIN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
