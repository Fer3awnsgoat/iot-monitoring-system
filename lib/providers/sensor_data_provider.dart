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

    // Disabled: No longer fetch from /capteurs endpoint to avoid 404 errors.
    _isApiLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
