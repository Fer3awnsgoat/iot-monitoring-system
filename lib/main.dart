import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:apppfe/screens/login_screen.dart';
import 'package:apppfe/screens/register_screen.dart';
import 'package:apppfe/screens/main_screen.dart';
import 'package:apppfe/providers/auth_provider.dart';
import 'package:apppfe/providers/threshold_provider.dart';
import 'notification_service.dart';
import 'dart:io';

// Fonction principal, tkhadem el application (MyApp).
void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (cert, host, port) =>
          true; // Bypass certificate verification (for testing only)
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Tebni el widget el rasmia, thez el providers, t'regl el theme, w tkhtar l'écran loula/les routes.
  @override
  Widget build(BuildContext context) {
    // Create a single instance of NotificationService
    final notificationService = NotificationService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThresholdProvider()),
        Provider.value(value: notificationService),
      ],
      child: MaterialApp(
        title: 'ClimCare',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF043388),
          textTheme: ThemeData.dark().textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF043388),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/main': (context) =>
              MainScreen(notificationService: notificationService),
        },
      ),
    );
  }
}
