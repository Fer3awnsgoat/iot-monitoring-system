class Config {
  static const bool isProduction = true;
  // Set this to true to enable detailed logging even in production mode
  static const bool debugLoggingEnabled = true; // <-- Set to true to debug, false to disable

  static const String _devUrl = 'http://10.0.2.2:3001';
  static const String _prodUrl =
      'https://iot-monitoring-system-production-5852.up.railway.app';

  static String get baseUrl => isProduction ? _prodUrl : _devUrl;

  static String get loginEndpoint => '$baseUrl/login';
  static String get registerEndpoint => '$baseUrl/register';
  static String get sensorDataEndpoint => '$baseUrl/capteurs';
}
