import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorChartWidget extends StatelessWidget {
  final List<FlSpot> spots;
  final String title;
  final String sensorName;
  final Color titleColor;
  final String timeRange; // Keep this if you plan to add time range selection
  final List<Color> gradientColors;
  final double? minY;
  final double? maxY;

  const SensorChartWidget({
    super.key,
    required this.spots,
    required this.title,
    required this.sensorName,
    this.titleColor = Colors.orange,
    this.timeRange = '--', // Default or placeholder
    this.gradientColors = const [Color(0xff23b6e6), Color(0xff02d39a)],
    this.minY,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate min/max Y values robustly
    double calculatedMinY = 0;
    double calculatedMaxY = 10; // Default range if no spots

    if (spots.isNotEmpty) {
      calculatedMinY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      calculatedMaxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    }

    // Apply overrides if provided
    calculatedMinY = minY ?? calculatedMinY;
    calculatedMaxY = maxY ?? calculatedMaxY;

    // Ensure max > min, add padding if max is not overridden
    if (calculatedMinY >= calculatedMaxY) {
      calculatedMaxY = calculatedMinY + 1; // Ensure max is always > min
    } else if (maxY == null) {
      // Add some top padding if maxY wasn't explicitly set
      double range = calculatedMaxY - calculatedMinY;
      calculatedMaxY += range * 0.1; // Add 10% padding
    }
    if (minY == null && calculatedMinY != 0) {
      // Add some bottom padding if minY wasn't explicitly set and isn't zero
      double range = calculatedMaxY - calculatedMinY;
      calculatedMinY -= range * 0.1;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Adjusted padding
      decoration: BoxDecoration(
        // Consistent styling with Dashboard cards
        color: Colors.blueGrey.withAlpha((255 * 0.3).round()),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.blueGrey.withAlpha((255 * 0.5).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Prevent column from taking max height
        children: [
          // Title and Sensor Name Row
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: Title and Sensor Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor, // Use passed title color
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sensorName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // Right side: Time Range (optional display)
                // If you add time range selection later, put UI here
                // Example: Text(timeRange, style: TextStyle(...))
              ],
            ),
          ),

          // Chart Area
          SizedBox(
            height: 180, // Fixed height for chart
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: (calculatedMaxY - calculatedMinY) / 4,
                  verticalInterval: spots.isNotEmpty ? spots.length / 4 : 1,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Colors.white12,
                      strokeWidth: 0.8,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return const FlLine(
                      color: Colors.white12,
                      strokeWidth: 0.8,
                    );
                  },
                ),
                titlesData: const FlTitlesData(
                  show: true,
                  // Hide all titles for cleaner look, customize if needed
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.white.withAlpha((255 * 0.1).round()),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: spots.isNotEmpty ? (spots.length - 1).toDouble() : 1.0,
                minY: calculatedMinY,
                maxY: calculatedMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(colors: gradientColors),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: gradientColors
                            .map(
                                (color) => color.withAlpha((255 * 0.3).round()))
                            .toList(),
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                // Optional: Add tooltip behavior
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true, // Enable default touches
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;
                        // You might need access to the original data point
                        // if x is just index and you need timestamp
                        return LineTooltipItem(
                          flSpot.y.toStringAsFixed(1),
                          const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          // Removed the redundant expand button, as parent handles tap
        ],
      ),
    );
  }
}
