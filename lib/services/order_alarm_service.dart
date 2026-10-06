import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Manages alarm playback for new order notifications.
///
/// **Foreground alarm**: Uses `audioplayers` to loop an alarm sound from assets.
/// **Background alarm**: Uses MethodChannel to start/stop the native
/// Android ForegroundService (OrderAlarmService.kt).
class OrderAlarmService {
  OrderAlarmService._();
  static final OrderAlarmService _instance = OrderAlarmService._();
  static OrderAlarmService get instance => _instance;

  // ─── Foreground alarm (audioplayers) ───
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Timer? _autoStopTimer;

  // ─── Native alarm (MethodChannel) ───
  static const MethodChannel _alarmChannel =
      MethodChannel('com.foodit.partner/alarm');

  bool get isPlaying => _isPlaying;

  // Expose a ValueNotifier so UI can show a "Stop Alarm" button
  final ValueNotifier<bool> isRingingNotifier = ValueNotifier<bool>(false);

  // ───────────────────────────────────────────────
  // FOREGROUND: Play alarm when app is open
  // ───────────────────────────────────────────────

  /// Start the looping alarm sound (foreground only).
  Future<void> startAlarm() async {
    if (_isPlaying) return;
    _isPlaying = true;
    isRingingNotifier.value = true;

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/new_order_alarm.wav'));
      print('🔔 [OrderAlarm] Foreground alarm started');

      // Auto-stop after 2 minutes as safety net
      _autoStopTimer?.cancel();
      _autoStopTimer = Timer(const Duration(minutes: 2), () {
        print('🔔 [OrderAlarm] Auto-stopping after 2 minutes');
        stopAlarm();
      });
    } catch (e) {
      print('🔔 [OrderAlarm] Failed to start alarm: $e');
      _isPlaying = false;
      isRingingNotifier.value = false;
    }
  }

  /// Stop the looping alarm sound.
  Future<void> stopAlarm() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    isRingingNotifier.value = false;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    try {
      await _player.stop();
      print('🔔 [OrderAlarm] Foreground alarm stopped');
    } catch (e) {
      print('🔔 [OrderAlarm] Failed to stop alarm: $e');
    }
  }

  // ───────────────────────────────────────────────
  // BACKGROUND: Native ForegroundService alarm
  // ───────────────────────────────────────────────

  /// Start the native alarm foreground service (for background/killed state).
  /// Called from the FCM background handler isolate.
  static Future<void> startNativeAlarm({
    required String orderId,
    String title = 'New Order!',
    String body = 'You have a new order waiting',
  }) async {
    try {
      await _alarmChannel.invokeMethod('startAlarmService', {
        'orderId': orderId,
        'title': title,
        'body': body,
      });
      print('🔔 [OrderAlarm] Native alarm service started for order: $orderId');
    } catch (e) {
      print('🔔 [OrderAlarm] Failed to start native alarm: $e');
    }
  }

  /// Stop the native alarm foreground service.
  static Future<void> stopNativeAlarm() async {
    try {
      await _alarmChannel.invokeMethod('stopAlarmService');
      print('🔔 [OrderAlarm] Native alarm service stopped');
    } catch (e) {
      print('🔔 [OrderAlarm] Failed to stop native alarm: $e');
    }
  }

  /// Check if the native alarm service is running.
  static Future<bool> isNativeAlarmRunning() async {
    try {
      final result = await _alarmChannel.invokeMethod<bool>('isAlarmRunning');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if the user tapped Accept/Reject on the notification while the
  /// app was in background/killed state. Returns null if no pending action.
  static Future<Map<String, String>?> checkPendingAlarmAction() async {
    try {
      final result = await _alarmChannel.invokeMethod<Map<Object?, Object?>>(
        'checkPendingAlarmAction',
      );
      if (result == null) return null;
      return result.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      print('🔔 [OrderAlarm] Failed to check pending action: $e');
      return null;
    }
  }

  /// Clear the stored pending alarm action after it has been processed.
  static Future<void> clearPendingAlarmAction() async {
    try {
      await _alarmChannel.invokeMethod('clearPendingAlarmAction');
    } catch (e) {
      print('🔔 [OrderAlarm] Failed to clear pending action: $e');
    }
  }

  /// Dispose of the audio player resources.
  void dispose() {
    _autoStopTimer?.cancel();
    _player.dispose();
  }
}
