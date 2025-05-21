import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../notification_service.dart';
import '../widgets/common_background.dart';
import '../widgets/dashboard_stats_card.dart';
import '../config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Colors for stat cards
const Color _tempColor = Color(0xFFAA44C8);
const Color _mq2Color = Color(0xFF15355E);
const Color _soundColor = Color(0xFFE07A5F); // Example color

/// Simplified dashboard screen fetching data directly from API
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ===== State Variables =====
  String _selectedHours = '1H';
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _latestSensorData;
  List<Map<String, dynamic>> _sensorHistory = [];
  List<Map<String, dynamic>> _allDataCache = []; // Cache all fetched data

  // Notification service
  final NotificationService _notificationService = NotificationService();

  // Formatter for display
  final DateFormat _timeFormatter = DateFormat('HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    debugPrint('Dashboard: Starting to fetch data');
    if (!mounted) {
      debugPrint('Dashboard: Widget not mounted, aborting fetch');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    debugPrint('Dashboard: Set loading state');

    try {
      // Get auth token
      debugPrint('Dashboard: Getting auth token');
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (token == null) {
        debugPrint('Dashboard: No auth token found');
        setState(() {
          _errorMessage = 'Not authenticated. Please login again.';
          _isLoading = false;
        });
        return;
      }
      debugPrint('Dashboard: Auth token retrieved successfully');

      // Test connection first
      try {
        debugPrint('Dashboard: Testing backend connection');
        final testResponse = await http.get(
          Uri.parse('${Config.baseUrl}/health'),
          headers: {
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));

        if (testResponse.statusCode != 200) {
          debugPrint(
              'Dashboard: Backend health check failed with status ${testResponse.statusCode}');
          throw Exception('Backend health check failed');
        }
        debugPrint('Dashboard: Backend connection test successful');
      } catch (e) {
        debugPrint('Dashboard: Backend connection test failed: $e');
        throw Exception(
            'Could not connect to the server. Please check your internet connection.');
      }

      debugPrint('Dashboard: Fetching sensor data');
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/sensors'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Dashboard: Sensor data fetch timed out');
          throw TimeoutException('Request timed out');
        },
      );

      if (!mounted) {
        debugPrint('Dashboard: Widget unmounted during fetch');
        return;
      }

      debugPrint(
          'Dashboard: Received response with status ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        debugPrint('Dashboard: Parsed ${rawData.length} sensor records');
        _allDataCache = rawData.cast<Map<String, dynamic>>();

        // Sort data by timestamp descending (newest first)
        debugPrint('Dashboard: Sorting sensor data');
        _allDataCache.sort((a, b) {
          DateTime timeA =
              DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(0);
          DateTime timeB =
              DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(0);
          return timeB.compareTo(timeA);
        });

        _latestSensorData =
            _allDataCache.isNotEmpty ? _allDataCache.first : null;
        debugPrint('Dashboard: Latest sensor data: $_latestSensorData');

        _filterAndSetHistory();
        debugPrint('Dashboard: Applied time filter to data');

        if (_latestSensorData != null) {
          debugPrint('Dashboard: Processing sensor data for notifications');
          _processSensorDataForNotifications(_latestSensorData!);
        }

        debugPrint(
            'Dashboard: Successfully processed ${_allDataCache.length} sensor records');
      } else if (response.statusCode == 404) {
        debugPrint('Dashboard: No sensor data available (404)');
        _latestSensorData = null;
        _sensorHistory = [];
        _allDataCache = [];
        _errorMessage = 'No sensor data available yet.';
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('Dashboard: Authentication error: ${response.statusCode}');
        _errorMessage = 'Authentication error. Please login again.';
      } else {
        debugPrint(
            'Dashboard: Error fetching data: ${response.statusCode} - ${response.body}');
        _errorMessage = 'Error fetching data: ${response.statusCode}';
        _latestSensorData = null;
        _sensorHistory = [];
        _allDataCache = [];
      }
    } catch (e) {
      debugPrint('Dashboard: Error in _fetchData: $e');
      if (!mounted) return;
      _errorMessage = 'Could not connect to the server.';
      _latestSensorData = null;
      _sensorHistory = [];
      _allDataCache = [];
    } finally {
      if (mounted) {
        debugPrint('Dashboard: Finishing fetch operation');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Filter data based on selected hours from the cache
  void _filterAndSetHistory() {
    debugPrint('Dashboard: Filtering history data');
    setState(() {
      _sensorHistory = List.from(_allDataCache);
      debugPrint('Dashboard: Filtered ${_sensorHistory.length} records');
    });
  }

  // Process sensor data for notifications
  void _processSensorDataForNotifications(Map<String, dynamic> sensorData) {
    debugPrint(
        'Dashboard: Processing notifications for sensor data: $sensorData');
    _notificationService.processSensorData(
      gasLevel: sensorData['mq2']?.toDouble(),
      temperature: sensorData['temperature']?.toDouble(),
      soundLevel: sensorData['sound']?.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CommonBackground(
        // Use CommonBackground
        child: Column(
          children: [
            // Header Title (already implemented)
            const SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Center(
                  child: Text(
                    'Dashboard',
                    style: TextStyle(
                        color: Color(0xFFE07A5F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.orange,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null)
                              _buildErrorDisplay(_errorMessage!),
                            const SizedBox(height: 16),
                            // Replace Latest Readings section
                            _buildStatsGridSection(), // Use the new stats grid
                            const SizedBox(
                                height: 12), // Reduce spacing from 24 to 12
                            _buildRecordedDataSection(), // Keep recorded data section
                            const SizedBox(
                                height: 48), // Spacing under the table
                            const SizedBox(
                                height: 16), // Restore spacing for Nav Bar
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

  // --- UI Builder Widgets ---

  Widget _buildErrorDisplay(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(51),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New method to build the stats grid
  Widget _buildStatsGridSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add Title and Button Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Live Data',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement Add button functionality (e.g., navigate to add device?)
                debugPrint('Add button pressed');
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Button color
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16), // Add spacing below the title row
        // Title removed as it's implicit now
        // const Text('Latest Readings', ...),
        // const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2, // Use 2 columns
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3, // Adjust aspect ratio for the new card layout
          children: [
            DashboardStatsCard(
              title: 'Temperature',
              value:
                  _latestSensorData?['temperature']?.toStringAsFixed(1) ?? '0',
              unit: '°C',
              icon: Icons.thermostat,
              color: _tempColor,
            ),
            DashboardStatsCard(
              title: 'Gas (MQ-2)',
              value: _latestSensorData?['mq2']?.toStringAsFixed(1) ?? '0',
              unit: 'ppm',
              icon: Icons.cloud_outlined, // Or Icons.gas_meter_outlined
              color: _mq2Color,
            ),
            DashboardStatsCard(
              title: 'Sound Level',
              value: _latestSensorData?['sound']?.toStringAsFixed(1) ?? '0',
              unit: 'dB',
              icon: Icons.volume_up_outlined,
              color: _soundColor,
            ),
            // Can add a 4th card here later if needed
          ],
        ),
      ],
    );
  }

  Widget _buildRecordedDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recorded Data',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildTimeRangeDropdown(),
          ],
        ),
        const SizedBox(height: 8),
        // Data Table Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF15355E).withAlpha(51),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha(51), // Softer border
              width: 1,
            ),
          ),
          child: _sensorHistory.isEmpty
              ? _buildEmptyDataTable() // Call helper for empty table
              : _buildDataTable(), // Use helper for table with data
        ),
      ],
    );
  }

  // Helper for Time Range Dropdown
  Widget _buildTimeRangeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<String>(
        value: _selectedHours,
        items: ['1H', '2H', '4H', '6H', '8H', '10H', '24H'].map((String hours) {
          return DropdownMenuItem<String>(
            value: hours,
            child: Text(
              hours,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedHours = newValue;
              _filterAndSetHistory(); // Apply filter to cached data, no need to refetch
            });
          }
        },
        style: const TextStyle(color: Colors.white, fontSize: 14),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
        isDense: true,
        underline: const SizedBox(),
        dropdownColor:
            const Color(0xFF15355E).withAlpha(51), // More opaque dropdown
      ),
    );
  }

  // Helper to build the Data Table
  Widget _buildDataTable() {
    // Define column headers
    List<String> columns = [
      'Time',
      'Temp (°C)',
      'MQ-2 (ppm)',
      'Sound (dB)',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18, // Adjust spacing
        headingRowHeight: 40,
        dataRowMinHeight: 35, // Adjust row height
        dataRowMaxHeight: 45,
        headingTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        dataTextStyle: TextStyle(
          color: Colors.white.withAlpha(179),
          fontSize: 13,
        ),
        columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
        rows: _sensorHistory.map((row) {
          DateTime timestamp =
              DateTime.tryParse(row['timestamp'] ?? '') ?? DateTime(0);
          return DataRow(
            cells: [
              DataCell(Text(_timeFormatter.format(timestamp))),
              DataCell(Text(row['temperature']?.toStringAsFixed(1) ?? '-')),
              DataCell(Text(row['mq2']?.toStringAsFixed(1) ?? '-')),
              DataCell(Text(row['sound']?.toStringAsFixed(1) ?? '-')),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Helper to build an empty Data Table with '0' values
  Widget _buildEmptyDataTable() {
    List<String> columns = [
      'Time',
      'Temp (°C)',
      'MQ-2 (ppm)',
      'Sound (dB)',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 40,
        dataRowMinHeight: 35,
        dataRowMaxHeight: 45,
        headingTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        dataTextStyle: TextStyle(
          color: Colors.white.withAlpha(179),
          fontSize: 13,
        ),
        columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
        rows: const [
          DataRow(
            cells: [
              DataCell(Text('--:--:--')),
              DataCell(Text('0')),
              DataCell(Text('0')),
              DataCell(Text('0')),
            ],
          ),
        ],
      ),
    );
  }
}
