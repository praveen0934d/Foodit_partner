import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/analytics/analytics_bloc.dart';
import '../models/order_model.dart';

// ─── Design tokens ──────────────────────────────────────────
const _kBrand     = Color(0xFFFF5722);
const _kBrandDeep = Color(0xFFBF360C);
const _kSurface   = Color(0xFFF7F8FA);
const _kTextDark  = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF6B7280);
const _kTextLight = Color(0xFF9CA3AF);
const _kGreen     = Color(0xFF22C55E);
const _kPurple    = Color(0xFF6366F1);

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBrand, onPrimary: Colors.white, onSurface: _kTextDark),
        ),
        child: child!,
      ),
    );

    if (picked != null && context.mounted) {
      final start = picked.start.toIso8601String().split('T').first;
      final end   = picked.end.toIso8601String().split('T').first;
      context.read<AnalyticsBloc>().add(LoadAnalytics(dateFilter: '$start,$end'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Column(
          children: [
            _AnalyticsHeader(),
            Expanded(
              child: BlocConsumer<AnalyticsBloc, AnalyticsState>(
                listener: (context, state) {
                  if (state is AnalyticsError) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      margin: const EdgeInsets.all(16),
                    ));
                  }
                },
                builder: (context, state) {
                  if (state is AnalyticsLoading) {
                    return const Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 2.5));
                  }
                  if (state is AnalyticsLoaded) {
                    return RefreshIndicator(
                      color: _kBrand,
                      strokeWidth: 2.5,
                      onRefresh: () async => context.read<AnalyticsBloc>().add(LoadAnalytics(dateFilter: state.currentFilter)),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: [
                          const SizedBox(height: 20),
                          _buildTimeFilters(context, state.currentFilter),
                          const SizedBox(height: 24),
                          _buildStatCards(state),
                          const SizedBox(height: 28),
                          _buildSectionHeader('Recent Deliveries', '${state.deliveredOrders.length} orders'),
                          const SizedBox(height: 14),
                          if (state.deliveredOrders.isEmpty)
                            _buildEmptyDeliveries()
                          else
                            ...state.deliveredOrders.asMap().entries.map((e) =>
                              _AnimatedHistoryCard(order: e.value, index: e.key)
                            ),
                        ],
                      ),
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

  Widget _buildTimeFilters(BuildContext context, String currentFilter) {
    final isCustom = !['today', 'this_week', 'this_month'].contains(currentFilter);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(label: 'Today',      value: 'today',      current: currentFilter),
          const SizedBox(width: 8),
          _FilterChip(label: 'This Week',  value: 'this_week',  current: currentFilter),
          const SizedBox(width: 8),
          _FilterChip(label: 'This Month', value: 'this_month', current: currentFilter),
          const SizedBox(width: 8),
          _CustomDateChip(isActive: isCustom, onTap: () => _pickCustomDateRange(context)),
        ],
      ),
    );
  }

  Widget _buildStatCards(AnalyticsLoaded state) {
    return Row(
      children: [
        Expanded(
          child: _RevenueCard(revenue: state.totalRevenue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _OrdersCard(orders: state.totalOrders),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DELIVERIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _kBrand)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kTextDark, letterSpacing: -0.3)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBrand)),
        ),
      ],
    );
  }

  Widget _buildEmptyDeliveries() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.06), shape: BoxShape.circle),
            child: Icon(Icons.inbox_rounded, size: 40, color: _kBrand.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 14),
          const Text('No deliveries yet', style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Completed orders will appear here', style: TextStyle(color: _kTextLight, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Analytics Header ───────────────────────────────────────
class _AnalyticsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kBrandDeep, _kBrand], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ANALYTICS', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    const Text('Sales Overview', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter Chip ─────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, current;
  const _FilterChip({required this.label, required this.value, required this.current});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => context.read<AnalyticsBloc>().add(LoadAnalytics(dateFilter: value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? _kBrand : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _kBrand : const Color(0xFFE5E7EB), width: 1.5),
          boxShadow: isSelected
              ? [BoxShadow(color: _kBrand.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isSelected ? Colors.white : _kTextMid,
          ),
        ),
      ),
    );
  }
}

// ─── Custom Date Chip ────────────────────────────────────────
class _CustomDateChip extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _CustomDateChip({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isActive ? _kBrand : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? _kBrand : const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded, size: 15, color: isActive ? Colors.white : _kTextMid),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Custom Range' : 'Custom',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isActive ? Colors.white : _kTextMid),
          ),
        ],
      ),
    ),
  );
}

// ─── Revenue Card ────────────────────────────────────────────
class _RevenueCard extends StatelessWidget {
  final double revenue;
  const _RevenueCard({required this.revenue});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_kBrand, _kBrandDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: _kBrand.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 7))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 14),
        const Text('Revenue', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text('₹${revenue.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
      ],
    ),
  );
}

// ─── Orders Card ─────────────────────────────────────────────
class _OrdersCard extends StatelessWidget {
  final int orders;
  const _OrdersCard({required this.orders});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.receipt_long_rounded, color: _kPurple, size: 18),
        ),
        const SizedBox(height: 14),
        const Text('Orders', style: TextStyle(color: _kTextMid, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Text('$orders', style: const TextStyle(color: _kTextDark, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
      ],
    ),
  );
}

// ─── Animated History Card ───────────────────────────────────
class _AnimatedHistoryCard extends StatefulWidget {
  final Order order;
  final int index;
  const _AnimatedHistoryCard({required this.order, required this.index});

  @override
  State<_AnimatedHistoryCard> createState() => _AnimatedHistoryCardState();
}

class _AnimatedHistoryCardState extends State<_AnimatedHistoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _slide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F0F0)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.check_circle_rounded, color: _kGreen, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${widget.order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w800, color: _kTextDark, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.order.items.length} item${widget.order.items.length != 1 ? 's' : ''} · Delivered',
                      style: const TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${widget.order.totalAmount.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _kTextDark),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Paid', style: TextStyle(color: _kGreen, fontSize: 10, fontWeight: FontWeight.w800)),
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
