import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/battery_optimization_service.dart';
import 'dashboard_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final BatteryOptimizationService _batteryService =
      BatteryOptimizationService.instance;

  bool _isLoading = true;
  bool _notificationsGranted = false;
  bool _batteryExempted = false;
  bool _fullScreenGranted = false;
  bool _oemOpened = false;
  String _manufacturer = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initChecks();
    }
  }

  Future<void> _initChecks() async {
    setState(() => _isLoading = true);

    // 1. Check Notifications
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      _notificationsGranted = status.isGranted;
    } else {
      _notificationsGranted = true;
    }

    // 2. Check Battery Optimization
    final isOptimized = await _batteryService.isBatteryOptimized();
    _batteryExempted = !isOptimized;

    // 3. Check Full Screen Intent
    _fullScreenGranted = await _batteryService.canUseFullScreenIntent();

    // 4. OEM status & Manufacturer
    _manufacturer = await _batteryService.getManufacturer();
    _oemOpened = await _batteryService.hasOpenedOemSettings();

    if (mounted) setState(() => _isLoading = false);
  }

  bool _needsOem() {
    return ['xiaomi', 'redmi', 'poco', 'oppo', 'vivo', 'iqoo', 'huawei', 'honor', 'samsung', 'realme', 'oneplus']
        .any((mfr) => _manufacturer.toLowerCase().contains(mfr));
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
    }
    await _initChecks();
  }

  Future<void> _requestBattery() async {
    await _batteryService.requestBatteryExemption();
    // Flow resumes in didChangeAppLifecycleState
  }

  Future<void> _requestFullScreen() async {
    await _batteryService.requestFullScreenIntent();
    // Flow resumes in didChangeAppLifecycleState
  }

  void _showOemInstructions() {
    final instructions = _batteryService.getOemInstructions(_manufacturer);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_suggest_rounded, size: 48, color: Color(0xFFBF360C)),
              const SizedBox(height: 16),
              const Text(
                'Follow these steps:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  instructions,
                  style: const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBF360C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final opened = await _batteryService.openAutoStartSettings();
                    if (opened) {
                      await _batteryService.markOemSettingsOpened();
                    }
                  },
                  child: const Text('Open Settings Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _proceed() async {
    HapticFeedback.lightImpact();
    await _batteryService.updateLastCheckTimestamp();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  Widget _buildPermissionItem({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.greenAccent : Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
          ),
        ),
        trailing: isGranted
            ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28)
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFBF360C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: onTap,
                child: const Text('Fix', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFBF360C),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final bool allCoreGranted = _notificationsGranted && _batteryExempted && _fullScreenGranted;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFBF360C), Color(0xFFFF5722), Color(0xFFFF8A65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Critical Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'To ensure you never miss an order, FOODIT Partner requires the following settings to be enabled.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildPermissionItem(
                        title: 'Notifications',
                        subtitle: 'Required to alert you of new orders.',
                        isGranted: _notificationsGranted,
                        onTap: _requestNotification,
                      ),
                      _buildPermissionItem(
                        title: 'Battery Optimization',
                        subtitle: 'Prevents the app from sleeping in the background.',
                        isGranted: _batteryExempted,
                        onTap: _requestBattery,
                      ),
                      if (!_fullScreenGranted || Platform.isAndroid && (int.tryParse(Platform.operatingSystemVersion) ?? 0) >= 34)
                        _buildPermissionItem(
                          title: 'Full-Screen Alarms',
                          subtitle: 'Allows the app to wake the screen for orders.',
                          isGranted: _fullScreenGranted,
                          onTap: _requestFullScreen,
                        ),
                      if (_needsOem())
                        _buildPermissionItem(
                          title: 'Background Autostart',
                          subtitle: 'Required for ${_manufacturer.toUpperCase()} devices to keep the app alive.',
                          isGranted: _oemOpened,
                          onTap: _showOemInstructions,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFBF360C),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: allCoreGranted ? _proceed : null,
                    child: const Text(
                      'Verify & Continue',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                if (!allCoreGranted)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: TextButton(
                        onPressed: _proceed,
                        child: Text(
                          'Skip for now (Not Recommended)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
