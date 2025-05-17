import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkDebugger {
  // Comprehensive network request method with extensive logging
  static Future<http.Response> debuggedPost({
    required String url,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    try {
      // Print detailed request information
      debugPrint(' Network Request:');
      debugPrint('URL: $url');
      debugPrint('Headers: ${headers?.toString() ?? 'None'}');
      debugPrint('Body: ${body?.toString() ?? 'None'}');

      // Perform the network request
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers ?? {},
            body: body,
            encoding: encoding,
          )
          .timeout(const Duration(seconds: 15));

      // Print detailed response information
      debugPrint(' Network Response:');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Headers: ${response.headers}');
      debugPrint('Body: ${response.body}');

      return response;
    } on SocketException catch (e) {
      debugPrint(' Socket Exception: ${e.message}');
      debugPrint('OS Error: ${e.osError}');
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint(' Timeout Exception: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint(' Unexpected Network Error: $e');
      rethrow;
    }
  }

  // Method to test server connectivity
  static Future<bool> testServerConnectivity(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      debugPrint('Server Connectivity Test:');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Server Connectivity Test Failed: $e');
      return false;
    }
  }

  // Enhanced error handling method
  static String parseErrorResponse(http.Response response) {
    try {
      // Try to parse JSON error response
      final errorBody = json.decode(response.body);
      return errorBody['message'] ?? 'Unknown error occurred';
    } catch (_) {
      // Fallback to status code if JSON parsing fails
      return 'Error ${response.statusCode}: ${response.reasonPhrase}';
    }
  }
}
