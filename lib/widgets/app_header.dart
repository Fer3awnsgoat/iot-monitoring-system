import 'package:flutter/material.dart';

/// Simple AppBar-like header widget
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final double elevation;

  const AppHeader({super.key, required this.title, this.elevation = 0});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(
        0xFF043388,
      ).withAlpha(200), // Semi-transparent dark blue
      elevation: elevation,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      automaticallyImplyLeading: false, // Remove back button if not needed
      centerTitle: true, // Center the title
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
