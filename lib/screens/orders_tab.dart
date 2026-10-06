import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../blocs/order/order_bloc.dart';
import '../models/order_model.dart';
import '../blocs/restaurant/restaurant_bloc.dart';
import '../services/fcm_service.dart';
import '../services/order_alarm_service.dart';

// ─── Design tokens ──────────────────────────────────────────
const _kBrand     = Color(0xFFFF5722);
const _kBrandDeep = Color(0xFFBF360C);
const _kSurface   = Color(0xFFF7F8FA);
const _kTextDark  = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF6B7280);
const _kTextLight = Color(0xFF9CA3AF);
const _kGreen     = Color(0xFF22C55E);
const _kRed       = Color(0xFFEF4444);
const _kPurple    = Color(0xFF8B5CF6);

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Track which order is currently processing
  String? _processingOrderId;
  String? _processingAction; // 'accept' or 'cancel'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    PartnerFCMService.isViewingNewOrders = true;

    // Stop alarm when user opens Orders tab (acknowledging the order)
    OrderAlarmService.instance.stopAlarm();
    OrderAlarmService.stopNativeAlarm();

    _tabController.addListener(() {
      PartnerFCMService.isViewingNewOrders = (_tabController.index == 0);
      // Also stop alarm when switching back to pending tab
      if (_tabController.index == 0) {
        OrderAlarmService.instance.stopAlarm();
        OrderAlarmService.stopNativeAlarm();
      }
    });
  }

  @override
  void dispose() {
    PartnerFCMService.isViewingNewOrders = false;
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Column(
          children: [
            _OrdersHeader(tabController: _tabController),
            Expanded(
              child: BlocConsumer<OrderBloc, OrderState>(
                listener: (context, state) {
                  if (state is OrdersError) {
                    // Clear loading state if there's an error
                    if (mounted) setState(() {
                      _processingOrderId = null;
                      _processingAction = null;
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: _kRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      margin: const EdgeInsets.all(16),
                    ));
                  } else if (state is OrdersLoaded) {
                    // Clear loading state when data reloads
                    if (mounted) setState(() {
                      _processingOrderId = null;
                      _processingAction = null;
                    });
                  }
                },
                builder: (context, state) {
                  if (state is OrdersLoading) {
                    return const Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 2.5));
                  }
                  if (state is OrdersLoaded) {
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrderList(context, state.pendingOrders, tabType: 'pending'),
                        _PreparingOrdersList(
                          orders: state.preparingOrders,
                          onRefresh: () async => context.read<OrderBloc>().add(LoadActiveOrders()),
                          onDispatchSelected: (selectedOrders) => _showBulkAssignDialog(context, selectedOrders),
                          cardBuilder: (order, isSelected, onSelectionChanged) =>
                              _buildOrderCard(context, order, 'preparing',
                                  showCheckbox: true, isSelected: isSelected, onSelectionChanged: onSelectionChanged),
                        ),
                        _buildOrderList(context, state.outForDeliveryOrders, tabType: 'dispatched'),
                        _buildOrderList(context, state.historyOrders, tabType: 'history'),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, List<Order> orders, {required String tabType}) {
    final emptyMsg = {
      'pending':    'No new orders right now',
      'preparing':  'Kitchen is clear!',
      'dispatched': 'No active deliveries',
      'history':    'No past orders yet',
    }[tabType] ?? 'No orders found';

    // Reverse so newest orders appear at the bottom instead of the top
    final displayOrders = orders.reversed.toList();

    return RefreshIndicator(
      color: _kBrand,
      strokeWidth: 2.5,
      onRefresh: () async => context.read<OrderBloc>().add(LoadActiveOrders()),
      child: displayOrders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                _buildEmptyState(tabType, emptyMsg),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: displayOrders.length,
              itemBuilder: (context, index) => _buildOrderCard(context, displayOrders[index], tabType),
            ),
    );
  }

  Widget _buildEmptyState(String tabType, String msg) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.06), shape: BoxShape.circle),
          child: Icon(
            tabType == 'history' ? Icons.history_rounded : Icons.receipt_long_rounded,
            size: 44, color: _kBrand.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: 16),
        Text(msg, style: const TextStyle(fontSize: 17, color: _kTextMid, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Pull down to refresh', style: TextStyle(fontSize: 13, color: _kTextLight)),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order, String tabType, {
    bool showCheckbox = false,
    bool isSelected = false,
    ValueChanged<bool?>? onSelectionChanged,
  }) {
    return GestureDetector(
      onTap: showCheckbox ? () => onSelectionChanged?.call(!isSelected) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: showCheckbox && isSelected ? _kBrand : const Color(0xFFF0F0F0),
            width: showCheckbox && isSelected ? 2 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CARD HEADER ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: showCheckbox && isSelected ? _kBrand.withValues(alpha: 0.04) : const Color(0xFFFAFAFA),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  if (showCheckbox) ...[
                    _StyledCheckbox(value: isSelected, onChanged: onSelectionChanged),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${order.orderNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _kTextDark, letterSpacing: -0.3)),
                        const SizedBox(height: 3),
                        Text('${order.studentName}',
                          style: const TextStyle(color: _kTextMid, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (tabType == 'history' || tabType == 'dispatched')
                    _buildStatusBadge(order.status)
                  else
                    Text('₹${order.totalAmount.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _kBrand)),
                ],
              ),
            ),

            // ── DELIVERY AGENT BANNER ──
            if (order.deliveryAgentName != null &&
                (order.status == 'out_for_delivery' || order.status == 'at_gate' || order.status == 'delivered'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: order.status == 'delivered'
                    ? _kGreen.withValues(alpha: 0.06)
                    : order.status == 'at_gate'
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.06)
                        : _kPurple.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Icon(
                      order.status == 'delivered'
                          ? Icons.check_circle_rounded
                          : order.status == 'at_gate'
                              ? Icons.location_on_rounded
                              : Icons.moped_rounded,
                      color: order.status == 'delivered'
                          ? _kGreen
                          : order.status == 'at_gate'
                              ? const Color(0xFFF59E0B)
                              : _kPurple,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.status == 'delivered'
                            ? 'Delivered by ${order.deliveryAgentName}'
                            : order.status == 'at_gate'
                                ? 'At gate — ${order.deliveryAgentName}'
                                : 'Out for delivery by ${order.deliveryAgentName}',
                        style: TextStyle(
                          color: order.status == 'delivered'
                              ? _kGreen
                              : order.status == 'at_gate'
                                  ? const Color(0xFFF59E0B)
                                  : _kPurple,
                          fontWeight: FontWeight.w700, fontSize: 13,
                        ),
                      ),
                    ),

                  ],
                ),
              ),

            // ── ORDER ITEMS ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kBrand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text('${item.quantity}x',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _kBrand)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark))),
                    ],
                  ),
                )).toList(),
              ),
            ),

            if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kBrand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBrand.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: _kBrandDeep),
                          SizedBox(width: 6),
                          Text('Special Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kBrandDeep)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(order.specialInstructions!, style: const TextStyle(fontSize: 13, color: _kBrandDeep, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),

            // ── TOTAL AND DISCOUNT ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.discountAmount > 0) ...[
                    Row(
                      children: [
                        const Icon(Icons.local_offer_rounded, size: 14, color: _kBrand),
                        const SizedBox(width: 4),
                        Text(
                          order.couponCode != null && order.couponCode!.isNotEmpty
                              ? "Coupon '${order.couponCode}' applied"
                              : "Coupon applied by user",
                          style: const TextStyle(color: _kBrand, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Original Price:', style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 6),
                        Text('₹${(order.totalAmount + order.discountAmount).toInt()}', 
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextMid, decoration: TextDecoration.lineThrough)),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      Text(order.discountAmount > 0 ? 'Final Total:' : 'Total:', style: const TextStyle(color: _kTextMid, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 6),
                      Text('₹${order.totalAmount.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _kTextDark)),
                    ],
                  ),
                ],
              ),
            ),

            // ── ACTION BUTTONS (pending only) ──
            if (tabType == 'pending')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SwipeActionButton(
                        label: 'Swipe Cancel',
                        loadingLabel: 'Canceling...',
                        color: _kRed,
                        isLoading: _processingOrderId == order.id && _processingAction == 'cancel',
                        onSwipe: _processingOrderId != null ? null : () => _showAdvancedRejectDialog(context, order),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SwipeActionButton(
                        label: 'Swipe Accept',
                        loadingLabel: 'Accepting...',
                        color: _kGreen,
                        isLoading: _processingOrderId == order.id && _processingAction == 'accept',
                        onSwipe: _processingOrderId != null ? null : () {
                          setState(() {
                            _processingOrderId = order.id;
                            _processingAction = 'accept';
                          });
                          context.read<OrderBloc>().add(AcceptOrderRequested(order));
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg, fg;
    String text;

    switch (status) {
      case 'out_for_delivery': bg = _kPurple.withValues(alpha: 0.10); fg = _kPurple; text = 'ON THE WAY'; break;
      case 'at_gate':          bg = const Color(0xFFF59E0B).withValues(alpha: 0.10); fg = const Color(0xFFF59E0B); text = 'AT GATE'; break;
      case 'delivered':        bg = _kGreen.withValues(alpha: 0.10);  fg = _kGreen;  text = 'DELIVERED';  break;
      case 'not_picked_up':    bg = _kRed.withValues(alpha: 0.10);    fg = _kRed;    text = 'NOT PICKED UP'; break;
      case 'rejected':
      case 'cancelled':        bg = _kRed.withValues(alpha: 0.10);    fg = _kRed;    text = status.toUpperCase(); break;
      default:                 bg = const Color(0xFFF3F4F6);    fg = _kTextMid; text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.5)),
    );
  }

  void _showAdvancedRejectDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<OrderBloc>(),
        child: _RejectDialogContent(
          order: order,
          onConfirm: () {
            if (mounted) {
              setState(() {
                _processingOrderId = order.id;
                _processingAction = 'cancel';
              });
            }
          },
        ),
      ),
    );
  }

  void _showBulkAssignDialog(BuildContext context, List<Order> preparingOrders) {
    final restaurantState = context.read<RestaurantBloc>().state;
    if (restaurantState is! RestaurantLoaded) return;
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<OrderBloc>(),
        child: _BulkAssignDialogContent(
          preparingOrders: preparingOrders,
          restaurantId: restaurantState.restaurant.id,
        ),
      ),
    );
  }
}

// ─── Orders Header ───────────────────────────────────────────
class _OrdersHeader extends StatelessWidget {
  final TabController tabController;
  const _OrdersHeader({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kBrandDeep, _kBrand], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ORDERS', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        const Text('Live Queue', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            BlocBuilder<OrderBloc, OrderState>(
              builder: (context, state) {
                int pendingCount = 0, preparingCount = 0, onWayCount = 0, historyCount = 0;
                if (state is OrdersLoaded) {
                  pendingCount = state.pendingOrders.length;
                  preparingCount = state.preparingOrders.length;
                  onWayCount = state.outForDeliveryOrders.length;
                  historyCount = state.historyOrders.length;
                }
                return TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tabs: [
                    Tab(text: pendingCount > 0 ? 'NEW ORDERS ($pendingCount)' : 'NEW ORDERS'),
                    Tab(text: preparingCount > 0 ? 'COOKING ($preparingCount)' : 'COOKING'),
                    Tab(text: onWayCount > 0 ? 'ON THE WAY ($onWayCount)' : 'ON THE WAY'),
                    Tab(text: historyCount > 0 ? 'HISTORY ($historyCount)' : 'HISTORY'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Styled Checkbox ─────────────────────────────────────────
class _StyledCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  const _StyledCheckbox({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged?.call(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: value ? _kBrand : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: value ? _kBrand : const Color(0xFFD1D5DB), width: 2),
      ),
      child: value ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
    ),
  );
}

// ─── Action Buttons ───────────────────────────────────────────
class _OutlineActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;
  const _OutlineActionButton({required this.label, required this.color, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isLoading ? null : onTap,
    child: Container(
      height: 46, // Fixed height keeps skeleton identical to Filled button
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.04),
      ),
      child: Center(
        child: isLoading 
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: color.withValues(alpha: 0.2),
                  color: color,
                  minHeight: 4,
                ),
              ),
            )
          : Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    ),
  );
}

class _SwipeActionButton extends StatefulWidget {
  final String label;
  final String loadingLabel;
  final Color color;
  final VoidCallback? onSwipe;
  final bool isLoading;

  const _SwipeActionButton({
    required this.label,
    required this.loadingLabel,
    required this.color,
    required this.onSwipe,
    this.isLoading = false,
  });

  @override
  State<_SwipeActionButton> createState() => _SwipeActionButtonState();
}

class _SwipeActionButtonState extends State<_SwipeActionButton> {
  double _dragPosition = 0.0;
  bool _isAccepted = false;

  @override
  void didUpdateWidget(_SwipeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && oldWidget.isLoading) {
      setState(() {
        _isAccepted = false;
        _dragPosition = 0.0;
      });
    } else if (widget.isLoading) {
      _isAccepted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 46;
        final currentPosition = widget.isLoading ? maxDrag : _dragPosition;

        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    widget.isLoading ? widget.loadingLabel : widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 46,
                width: currentPosition + 46,
                decoration: BoxDecoration(
                  color: widget.isLoading ? widget.color : widget.color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: widget.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white30,
                            color: Colors.white,
                            minHeight: 4,
                          ),
                        ),
                      ),
                    )
                  : null,
              ),
              if (!widget.isLoading)
                Positioned(
                  left: currentPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: widget.onSwipe == null ? null : (details) {
                      setState(() {
                        _dragPosition += details.delta.dx;
                        if (_dragPosition < 0) _dragPosition = 0;
                        if (_dragPosition > maxDrag) {
                          _dragPosition = maxDrag;
                          if (!_isAccepted) {
                            _isAccepted = true;
                            widget.onSwipe?.call();
                          }
                        }
                      });
                    },
                    onHorizontalDragEnd: widget.onSwipe == null ? null : (details) {
                      if (!_isAccepted) {
                        setState(() {
                          _dragPosition = 0.0;
                        });
                      }
                    },
                    child: Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.double_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Preparing Orders List ───────────────────────────────────
class _PreparingOrdersList extends StatefulWidget {
  final List<Order> orders;
  final Future<void> Function() onRefresh;
  final Function(List<Order>) onDispatchSelected;
  final Widget Function(Order, bool, ValueChanged<bool?>?) cardBuilder;

  const _PreparingOrdersList({
    required this.orders,
    required this.onRefresh,
    required this.onDispatchSelected,
    required this.cardBuilder,
  });

  @override
  State<_PreparingOrdersList> createState() => _PreparingOrdersListState();
}

class _PreparingOrdersListState extends State<_PreparingOrdersList> {
  final Set<String> _selectedIds = {};

  @override
  void didUpdateWidget(_PreparingOrdersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.orders.map((o) => o.id).toSet();
    _selectedIds.removeWhere((id) => !currentIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return RefreshIndicator(
        color: _kBrand,
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.06), shape: BoxShape.circle),
                  child: Icon(Icons.restaurant_rounded, size: 44, color: _kBrand.withValues(alpha: 0.35)),
                ),
                const SizedBox(height: 16),
                const Text('Kitchen is clear!', style: TextStyle(fontSize: 17, color: _kTextMid, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      );
    }

    final allSelected = _selectedIds.length == widget.orders.length;

    return Column(
      children: [
        // Select All bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: GestureDetector(
            onTap: () => setState(() {
              if (allSelected) _selectedIds.clear();
              else _selectedIds.addAll(widget.orders.map((o) => o.id));
            }),
            child: Row(
              children: [
                _StyledCheckbox(
                  value: allSelected,
                  onChanged: (val) => setState(() {
                    if (val == true) _selectedIds.addAll(widget.orders.map((o) => o.id));
                    else _selectedIds.clear();
                  }),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select All (${widget.orders.length} Orders)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextDark),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: _kBrand,
            onRefresh: widget.onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              itemCount: widget.orders.length,
              itemBuilder: (context, index) {
                final order = widget.orders[index];
                final isSelected = _selectedIds.contains(order.id);
                return widget.cardBuilder(order, isSelected, (bool? val) {
                  setState(() {
                    if (val == true) _selectedIds.add(order.id);
                    else _selectedIds.remove(order.id);
                  });
                });
              },
            ),
          ),
        ),

        // Dispatch bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -5))],
          ),
          child: GestureDetector(
            onTap: _selectedIds.isEmpty ? null : () {
              final selectedOrders = widget.orders.where((o) => _selectedIds.contains(o.id)).toList();
              widget.onDispatchSelected(selectedOrders);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                gradient: _selectedIds.isEmpty
                    ? null
                    : const LinearGradient(colors: [_kBrand, _kBrandDeep]),
                color: _selectedIds.isEmpty ? const Color(0xFFF3F4F6) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _selectedIds.isEmpty ? [] : [
                  BoxShadow(color: _kBrand.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.moped_rounded, color: _selectedIds.isEmpty ? _kTextLight : Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _selectedIds.isEmpty
                          ? 'Select Orders to Dispatch'
                          : 'Dispatch ${_selectedIds.length} Order(s)',
                      style: TextStyle(
                        color: _selectedIds.isEmpty ? _kTextLight : Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reject Dialog ────────────────────────────────────────────
class _RejectDialogContent extends StatefulWidget {
  final Order order;
  final VoidCallback onConfirm;
  const _RejectDialogContent({required this.order, required this.onConfirm});

  @override
  State<_RejectDialogContent> createState() => _RejectDialogContentState();
}

class _RejectDialogContentState extends State<_RejectDialogContent> {
  final Set<String> _unavailableItems = {};
  final _noteCtrl = TextEditingController();

  void _submitRejection() {
    String finalReason = '';
    if (_unavailableItems.isNotEmpty) {
      final names = widget.order.items.where((i) => _unavailableItems.contains(i.id)).map((i) => i.name).join(', ');
      finalReason = 'Out of stock: $names. ';
    }
    if (_noteCtrl.text.trim().isNotEmpty) finalReason += _noteCtrl.text.trim();
    if (finalReason.isEmpty) finalReason = 'Cancelled by restaurant.';
    context.read<OrderBloc>().add(RejectOrderRequested(widget.order.id, finalReason));
    widget.onConfirm();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.cancel_rounded, color: _kRed, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Cancel Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kTextDark)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Unavailable items:', style: TextStyle(fontWeight: FontWeight.w700, color: _kTextDark, fontSize: 13)),
            const SizedBox(height: 8),
            ...widget.order.items.map((item) => GestureDetector(
              onTap: () => setState(() {
                if (_unavailableItems.contains(item.id)) _unavailableItems.remove(item.id);
                else _unavailableItems.add(item.id);
              }),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _StyledCheckbox(
                      value: _unavailableItems.contains(item.id),
                      onChanged: (val) => setState(() {
                        if (val == true) _unavailableItems.add(item.id);
                        else _unavailableItems.remove(item.id);
                      }),
                    ),
                    const SizedBox(width: 10),
                    Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kTextDark)),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 14),
            const Text('Or add a note:', style: TextStyle(fontWeight: FontWeight.w700, color: _kTextDark, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g., Kitchen closed',
                hintStyle: const TextStyle(color: _kTextLight),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBrand, width: 2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: const Text('Back', style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitRejection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bulk Assign Dialog ───────────────────────────────────────
class _BulkAssignDialogContent extends StatefulWidget {
  final List<Order> preparingOrders;
  final String restaurantId;
  const _BulkAssignDialogContent({required this.preparingOrders, required this.restaurantId});

  @override
  State<_BulkAssignDialogContent> createState() => _BulkAssignDialogContentState();
}

class _BulkAssignDialogContentState extends State<_BulkAssignDialogContent> {
  List<Map<String, dynamic>> _agents = [];
  String? _selectedAgentId;
  bool _isLoading = true;
  bool _isDispatching = false; // Added tracking state for dispatch action
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  Future<void> _fetchAgents() async {
    try {
      final service = context.read<OrderBloc>().service;
      final agents = await service.getRestaurantDeliveryAgents(widget.restaurantId);
      if (mounted) {
        setState(() {
          _agents = agents;
          _isLoading = false;
          if (_agents.isNotEmpty) _selectedAgentId = _agents.first['delivery_agent']['id'];
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderBloc, OrderState>(
      listener: (context, state) {
        if (_isDispatching && (state is OrdersLoaded || state is OrdersError)) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.moped_rounded, color: _kBrand, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Assign Agent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kTextDark)),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 2.5)))
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Text('Error: $_error', style: const TextStyle(color: _kRed, fontWeight: FontWeight.w600)),
                )
              else if (_agents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                  child: const Text('No active delivery agents found.', style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w600)),
                )
              else ...[
                Text(
                  'Dispatch ${widget.preparingOrders.length} order(s) with:',
                  style: const TextStyle(color: _kTextMid, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedAgentId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kTextLight),
                  decoration: InputDecoration(
                    labelText: 'Select Agent',
                    labelStyle: const TextStyle(color: _kTextMid, fontWeight: FontWeight.w600),
                    filled: true, fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBrand, width: 2)),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _kTextDark, fontSize: 14),
                  dropdownColor: Colors.white,
                  items: _agents.map((agent) {
                    final da = agent['delivery_agent'];
                    return DropdownMenuItem<String>(
                      value: da['id'],
                      child: Text('${da['name']}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: _isDispatching ? null : (val) => setState(() => _selectedAgentId = val),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isDispatching ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand, padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                      ),
                      onPressed: (_isLoading || _isDispatching || _agents.isEmpty || _selectedAgentId == null) ? null : () {
                        setState(() => _isDispatching = true); // Activate loading spinner
                        final orderIds = widget.preparingOrders.map((o) => o.id).toList();
                        context.read<OrderBloc>().add(BulkAssignAgentRequested(orderIds, _selectedAgentId!));
                      },
                      child: _isDispatching 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                            )
                          : const Text('Dispatch Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}