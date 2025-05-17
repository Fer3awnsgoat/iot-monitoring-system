import 'dart:async';
import 'dart:convert'; // Import dart:convert
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http; // Import http package
import '../models/capteur.dart' as api_model;
import '../config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SensorDataProvider with ChangeNotifier {
  bool _initialized = false;
  bool _hasFetchedOnce = false;

  bool _isApiLoading = false;
  String? _apiFetchError;

  api_model.Capteur? _latestApiTemperature;
  api_model.Capteur? _latestApiMq2;
  api_model.Capteur? _latestApiSound;

  List<api_model.Capteur> _fullApiDataList = [];

  Timer? _apiFetchTimer;

  SensorDataProvider() {
    // initialize(); // Consider calling initialize when the provider is first used
  }

  // Getters
  bool get isInitialized => _initialized;
  bool get hasFetchedOnce => _hasFetchedOnce;
  bool get isApiLoading => _isApiLoading;
  String? get apiFetchError => _apiFetchError;
  api_model.Capteur? get latestApiTemperature => _latestApiTemperature;
  api_model.Capteur? get latestApiMq2 => _latestApiMq2;
  api_model.Capteur? get latestApiSound => _latestApiSound;
  List<api_model.Capteur> get fullApiDataList =>
      List.unmodifiable(_fullApiDataList);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _fetchApiData();
      _apiFetchTimer?.cancel();
      _apiFetchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _fetchApiData();
      });
      // No need to notify here, _fetchApiData does it
    } catch (e) {
      debugPrint('Error initializing sensor data provider: $e');
    }
  }

  void disconnect() {
    _apiFetchTimer?.cancel();
    _apiFetchTimer = null;
    _initialized = false;
    _hasFetchedOnce = false;
    _fullApiDataList = [];
    _latestApiTemperature = null;
    _latestApiMq2 = null;
    _latestApiSound = null;
    _apiFetchError = null;
    notifyListeners();
  }

  // Fetch data directly using http package
  Future<void> _fetchApiData() async {
    _isApiLoading = true;
    _apiFetchError = null;
    // Only notify if it's NOT the first fetch, to avoid layout issues on init
    if (_hasFetchedOnce) {
      notifyListeners();
    }

    final url = '${Config.baseUrl}/capteurs';
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (!Config.isProduction) debugPrint('SensorDataProvider: Fetching data from $url');

      if (token == null) {
        _apiFetchError = 'Not authenticated';
        _isApiLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/capteurs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        // Map JSON to Capteur objects
        _fullApiDataList =
            rawData.map((data) => api_model.Capteur.fromJson(data)).toList();
        _hasFetchedOnce = true;

        // Process latest data
        if (_fullApiDataList.isNotEmpty) {
          api_model.Capteur? latestTempFromApi;
          api_model.Capteur? latestMq2FromApi;
          api_model.Capteur? latestSoundFromApi;

          for (var capteur in _fullApiDataList) {
            DateTime currentTimestamp = capteur.timestamp ?? DateTime(0);
            if (latestTempFromApi == null ||
                currentTimestamp
                    .isAfter(latestTempFromApi.timestamp ?? DateTime(0))) {
              latestTempFromApi = capteur;
            }
            if (latestMq2FromApi == null ||
                currentTimestamp
                    .isAfter(latestMq2FromApi.timestamp ?? DateTime(0))) {
              latestMq2FromApi = capteur;
            }
            if (latestSoundFromApi == null ||
                currentTimestamp
                    .isAfter(latestSoundFromApi.timestamp ?? DateTime(0))) {
              latestSoundFromApi = capteur;
            }
          }
          _latestApiTemperature = latestTempFromApi;
          _latestApiMq2 = latestMq2FromApi;
          _latestApiSound = latestSoundFromApi;
          _apiFetchError = null;
        } else {
          _latestApiTemperature = null;
          _latestApiMq2 = null;
          _latestApiSound = null;
          _apiFetchError = null; // Or set 'No data' message
        }
      } else if (response.statusCode == 404) {
        _apiFetchError = 'No sensor data available yet.';
        _fullApiDataList = [];
        _latestApiTemperature = null;
        _latestApiMq2 = null;
        _latestApiSound = null;
      } else {
        _apiFetchError = 'Error fetching data: ${response.statusCode}';
        _fullApiDataList = [];
        _latestApiTemperature = null;
        _latestApiMq2 = null;
        _latestApiSound = null;
      }
    } on TimeoutException catch (e, s) {
      _apiFetchError = "Connection timed out";
      if (Config.debugLoggingEnabled) {
        debugPrint('SensorDataProvider: Request timed out: $e');
        debugPrint('Stack trace: $s');
      }
    } catch (e, s) {
      _apiFetchError = "Could not connect to the server";
      if (Config.debugLoggingEnabled) {
        debugPrint('SensorDataProvider: Error fetching data from $url (this URL is from Config.baseUrl)');
        debugPrint('SensorDataProvider: Low-level error details: $e');
        debugPrint('SensorDataProvider: Stack trace: $s');
      }
      _fullApiDataList = [];
      _latestApiTemperature = null;
      _latestApiMq2 = null;
      _latestApiSound = null;
    } finally {
      _isApiLoading = false;
      notifyListeners(); // Notify listeners about loading state change and potential error/new data
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
