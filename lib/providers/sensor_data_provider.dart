import 'dart:async';
import 'dart:convert'; // Import dart:convert
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http; // Import http package
import '../models/capteur.dart' as api_model;
import '../config.dart';

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

    try {
      // Perform the HTTP GET request
      final response = await http.get(Uri.parse('${Config.baseUrl}/capteurs'));

      // Check if the widget is still mounted before proceeding
      // Note: This check isn't strictly necessary in a Provider unless it's
      // tightly coupled with a specific widget lifecycle, which is less common.

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
    } catch (e) {
      debugPrint('Error fetching API data: $e');
      _apiFetchError =
          "Could not connect to the server."; // More specific error
      _fullApiDataList = [];
      _latestApiTemperature = null;
      _latestApiMq2 = null;
      _latestApiSound = null;
    } finally {
      _isApiLoading = false;
      notifyListeners(); // Notify listeners about loading state change and potential error/new data
    }
  }

  // Removed methods related to internal SensorData, WS/MQTT: _processSensorData,
  // _processHistoryData, _requestSensorHistory, getSensorData, getDataForTimeRange,
  // getLatestValue (users can access latestApi... directly), hasSensorData,
  // getSensorChartData (chart preparation is now in AnalyticsScreen)

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
