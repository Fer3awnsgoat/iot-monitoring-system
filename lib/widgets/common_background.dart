import 'package:flutter/material.dart';

/// A reusable widget that provides the common background style
/// (gradient and world map) used across various screens.
class CommonBackground extends StatelessWidget {
  final Widget child;

  const CommonBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Apply the gradient decoration
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF001D54), // Dark blue start
            Color(0xFF000000), // Black end
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background world map image
          Positioned.fill(
            child: Opacity(
              opacity: 0.1, // Subtle opacity
              child: Image.asset(
                'assets/images/worldmap.png', // Make sure this asset exists
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Place the screen content on top
          child,
        ],
      ),
    );
  }
}
