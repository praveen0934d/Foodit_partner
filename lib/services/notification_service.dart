import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

class PartnerNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  // A stream that our UI can listen to when a new order arrives
  static final StreamController<String> _newOrderStream = StreamController<String>.broadcast();
  static Stream<String> get onNewOrder => _newOrderStream.stream;

  static Future<void> init() async {
    // 1. Request permissions for iOS/Android 13+
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Handle notifications while the app is OPEN (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('FOREGROUND NOTIFICATION RECEIVED: ${message.notification?.title}');
      
      // If it's a new order, tell the UI to refresh!
      if (message.data['type'] == 'new_order') {
        final orderId = message.data['order_id'] ?? '';
        _newOrderStream.add(orderId); // Broadcast the event to the UI
      }
    });

    // 3. Handle when the user TAPS the notification in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('👆 USER TAPPED NOTIFICATION: ${message.data}');
      if (message.data['type'] == 'new_order') {
        // Here you could use a GlobalKey<NavigatorState> to push directly to the Order Details screen
      }
    });
  }
}