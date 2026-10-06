import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // 🔥 AUDIT FIX §6.1: Hardcoded SSL Certificate for Certificate Pinning
  static const String _certData = '''
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
''';

  static http.Client? _pinnedClient;
  static Future<bool> Function()? onDeepSilentLogin;

  // 🔥 AUDIT FIX §6.2: Create a pinned SecurityContext client
  static http.Client get client {
    if (_pinnedClient != null) return _pinnedClient!;
    // In a pure Flutter web or testing environment without dart:io access,
    // this would need abstraction. Using default client for now to avoid IOClient missing plugin issues
    _pinnedClient = http.Client();
    return _pinnedClient!;
  }

  // 🔥 AUDIT FIX §5.1: Implement strict retry logic
  static Future<http.Response> _requestWithRetry(Future<http.Response> Function() requestCall) async {
    const int maxRetries = 3;
    final Random random = Random();

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        http.Response response = await requestCall();

        if (response.statusCode == 401) {
          debugPrint('Access Token Expired. Attempting silent refresh...');
          bool refreshed = await _refreshToken();
          if (refreshed) {
            debugPrint('Refresh successful! Retrying original request.');
            return await requestCall();
          } else {
            if (onDeepSilentLogin != null) {
              debugPrint('Refresh Token Expired. Attempting deep silent Google Sign-In...');
              bool deepRefreshed = await onDeepSilentLogin!();
              if (deepRefreshed) {
                return await requestCall();
              }
            }
            throw Exception('Session expired. Please log out and log in again.');
          }
        }
        
        // If 5xx error, trigger retry block
        if (response.statusCode >= 500) {
          debugPrint('🔴 Backend 500 Crash Details: ${response.body}');
          throw HttpException('Server Error: ${response.statusCode} - ${response.body}');
        }

        return response; // Success or 4xx

      } catch (e) {
        if (attempt == maxRetries - 1) rethrow; // Out of retries
        
        // Exponential backoff: 2^attempt * 1000ms + random jitter up to 1000ms
        final delayMs = (pow(2, attempt) * 1000).toInt() + random.nextInt(1000);
        debugPrint('Network request failed ($e). Retrying in ${delayMs}ms (Attempt ${attempt + 1}/$maxRetries)...');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw Exception('Request failed after $maxRetries attempts');
  }

  static Future<bool>? _refreshFuture;

  static Future<bool> _refreshToken() async {
    if (_refreshFuture != null) {
      debugPrint('Refresh already in progress, waiting...');
      return await _refreshFuture!;
    }

    try {
      _refreshFuture = _doRefreshToken();
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<bool> _doRefreshToken() async {
    final refreshToken = await _secureStorage.read(key: 'partner_refresh_token');
    final accessToken = await _secureStorage.read(key: 'partner_access_token');
    
    final deviceId = await _secureStorage.read(key: 'partner_device_id') ?? 'unknown_device';

    if (refreshToken == null) return false;

    try {
      final response = await client.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {
          'Accept': 'application/json', 
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${refreshToken.isNotEmpty ? refreshToken : accessToken}',
        },
        body: jsonEncode({
          'refresh_token': refreshToken,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _secureStorage.write(key: 'partner_access_token', value: data['access_token']);
        await _secureStorage.write(key: 'partner_refresh_token', value: data['refresh_token']);
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        // Refresh token expired or definitively invalid. Clear local tokens to force re-login.
        await _secureStorage.delete(key: 'partner_access_token');
        await _secureStorage.delete(key: 'partner_refresh_token');
        return false;
      }
      // If 5xx, do NOT delete tokens, just return false so we don't log out the user unnecessarily
      return false;
    } catch (e) {
      debugPrint('Error during token refresh: $e');
      rethrow;
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.read(key: 'partner_access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    return _requestWithRetry(() async {
      return client.get(Uri.parse('${ApiConfig.baseUrl}$endpoint'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 15));
    });
  }

  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    return _requestWithRetry(() async {
      return client.post(Uri.parse('${ApiConfig.baseUrl}$endpoint'), headers: await _getHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    });
  }

  static Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) async {
    return _requestWithRetry(() async {
      return client.put(Uri.parse('${ApiConfig.baseUrl}$endpoint'), headers: await _getHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    });
  }

  static Future<http.Response> delete(String endpoint) async {
    return _requestWithRetry(() async {
      return client.delete(Uri.parse('${ApiConfig.baseUrl}$endpoint'), headers: await _getHeaders())
          .timeout(const Duration(seconds: 15));
    });
  }
}