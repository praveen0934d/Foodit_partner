import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:foodit_partner/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';
import 'api_client.dart';
import 'order_alarm_service.dart';

// Call: FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)
// in main() BEFORE PartnerFCMService.init()
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // NOTE: This runs in a separate isolate — no access to Flutter UI.
  print("Background/Terminated message: ${message.notification?.title}");
  print("Background data: ${message.data}");

  // If it's a new order or order cancelled, show a local notification
  // because data-only messages won't be shown by Android OS automatically.
  if (message.data['type'] == 'new_order' || message.data['type'] == 'order_cancelled') {
    final title = message.notification?.title ?? message.data['title'] ?? (message.data['type'] == 'new_order' ? 'New Order!' : 'Order Cancelled!');
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? 'Check the app for details';

    try {
      final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      await localNotifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings)
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important partner order notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await localNotifications.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: title,
            ),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
      print('🔔 [Background] Local notification triggered for: $title');
    } catch (e) {
      print('🔔 [Background] Failed to show local notification: $e');
    }
  }
}

class PartnerFCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // true  = owner is on New Orders tab → silent reload only
  // false = owner elsewhere → show heads-up banner
  static bool isViewingNewOrders = false;

  // ic_notification must be a flat white PNG in all drawable-* folders
  static const String _notificationIcon = '@drawable/ic_notification';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important partner order notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static final StreamController<Map<String, String>> _orderEventStream =
      StreamController<Map<String, String>>.broadcast();
  static Stream<Map<String, String>> get onOrderUpdate => _orderEventStream.stream;

  static String? _pendingOrderId;
  static bool _pendingReload = false;

  static bool hasPendingReload() => _pendingReload;

  static void clearPendingReload() {
    _pendingReload = false;
    _pendingOrderId = null;
  }

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  static StreamSubscription<String>? _onTokenRefreshSub;

  static Future<void> init() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('Notification permission denied');
      return;
    }
    print('Notification permission granted: ${settings.authorizationStatus}');

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // @mipmap/ic_launcher is a color adaptive icon — Android notification
    // system requires monochrome white PNG from drawable folder
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    _onTokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed');
      _sendTokenToBackend(newToken);
    });

    // ─────────────────────────────────────────────
    // STATE 1: FOREGROUND — App is open
    // ─────────────────────────────────────────────
    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.title}');
      print('Data: ${message.data}');

      if (message.data['type'] == 'new_order' || message.data['type'] == 'order_cancelled') {
        _orderEventStream.add({
          'type': message.data['type'] ?? '',
          'order_id': message.data['order_id'] ?? ''
        });
      }

      // Start foreground alarm for new orders (preventing double-alarm race)
      // HIDING FOR NOW: We will complete the alarm feature later.
      // if (message.data['type'] == 'new_order') {
      //   OrderAlarmService.isNativeAlarmRunning().then((isRunning) {
      //     if (!isRunning) {
      //       OrderAlarmService.instance.startAlarm();
      //     }
      //   });
      // }
      
      // Always show the notification banner in the foreground
      _showHeadsUpNotification(message);
    });

    // ─────────────────────────────────────────────
    // STATE 2: BACKGROUND — User taps notification
    // ─────────────────────────────────────────────
    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Background tap: ${message.notification?.title}');
      if (message.data['type'] == 'new_order' || message.data['type'] == 'order_cancelled') {
        _pendingOrderId = message.data['order_id'] ?? '';
        _pendingReload = true;
        _orderEventStream.add({
          'type': message.data['type'] ?? '',
          'order_id': _pendingOrderId!
        });
      }
    });

    // ─────────────────────────────────────────────
    // STATE 3: TERMINATED — App was killed
    // ─────────────────────────────────────────────
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('Killed state tap: ${initialMessage.notification?.title}');
      if (initialMessage.data['type'] == 'new_order' || initialMessage.data['type'] == 'order_cancelled') {
        _pendingOrderId = initialMessage.data['order_id'] ?? '';
        _pendingReload = true;
        print('Pending order stored: $_pendingOrderId');
      }
    }
  }

  static Future<void> initAndSendToken() async {
    try {
      String? fcmToken = await _messaging.getToken();
      print('\n=========================================');
      print('PARTNER FCM TOKEN: $fcmToken');
      print('=========================================\n');
      if (fcmToken != null) await _sendTokenToBackend(fcmToken);
    } catch (e) {
      print('Failed to get FCM token: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Shows heads-up notification in FOREGROUND
  // Previously returned early if notification==null, silently dropping
  // data-only FCM messages sent from Laravel backend
  // ─────────────────────────────────────────────
  static Future<void> _showHeadsUpNotification(RemoteMessage message) async {
    // Laravel often sends data-only messages (notification object is null)
    final String title = message.notification?.title
        ?? message.data['title']
        ?? 'New Order';
    final String body = message.notification?.body
        ?? message.data['body']
        ?? message.data['message']
        ?? '';

    if (title.isEmpty && body.isEmpty) {
      print('Empty notification — skipping display');
      return;
    }

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: _notificationIcon,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _sendTokenToBackend(String fcmToken) async {
    try {
      String? authToken = await _storage.read(key: 'partner_access_token');
      if (authToken == null) {
        print('No auth token — skipping FCM update');
        return;
      }

      final response = await ApiClient.post(
        '/auth/update-fcm-token',
        body: {'fcm_token': fcmToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Partner FCM Token saved!');
      } else {
        print('Backend rejected FCM Token: ${response.body}');
      }
    } catch (e) {
      print('Error sending FCM token: $e');
    }
  }

  static Future<void> clearTokenOnLogout() async {
    await _sendTokenToBackend('');
    await _messaging.deleteToken();
    print('FCM Token cleared on logout');
  }
}