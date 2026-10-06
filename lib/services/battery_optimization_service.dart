import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages battery optimization and OEM autostart permission checks.
///
/// Uses MethodChannel to communicate with native Android code
/// for PowerManager checks and OEM-specific intent launching.
class BatteryOptimizationService {
  BatteryOptimizationService._();
  static final BatteryOptimizationService _instance = BatteryOptimizationService._();
  static BatteryOptimizationService get instance => _instance;

  static const MethodChannel _channel =
      MethodChannel('com.foodit.partner/battery');

  static const String _prefKeyLastCheck = 'battery_opt_last_check';
  static const String _prefKeyUserDismissed = 'battery_opt_user_dismissed';
  static const String _prefKeyOemOpened = 'battery_opt_oem_opened';
  static const int _recheckIntervalDays = 30;

  /// Returns true if the app is battery-optimized (i.e., at risk of being killed).
  /// Returns false if the app is already exempted (safe).
  Future<bool> isBatteryOptimized() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBatteryOptimized');
      return result ?? false;
    } catch (e) {
      print('🔋 [BatteryOpt] Failed to check battery optimization: $e');
      return false; // Assume safe if check fails
    }
  }

  /// Returns the device manufacturer (lowercase).
  Future<String> getManufacturer() async {
    try {
      final result = await _channel.invokeMethod<String>('getManufacturer');
      return result ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Request AOSP battery optimization exemption via system dialog.
  Future<void> requestBatteryExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryExemption');
      print('🔋 [BatteryOpt] Battery exemption requested');
    } catch (e) {
      print('🔋 [BatteryOpt] Failed to request battery exemption: $e');
    }
  }

  /// Open OEM-specific autostart / battery settings page.
  /// Returns true if a specific OEM page was opened.
  Future<bool> openAutoStartSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAutoStartSettings');
      return result ?? false;
    } catch (e) {
      print('🔋 [BatteryOpt] Failed to open autostart settings: $e');
      return false;
    }
  }

  /// Check if the app has permission to use full-screen intents (Android 14+).
  Future<bool> canUseFullScreenIntent() async {
    try {
      final result = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
      return result ?? true;
    } catch (e) {
      return true; // Default to true on older Android versions or if check fails
    }
  }

  /// Request full-screen intent permission by opening the specific settings page.
  Future<void> requestFullScreenIntent() async {
    try {
      await _channel.invokeMethod('requestFullScreenIntent');
    } catch (e) {
      print('🔋 [BatteryOpt] Failed to request full screen intent: $e');
    }
  }

  /// Check if we should show the permissions prompt.
  /// Returns true if ANY required permission is missing.
  Future<bool> shouldShowPrompt() async {
    final isOptimized = await isBatteryOptimized();
    final hasOpenedOem = await hasOpenedOemSettings();
    final needsOem = _needsOemAutostart(await getManufacturer());
    final canUseFullScreen = await canUseFullScreenIntent();
    
    bool hasNotifications = true;
    if (Platform.isAndroid) {
      hasNotifications = await Permission.notification.isGranted;
    }
    
    // If ANY required permission is missing, show the prompt EVERY time
    if (!hasNotifications || isOptimized || (needsOem && !hasOpenedOem) || !canUseFullScreen) {
      return true;
    }

    return false;
  }

  bool _needsOemAutostart(String manufacturer) {
    return ['xiaomi', 'redmi', 'oppo', 'vivo', 'huawei', 'honor', 'samsung', 'realme', 'oneplus']
        .any((mfr) => manufacturer.contains(mfr));
  }

  /// Returns explicit navigation instructions for the device's OEM autostart settings.
  String getOemInstructions(String manufacturer) {
    final mfr = manufacturer.toLowerCase();
    if (mfr.contains('xiaomi') || mfr.contains('redmi') || mfr.contains('poco')) {
      return 'Go to Settings > Apps > Manage apps > Foodit Partner > Enable "Autostart".';
    } else if (mfr.contains('oppo') || mfr.contains('realme')) {
      return 'Go to Settings > App Management > App List > Foodit Partner > Battery usage > Enable "Allow background activity".';
    } else if (mfr.contains('vivo') || mfr.contains('iqoo')) {
      return 'Go to Settings > Battery > Background power consumption management > Foodit Partner > Select "High background power consumption".';
    } else if (mfr.contains('samsung')) {
      return 'Go to Settings > Apps > Foodit Partner > Battery > Select "Unrestricted".';
    } else if (mfr.contains('huawei') || mfr.contains('honor')) {
      return 'Go to Settings > Apps > App launch > Foodit Partner > Manage manually > Enable "Run in background".';
    } else if (mfr.contains('oneplus')) {
      return 'Go to Settings > Apps > App management > Foodit Partner > Battery usage > Enable "Allow background activity".';
    } else {
      return 'Find Foodit Partner in your device settings and allow background activity or autostart.';
    }
  }

  /// Mark the OEM settings as opened.
  Future<void> markOemSettingsOpened() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyOemOpened, true);
  }

  /// Check if OEM settings have been opened.
  Future<bool> hasOpenedOemSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyOemOpened) ?? false;
  }

  /// Mark the prompt as dismissed by the user.
  Future<void> markPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prefKeyUserDismissed,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Update the last check timestamp.
  Future<void> updateLastCheckTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prefKeyLastCheck,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Check if it's time for a periodic re-check (every 30 days).
  Future<bool> needsPeriodicRecheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_prefKeyLastCheck) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceCheck = (now - lastCheck) / (1000 * 60 * 60 * 24);
    return daysSinceCheck > _recheckIntervalDays;
  }
}
