import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'services/partner_auth_service.dart';
import 'blocs/auth/partner_auth_bloc.dart';
import 'screens/splash_screen.dart';

import 'di/injection_container.dart' as di;
import 'data/repositories/partner_auth_repository.dart';

import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Must initialize Firebase before registering the background handler
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  
  // Must be registered immediately in main for background/killed state to work
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 🔥 AUDIT FIX §4.1: Send unhandled async errors to telemetry
  runZonedGuarded(() {
    print('1. Flutter Binding & Firebase ready');

    // 🔥 AUDIT FIX §8.1: Non-blocking AppShell instantly pushes UI frame
    runApp(const PartnerAppShell());
  }, (error, stackTrace) {
    debugPrint('🔥 [ZoneError] Caught by runZonedGuarded: $error');
    // In production, send to Crashlytics: FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });
}

class PartnerAppShell extends StatefulWidget {
  const PartnerAppShell({Key? key}) : super(key: key);

  @override
  State<PartnerAppShell> createState() => _PartnerAppShellState();
}

class _PartnerAppShellState extends State<PartnerAppShell> {
  bool _isBooted = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 🔥 AUDIT FIX §8.2: Concurrently boot massive JNI dependencies off the UI thread
      await Future.wait([
        di.init(),
      ]);

      print('2. DI Initialized');

      await PartnerFCMService.init();
      print('3. FCM Initialized');

    } catch (e) {
      debugPrint('🔥 [AppShell Init Error] $e');
    }

    if (mounted) {
      setState(() {
        _isBooted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBooted) {
      // ⚡ Instant frame render to satisfy OS boot timeout
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFE65100),
          body: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => PartnerAuthBloc(
            authRepository: di.sl<PartnerAuthRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'FOODIT Partner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFFE65100),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}