// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http; // Import http package
import '../config.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// Removed Provider import
// Removed SensorDataProvider import
import '../widgets/sensor_chart_widget.dart'; // Assuming this widget exists
import '../widgets/common_background.dart'; // Use common background
import '../models/capteur.dart' as api_model; // Assuming model exists

// Define baseUrl locally or import from a config file

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String? expandedChart; // Stores 'temperature', 'mq2', or 'sound'

  // Local state variables for data, loading, and error
  bool _isLoading = true;
  String? _errorMessage;
  List<api_model.Capteur> _apiDataList = [];

  @override
  void initState() {
    super.initState();
    _fetchApiData(); // Fetch data when screen initializes
  }

  // Function to fetch data directly from API
  Future<void> _fetchApiData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Access the AuthProvider to get the token
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        // Handle case where token is not available (user not logged in)
        setState(() {
          _errorMessage = 'Authentication token not found. Please log in.';
          _apiDataList = [];
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/sensors'),
        headers: {
          // Include the authorization header
          'Authorization': 'Bearer $token',
          'Accept': 'application/json', // Added Accept header for clarity
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        setState(() {
          _apiDataList =
              rawData.map((data) => api_model.Capteur.fromJson(data)).toList();
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'No sensor data available yet.';
          _apiDataList = [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error fetching data: ${response.statusCode}';
          _apiDataList = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not connect to the server.';
        _apiDataList = [];
        _isLoading = false;
      });
    }
  }

  void toggleChartExpansion(String chartId) {
    setState(() {
      if (chartId.isEmpty) {
        expandedChart = null; // Explicitly close
      } else if (expandedChart == chartId) {
        expandedChart = null; // Collapse if already expanded
      } else {
        expandedChart = chartId; // Expand the tapped chart
      }
    });
  }

  // Function to convert List<Capteur> to List<FlSpot>
  List<FlSpot> _prepareChartData(
      List<api_model.Capteur> capteurData, String valueField) {
    if (capteurData.isEmpty) {
      return [];
    }

    // Sort by timestamp ascending for the chart's X-axis
    var sortedData = List<api_model.Capteur>.from(capteurData);
    sortedData.sort((a, b) => (a.timestamp ?? DateTime(0))
        .compareTo(b.timestamp ?? DateTime(0))); // Added null checks

    List<FlSpot> spots = [];
    for (int i = 0; i < sortedData.length; i++) {
      double yValue;
      switch (valueField) {
        case 'temperature':
          yValue = sortedData[i].temperature;
          break;
        case 'mq2':
          yValue = sortedData[i].mq2;
          break;
        case 'sound':
          yValue = sortedData[i].sound;
          break;
        default:
          yValue = 0.0;
      }
      spots.add(FlSpot(i.toDouble(), yValue));
    }
    return spots;
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    // Removed sensorProvider usage

    // Loading State - Show only on initial load when list is empty
    if (_isLoading && _apiDataList.isEmpty) {
      return Scaffold(
        body: CommonBackground(
          child: Column(
            children: [
              _buildHeader('Analytics'), // Use string literal
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error State - Show only for critical errors, otherwise show empty charts
    // Check for critical errors specifically
    bool isCriticalError = _errorMessage != null &&
        _errorMessage != 'No sensor data available yet.';

    if (isCriticalError && _apiDataList.isEmpty) {
      // Only show full screen error for connection errors etc. when no data loaded yet
      return Scaffold(
        body: CommonBackground(
          child: Column(
            children: [
              _buildHeader('Analytics'), // Use string literal
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _errorMessage!, // Use local error message
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If loading is finished, or if it's not a critical error,
    // proceed to build the main view (even if data is empty)

    // Prepare chart data using local _apiDataList (will be empty if no data)
    final temperatureData = _prepareChartData(_apiDataList, 'temperature');
    final mq2Data = _prepareChartData(_apiDataList, 'mq2');
    final soundData = _prepareChartData(_apiDataList, 'sound');

    // Expanded Chart View
    if (expandedChart != null) {
      return _buildExpandedView(temperatureData, mq2Data, soundData);
    }

    // Regular View
    return _buildRegularView(temperatureData, mq2Data, soundData);
  }

  // Build the standard header
  Widget _buildHeader(String title, {bool showBackButton = false}) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: kToolbarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showBackButton)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: BackButton(
                    color: const Color(0xFFE07A5F),
                    onPressed: () =>
                        toggleChartExpansion(""), // Action to close
                  ),
                ),
              ),
            Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE07A5F),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Add Refresh Button to header
            if (!showBackButton) // Show only in main view
              Positioned(
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFE07A5F)),
                  onPressed: _fetchApiData, // Call fetch function
                  tooltip: 'Refresh Data',
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build the view when a chart is expanded
  Widget _buildExpandedView(List<FlSpot> temperatureData, List<FlSpot> mq2Data,
      List<FlSpot> soundData) {
    List<FlSpot> expandedSpots;
    String expandedTitle;
    String expandedSensorName;

    switch (expandedChart) {
      case "temperature":
        expandedSpots = temperatureData;
        expandedTitle = 'Temperature';
        expandedSensorName = "DHT11 Temperature";
        break;
      case "mq2":
        expandedSpots = mq2Data;
        expandedTitle = "MQ-2";
        expandedSensorName = "MQ-2 Gas Level";
        break;
      case "sound":
      default:
        expandedSpots = soundData;
        expandedTitle = 'Sound Detection';
        expandedSensorName = "Sound Sensor";
        break;
    }

    return Scaffold(
      body: CommonBackground(
        child: Column(
          children: [
            _buildHeader(expandedTitle,
                showBackButton: true), // Header with back
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SensorChartWidget(
                  spots: expandedSpots,
                  title: expandedTitle,
                  sensorName: expandedSensorName,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build the regular view showing all charts
  Widget _buildRegularView(List<FlSpot> temperatureData, List<FlSpot> mq2Data,
      List<FlSpot> soundData) {
    return Scaffold(
      body: CommonBackground(
        child: Column(
          children: [
            _buildHeader('Analytics'), // Standard Header with Refresh
            Expanded(
              child: RefreshIndicator(
                // Add RefreshIndicator
                onRefresh: _fetchApiData, // Link to fetch function
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Ensure scroll works with RefreshIndicator
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTappableChart(
                        "temperature",
                        SensorChartWidget(
                          spots: temperatureData,
                          title: 'Temperature',
                          sensorName: 'DHT11 Temperature',
                          titleColor: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTappableChart(
                        "mq2",
                        SensorChartWidget(
                          spots: mq2Data,
                          title: 'MQ-2',
                          sensorName: 'MQ-2 Gas Level',
                          titleColor: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTappableChart(
                        "sound",
                        SensorChartWidget(
                          spots: soundData,
                          title: 'Sound Detection',
                          sensorName: 'Sound Sensor',
                          titleColor: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 76), // Spacing above nav bar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Wraps chart to make it tappable for expansion
  Widget _buildTappableChart(String chartId, Widget chartWidget) {
    return GestureDetector(
      onTap: () => toggleChartExpansion(chartId),
      child: Stack(
        children: [
          chartWidget,
          Positioned(
            bottom: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((255 * 0.4).round()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
