import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:foodit_partner/blocs/order/order_bloc.dart';
import 'package:foodit_partner/blocs/restaurant/restaurant_event.dart';
import 'package:foodit_partner/screens/orders_tab.dart';
import '../services/restaurant_service.dart';
import '../blocs/restaurant/restaurant_bloc.dart';
import '../blocs/blocked_students/blocked_students_bloc.dart';
import 'home_tab.dart';
import '../blocs/analytics/analytics_bloc.dart';
import 'analytics_tab.dart';
import 'blocked_students_tab.dart';
import 'profile_tab.dart';
import '../services/fcm_service.dart';
import '../services/order_alarm_service.dart';
import '../services/battery_optimization_service.dart';
import 'permissions_screen.dart';

// ─── Design tokens ──────────────────────────────────────────

const _kBrand     = Color(0xFFFF5722);
const _kSurface   = Color(0xFFF7F8FA);
const _kTextMid   = Color(0xFF6B7280);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;

  StreamSubscription<Map<String, String>>? _orderSubscription;
  BuildContext? _innerContext;
  bool _listenersInitialized = false;
  bool _showBatteryBanner = false;

  late AnimationController _tabAnimCtrl;

  final List<Widget> _tabs = [
    const HomeTab(),
    const OrdersTab(),
    const AnalyticsTab(),
    const BlockedStudentsTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _tabAnimCtrl.forward();
    _checkBatteryOptimization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orderSubscription?.cancel();
    _tabAnimCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryOptimization();
      _checkPendingAlarmAction();
    }
  }

  /// Check if we need to show the battery optimization banner.
  Future<void> _checkBatteryOptimization() async {
    try {
      final service = BatteryOptimizationService.instance;
      final shouldShow = await service.shouldShowPrompt();
      final canUseFullScreen = await service.canUseFullScreenIntent();
      final shouldShowBanner = shouldShow || !canUseFullScreen;
      
      if (mounted && shouldShowBanner != _showBatteryBanner) {
        setState(() => _showBatteryBanner = shouldShowBanner);
      }
    } catch (e) {
      debugPrint('🔋 [Dashboard] Battery check failed: $e');
    }
  }

  /// Check if the user accepted/rejected an order from the notification
  /// while the app was in background/killed state.
  Future<void> _checkPendingAlarmAction() async {
    final pending = await OrderAlarmService.checkPendingAlarmAction();
    if (pending == null) return;

    final action = pending['action'];
    final orderId = pending['order_id'] ?? '';
    await OrderAlarmService.clearPendingAlarmAction();

    print('🔔 [Dashboard] Processing pending alarm action: $action for order: $orderId');

    if (_innerContext != null && _innerContext!.mounted) {
      final orderBloc = _innerContext!.read<OrderBloc>();
      final state = orderBloc.state;

      if (state is OrdersLoaded) {
        try {
          // Find the specific order in the pending list
          final order = state.pendingOrders.firstWhere((o) => o.id == orderId);
          
          if (action == 'accept') {
            orderBloc.add(AcceptOrderRequested(order));
          } else if (action == 'reject') {
            orderBloc.add(RejectOrderRequested(orderId, 'Rejected from notification'));
          }
        } catch (e) {
          // Order not found in pending list (might have been processed already)
          print('🔔 [Dashboard] Order $orderId not found in pending list, reloading orders instead');
          orderBloc.add(LoadActiveOrders());
        }
      } else {
        // If state isn't loaded yet, just trigger a reload as fallback
        orderBloc.add(LoadActiveOrders());
      }
    }

    // Switch to orders tab to see the result
    if (mounted) {
      _onTabChanged(1);
    }
  }

  void _setupNotificationListeners() {
    _orderSubscription = PartnerFCMService.onOrderUpdate.listen((eventData) {
      if (_innerContext == null || !_innerContext!.mounted) return;
      _innerContext!.read<OrderBloc>().add(LoadActiveOrders());
      
      final type = eventData['type'] ?? 'new_order';
      if (!PartnerFCMService.isViewingNewOrders) {
        _showOrderSnackbar(_innerContext!, type);
      }
    });
  }

  void _checkPendingReload() {
    if (!PartnerFCMService.hasPendingReload()) return;
    if (_innerContext == null || !_innerContext!.mounted) return;
    _innerContext!.read<OrderBloc>().add(LoadActiveOrders());
    // On pending reload, we assume it's a new order generally. Or we can just skip the snackbar on reload.
    if (!PartnerFCMService.isViewingNewOrders) {
      _showOrderSnackbar(_innerContext!, 'new_order');
    }
    PartnerFCMService.clearPendingReload();
  }

  void _showOrderSnackbar(BuildContext ctx, String eventType) {
    final bool isCancelled = eventType == 'order_cancelled';
    
    final Color mainColor = isCancelled ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final Color gradientEnd = isCancelled ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final IconData icon = isCancelled ? Icons.cancel_outlined : Icons.notifications_active_rounded;
    final String title = isCancelled ? 'Order Cancelled!' : 'New Order Received!';
    final String subtitle = isCancelled ? 'Customer cancelled an order' : 'Orders list has been refreshed';

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: mainColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [mainColor, gradientEnd]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _tabAnimCtrl.forward(from: 0);

    // Load blocked students when Students tab is selected
    if (index == 3 && _innerContext != null && _innerContext!.mounted) {
      final restaurantState = _innerContext!.read<RestaurantBloc>().state;
      if (restaurantState is RestaurantLoaded) {
        _innerContext!.read<BlockedStudentsBloc>().add(
          LoadBlockedStudents(restaurantState.restaurant.id),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => RestaurantBloc(RestaurantService())..add(LoadRestaurant())),
          BlocProvider(create: (_) => OrderBloc(RestaurantService())..add(LoadActiveOrders())),
          BlocProvider(create: (_) => AnalyticsBloc(RestaurantService())..add(LoadAnalytics())),
          BlocProvider(create: (_) => BlockedStudentsBloc(RestaurantService())),
        ],
        child: Builder(
          builder: (context) {
            _innerContext = context;
            if (!_listenersInitialized) {
              _listenersInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _setupNotificationListeners();
                _checkPendingReload();
              });
            }

            return Scaffold(
              backgroundColor: _kSurface,
              body: Column(
                children: [
                  // HIDING FOR NOW: Alarm feature is paused.
                  // Battery optimization banner
                  // if (_showBatteryBanner)
                  //   _BatteryBanner(
                  //     onTap: () {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                  //       ).then((_) => _checkBatteryOptimization());
                  //     },
                  //     onDismiss: () {
                  //       BatteryOptimizationService.instance.markPromptDismissed();
                  //       BatteryOptimizationService.instance.updateLastCheckTimestamp();
                  //       setState(() => _showBatteryBanner = false);
                  //     },
                  //   ),
                  Expanded(
                    child: FadeTransition(
                      opacity: CurvedAnimation(parent: _tabAnimCtrl, curve: Curves.easeOut),
                      child: _tabs[_currentIndex],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _StyledNavBar(
                currentIndex: _currentIndex,
                onTap: _onTabChanged,
              ),
              floatingActionButton: ValueListenableBuilder<bool>(
                valueListenable: OrderAlarmService.instance.isRingingNotifier,
                builder: (context, isRinging, child) {
                  if (!isRinging) return const SizedBox.shrink();
                  
                  return FloatingActionButton.extended(
                    onPressed: () {
                      OrderAlarmService.instance.stopAlarm();
                    },
                    backgroundColor: const Color(0xFFEF4444), // Red for Stop
                    icon: const Icon(Icons.notifications_off_rounded, color: Colors.white),
                    label: const Text('Stop Alarm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  );
                },
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STYLED BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────
class _StyledNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _StyledNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Orders'),
    _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analytics'),
    _NavItem(icon: Icons.person_off_outlined, activeIcon: Icons.person_off_rounded, label: 'Students'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? _kBrand.withValues(alpha: 0.10) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? _kBrand : _kTextMid,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive ? _kBrand : _kTextMid,
                          letterSpacing: 0.2,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// ─────────────────────────────────────────────────────────────
// BATTERY OPTIMIZATION BANNER
// ─────────────────────────────────────────────────────────────
class _BatteryBanner extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _BatteryBanner({required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF3CD),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: const Text(
                    'Order alerts may be delayed — tap to fix',
                    style: TextStyle(
                      color: Color(0xFF856404),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close_rounded, color: Color(0xFF856404), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
