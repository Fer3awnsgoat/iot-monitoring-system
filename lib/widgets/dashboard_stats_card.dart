import 'package:flutter/material.dart';

class DashboardStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const DashboardStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        // Change the background color to a more visible one
        color: Colors.blueGrey.withAlpha((255 * 0.3).round()), // Use withAlpha
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: color.withAlpha(
              (255 * 0.3).round()), // Keep border related to passed color
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon and Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withAlpha((255 * 0.8).round()),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const Spacer(), // Pushes value and unit down
          // Value Text
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27, // Larger font for the value
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Unit Text
          Text(
            unit,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
