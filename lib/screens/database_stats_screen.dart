import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/common_background.dart';
import '../config.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DatabaseStatsScreen extends StatefulWidget {
  const DatabaseStatsScreen({super.key});

  @override
  State<DatabaseStatsScreen> createState() => _DatabaseStatsScreenState();
}

class _DatabaseStatsScreenState extends State<DatabaseStatsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _fetchDatabaseStats();
  }

  Future<void> _fetchDatabaseStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      debugPrint('DatabaseStatsScreen: Attempting to fetch stats with token: ${token?.substring(0, 10)}...');
      debugPrint('DatabaseStatsScreen: Using URL: ${Config.databaseStatsEndpoint}');
      
      final response = await http.get(
        Uri.parse(Config.databaseStatsEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('DatabaseStatsScreen: Response status code: ${response.statusCode}');
      debugPrint('DatabaseStatsScreen: Response body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _stats = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to fetch database stats (Status: ${response.statusCode})';
          _isLoading = false;
        });
        debugPrint('DatabaseStatsScreen: Error response: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('DatabaseStatsScreen: Exception occurred: $e');
      debugPrint('DatabaseStatsScreen: Stack trace: $stackTrace');
      setState(() {
        _error = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCollection(String collectionName, double sizeMB) async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final response = await http.delete(
        Uri.parse('${Config.baseUrl}/admin/clear-collection/$collectionName'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'sizeMB': sizeMB}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully cleared ${sizeMB}MB from $collectionName collection')),
        );
        _fetchDatabaseStats(); // Refresh stats
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear $collectionName collection')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error connecting to server')),
      );
    }
  }

  void _showDeleteConfirmation(String collectionName, double totalSizeMB) {
    double selectedSize = totalSizeMB;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF15355E),
          title: const Text('Clear Collection Data', 
            style: TextStyle(color: Colors.white)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How much data do you want to clear from $collectionName?',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: selectedSize,
                      min: 0,
                      max: totalSizeMB,
                      divisions: 20,
                      label: '${selectedSize.toStringAsFixed(2)} MB',
                      onChanged: (value) {
                        setState(() => selectedSize = value);
                      },
                      activeColor: Colors.orange,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${selectedSize.toStringAsFixed(2)}MB',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', 
                style: TextStyle(color: Colors.white70)
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearCollection(collectionName, selectedSize);
              },
              child: const Text('Clear', 
                style: TextStyle(color: Colors.red)
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CommonBackground(
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Stack(
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: SafeArea(
                        child: BackButton(color: Color(0xFFE07A5F)),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Database Storage',
                        style: TextStyle(
                          color: Color(0xFFE07A5F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFFE07A5F)),
                        onPressed: _fetchDatabaseStats,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Storage Usage Card
                              _buildStorageCard(),
                              const SizedBox(height: 24),
                              // Collections List
                              _buildCollectionsList(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard() {
    final usagePercentage = double.parse(_stats?['usagePercentage'] ?? '0');
    final color = usagePercentage > 90
        ? Colors.red
        : usagePercentage > 70
            ? Colors.orange
            : Colors.green;

    return Card(
      color: const Color(0xFF15355E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage Usage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: usagePercentage / 100,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_stats?['totalSizeMB']} MB used',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  '${_stats?['usagePercentage']}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Storage Limit: ${_stats?['storageLimit']}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsList() {
    final collections = (_stats?['collections'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collections',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...collections.map((collection) => _buildCollectionCard(collection)),
      ],
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    final collectionSize = double.parse(collection['size'].toString());
    
    return Card(
      color: const Color(0xFF15355E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          collection['name'],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Size: ${collection['size']} MB',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Documents: ${collection['documents']}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(collection['name'], collectionSize),
        ),
      ),
    );
  }
} 