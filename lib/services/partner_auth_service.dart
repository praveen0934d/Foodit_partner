import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:foodit_partner/config/api_config.dart';
import 'package:foodit_partner/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/partner_model.dart';

class PartnerAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<Map<String, String>> _getDeviceDetails() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = 'unknown_device', deviceModel = 'unknown_model', platform = 'android';
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceId = info.id;
        deviceModel = info.model;
        platform = 'android';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceId = info.identifierForVendor ?? 'unknown_device';
        deviceModel = info.name;
        platform = 'ios';
      }
    } catch (e) {
      debugPrint('Could not get device info: $e');
    }
    return {'device_id': deviceId, 'device_model': deviceModel, 'platform': platform};
  }

  // ─── Google Sign-In ────────────────────────────────────────
  Future<PartnerUser> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Sign-in cancelled.');

      debugPrint('Google account selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final String firebaseToken = await userCred.user!.getIdToken(true) ?? '';

      return await _laravelGoogleLogin(
        firebaseToken: firebaseToken,
        email: googleUser.email,
        name: googleUser.displayName ?? 'Partner',
        googlePhotoUrl: googleUser.photoUrl,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Google sign-in failed: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // ─── Deep Silent Re-Authentication ────────────────────────
  Future<bool> silentReAuth() async {
    try {
      debugPrint('Attempting Google silent sign-in...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        debugPrint('Silent sign-in returned null.');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final String firebaseToken = await userCred.user!.getIdToken(true) ?? '';

      // This will automatically save new access/refresh tokens in secure storage
      await _laravelGoogleLogin(
        firebaseToken: firebaseToken,
        email: googleUser.email,
        name: googleUser.displayName ?? 'Partner',
        googlePhotoUrl: googleUser.photoUrl,
      );
      
      debugPrint('Deep silent re-auth successful!');
      return true;
    } catch (e) {
      debugPrint('Deep silent re-auth failed: $e');
      rethrow;
    }
  }

  // Generates consistent temp phone starting with 1
  // Real Indian numbers never start with 1
  // Same email always gives same number — no duplicates
  String _generateTempPhone(String email) {
    final hash = email.codeUnits.fold(0, (prev, e) => prev + e);
    final base = (hash * 9871) % 1000000000;
    return '1${base.toString().padLeft(9, '0')}';
  }

  Future<PartnerUser> _laravelGoogleLogin({
    required String firebaseToken,
    required String email,
    required String name,
    String? googlePhotoUrl,
  }) async {
    final deviceData = await _getDeviceDetails();

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      print('=========================================');
      print('PARTNER FCM TOKEN: $fcmToken');
      print('=========================================');
    } catch (e) {
      print('Failed to fetch FCM Token: $e');
    }

    final tempPhone = _generateTempPhone(email);

    final requestBody = {
      'firebase_token': firebaseToken,
      'email': email,
      'name': name,
      'phone': tempPhone,       // temp phone — starts with 1
      'is_temp_phone': true,
      'role': 'restaurant',
      'device_id': deviceData['device_id'],
      'device_model': deviceData['device_model'],
      'platform': deviceData['platform'],
      'fcm_token': fcmToken,
      'google_photo_url': googlePhotoUrl ?? 'https://ui-avatars.com/api/?name=Partner',
      'student_id': 'PARTNER_$tempPhone', // dummy student ID for database constraints
    };

    print('POST → ${ApiConfig.baseUrl}/auth/google-login');
    print('Body: ${jsonEncode(requestBody)}');

    final response = await ApiClient.post('/auth/google-login', body: requestBody);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['access_token'] != null) {
      final user = PartnerUser.fromJson(data['user'], data['access_token']);
      await _saveTokens(data['access_token'], data['refresh_token'] ?? '', deviceData['device_id']);
      return user;
    } else {
      throw Exception(data['message'] ?? 'Failed to authenticate. Status: ${response.statusCode}');
    }
  }

  Future<void> logout() async {
    final token = await _secureStorage.read(key: 'partner_access_token');
    final refreshToken = await _secureStorage.read(key: 'partner_refresh_token');

    if (token != null) {
      try {
        await ApiClient.post('/auth/logout', body: {'refresh_token': refreshToken});
      } catch (e) {
        print('Server logout failed: $e');
      }
    }
    await _secureStorage.delete(key: 'partner_access_token');
    await _secureStorage.delete(key: 'partner_refresh_token');
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> _saveTokens(String accessToken, String refreshToken, [String? deviceId]) async {
    await _secureStorage.write(key: 'partner_access_token', value: accessToken);
    await _secureStorage.write(key: 'partner_refresh_token', value: refreshToken);
    if (deviceId != null) {
      await _secureStorage.write(key: 'partner_device_id', value: deviceId);
    }
  }

  // ─── Cache user data locally on login ────────────────────────
  Future<void> saveUserLocally(PartnerUser user) async {
    await _secureStorage.write(key: 'partner_user_id', value: user.id);
    await _secureStorage.write(key: 'partner_user_name', value: user.name);
    await _secureStorage.write(key: 'partner_user_email', value: user.email);
    await _secureStorage.write(key: 'partner_restaurant_id', value: user.restaurantId);
  }

  // ─── Restore cached user from secure storage ─────────────────
  Future<PartnerUser?> getCachedUser() async {
    final token = await _secureStorage.read(key: 'partner_access_token');
    final id = await _secureStorage.read(key: 'partner_user_id');
    if (token == null || id == null) return null;

    return PartnerUser(
      id: id,
      name: await _secureStorage.read(key: 'partner_user_name') ?? '',
      email: await _secureStorage.read(key: 'partner_user_email') ?? '',
      restaurantId: await _secureStorage.read(key: 'partner_restaurant_id') ?? '',
      token: token,
    );
  }

  // ─── Validate token with server ──────────────────────────────
  /// Returns the real PartnerUser if the token is valid.
  /// On 401, tries refresh. On network error, falls back to cached user.
  /// Returns null only if truly unauthenticated.
  Future<PartnerUser?> validateToken() async {
    final token = await _secureStorage.read(key: 'partner_access_token');
    if (token == null) {
      debugPrint('validateToken: No token in storage');
      return null;
    }

    debugPrint('validateToken: Token found, calling /auth/profile...');

    try {
      final response = await ApiClient.get('/auth/profile');

      debugPrint('validateToken: Response status=${response.statusCode}');
      debugPrint('validateToken: Response body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['user'] == null) {
          debugPrint('validateToken: 200 but no "user" key in response — using cached user');
          return await getCachedUser();
        }

        final user = PartnerUser.fromJson(data['user'], token);
        // Update cached user data with fresh server data
        await saveUserLocally(user);
        debugPrint('validateToken: Valid — user=${user.name}, email=${user.email}');
        return user;
      } else if (response.statusCode == 401) {
        // ApiClient already tries refresh internally on 401.
        // If we still get here, the session is truly expired.
        // This prevents cross-app logout when another app revokes tokens.
        debugPrint('validateToken: 401 — trying cached user instead of forcing logout');
        final cached = await getCachedUser();
        if (cached != null) {
          debugPrint('validateToken: Using cached user to stay logged in');
          return cached;
        }
        // Only clear tokens if there's no cached fallback
        debugPrint('validateToken: No cached user — clearing tokens');
        await _secureStorage.delete(key: 'partner_access_token');
        await _secureStorage.delete(key: 'partner_refresh_token');
        return null;
      } else {
        // Non-auth server error — fall back to cached user
        debugPrint('Token validation got status ${response.statusCode}, using cached user');
        return await getCachedUser();
      }
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('validateToken: caught exception: $errorMsg');

      // instead of immediately clearing tokens. This prevents unnecessary logouts
      // when the token was revoked by another app or due to transient issues.
      final cached = await getCachedUser();
      if (cached != null) {
        debugPrint('validateToken: Using cached user despite error');
        return cached;
      }

      // No cached user and session is truly expired — force logout
      if (errorMsg.contains('Session expired') || errorMsg.contains('401')) {
        debugPrint('Token validation: session expired, no cache — clearing tokens');
        await _secureStorage.delete(key: 'partner_access_token');
        await _secureStorage.delete(key: 'partner_refresh_token');
        return null;
      }
      // Genuine network error with no cache — throw to show retry UI
      debugPrint('Token validation network error, no cache: $e');
      rethrow;
    }
  }
}