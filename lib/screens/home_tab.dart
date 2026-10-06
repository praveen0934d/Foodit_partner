// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:foodit_partner/blocs/restaurant/restaurant_event.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../blocs/restaurant/restaurant_bloc.dart';
import '../models/restaurant_model.dart';
import '../services/cloudinary_service.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────
class _AppColors {
  static const Color brand      = Color(0xFFFF5722); // deep orange
  static const Color brandDeep  = Color(0xFFBF360C);
  static const Color surface    = Color(0xFFF7F8FA);
  static const Color textDark   = Color(0xFF1A1A2E);
  static const Color textMid    = Color(0xFF6B7280);
  static const Color textLight  = Color(0xFF9CA3AF);
  static const Color green      = Color(0xFF22C55E);
  static const Color red        = Color(0xFFEF4444);
  static const Color glassBg    = Color(0x1AFFFFFF); // 10% white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white
}

class _AppTextStyles {
  static const titleMd = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: _AppColors.textDark,
    letterSpacing: -0.3,
  );
  static const labelSm = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: _AppColors.textMid,
  );
}

// ─────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RestaurantBloc, RestaurantState>(
      listener: (context, state) {
        if (state is RestaurantError) {
          _showStyledSnackBar(context, state.message, isError: true);
        }
      },
      builder: (context, state) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: _AppColors.surface,
            body: _buildBody(context, state),
          ),
        );
      },
    );
  }

  void _showStyledSnackBar(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_rounded : Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: isError ? _AppColors.red : _AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildBody(BuildContext context, RestaurantState state) {
    if (state is RestaurantInitial || state is RestaurantLoading) return _buildSkeletonLoader();
    if (state is RestaurantEmpty)  return _buildNoRestaurantView(context);
    if (state is RestaurantLoaded) return _buildRestaurantView(context, state.restaurant);
    if (state is RestaurantError) {
      return _buildErrorView(context, state.message);
    }
    return const SizedBox.shrink();
  }

  // ── SKELETON ────────────────────────────────────────────────
  Widget _buildSkeletonLoader() {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE5E7EB),
        highlightColor: const Color(0xFFF9FAFB),
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            Container(
              height: 240,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  height: 96,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NO RESTAURANT ──────────────────────────────────────────
  Widget _buildNoRestaurantView(BuildContext context) {
    return RefreshIndicator(
      color: _AppColors.brand,
      strokeWidth: 2.5,
      onRefresh: () async {
        context.read<RestaurantBloc>().add(LoadRestaurant());
        // Wait until the bloc settles on a non-loading state
        await context.read<RestaurantBloc>().stream.firstWhere(
          (state) => state is! RestaurantLoading,
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: _AppColors.brand.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.store_mall_directory_outlined, size: 52, color: _AppColors.brand),
                ),
                const SizedBox(height: 20),
                const Text('No Restaurant Found', style: _AppTextStyles.titleMd),
                const SizedBox(height: 8),
                const Text('Set up your restaurant to get started', style: TextStyle(color: _AppColors.textMid, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('Pull down to refresh', style: TextStyle(color: _AppColors.textLight, fontSize: 12)),
                const SizedBox(height: 28),
                _PrimaryButton(
                  label: 'Reload',
                  icon: Icons.refresh_rounded,
                  onTap: () => context.read<RestaurantBloc>().add(LoadRestaurant()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ERROR ──────────────────────────────────────────────────
  Widget _buildErrorView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _AppColors.red.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, color: _AppColors.red, size: 48),
            ),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: _AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 28),
            _PrimaryButton(
              label: 'Try Again',
              icon: Icons.refresh_rounded,
              onTap: () => context.read<RestaurantBloc>().add(LoadRestaurant()),
            ),
          ],
        ),
      ),
    );
  }

  // ── MAIN RESTAURANT VIEW ───────────────────────────────────
  Widget _buildRestaurantView(BuildContext context, Restaurant restaurant) {
    final topPadding = MediaQuery.of(context).padding.top;
    return RefreshIndicator(
      color: _AppColors.brand,
      strokeWidth: 2.5,
      displacement: 60,
      onRefresh: () async => context.read<RestaurantBloc>().add(LoadRestaurant()),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── HERO HEADER ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeroHeaderDelegate(
              restaurant: restaurant,
              topPadding: topPadding,
              onToggleStatus: () => context.read<RestaurantBloc>().add(ToggleOpenStatus()),
            ),
          ),

          // ── STATS STRIP ──
          SliverToBoxAdapter(
            child: _AnimatedSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _StatsStrip(restaurant: restaurant),
            ),
          ),

          // ── SECTION HEADER ──
          SliverToBoxAdapter(
            child: _AnimatedSlideIn(
              delay: const Duration(milliseconds: 140),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MENU', style: _AppTextStyles.labelSm.copyWith(color: _AppColors.brand)),
                        const SizedBox(height: 2),
                        const Text('Management', style: _AppTextStyles.titleMd),
                      ],
                    ),
                    _AddItemButton(onTap: () => _showItemBottomSheet(context, null)),
                  ],
                ),
              ),
            ),
          ),

          // ── MENU ITEMS ──
          if (restaurant.menuItems.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyMenu())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _AnimatedSlideIn(
                    delay: Duration(milliseconds: 200 + (i * 60)),
                    child: _MenuItemCard(
                      item: restaurant.menuItems[i],
                      onEdit: () => _showItemBottomSheet(ctx, restaurant.menuItems[i]),
                      onDelete: () => _showDeleteConfirmation(ctx, restaurant.menuItems[i]),
                      onToggle: () => ctx.read<RestaurantBloc>().add(ToggleMenuItem(restaurant.menuItems[i].id)),
                    ),
                  ),
                  childCount: restaurant.menuItems.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyMenu() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _AppColors.brand.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant_menu_rounded, size: 48, color: _AppColors.brand.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          const Text('Menu is empty', style: TextStyle(color: _AppColors.textMid, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Tap "+ Add Item" to get started', style: TextStyle(color: _AppColors.textLight, fontSize: 13)),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _AppColors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_forever_rounded, color: _AppColors.red, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Delete Item?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _AppColors.textDark)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to remove "${item.name}" from your menu?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _AppColors.textMid, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: _AppColors.textMid, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<RestaurantBloc>().add(DeleteMenuItemRequested(item.id));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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

  void _showItemBottomSheet(BuildContext context, MenuItem? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<RestaurantBloc>(),
        child: MenuItemForm(existingItem: item),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ANIMATED SLIDE-IN WRAPPER
// ─────────────────────────────────────────────────────────────
class _AnimatedSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedSlideIn({required this.child, this.delay = Duration.zero});

  @override
  State<_AnimatedSlideIn> createState() => _AnimatedSlideInState();
}

class _AnimatedSlideInState extends State<_AnimatedSlideIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ─────────────────────────────────────────────────────────────
// HERO HEADER DELEGATE
// ─────────────────────────────────────────────────────────────
class _HeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Restaurant restaurant;
  final double topPadding;
  final VoidCallback onToggleStatus;

  const _HeroHeaderDelegate({
    required this.restaurant,
    required this.topPadding,
    required this.onToggleStatus,
  });

  @override
  double get maxExtent => topPadding + 210.0;
  @override
  double get minExtent => topPadding + 72.0;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate _) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1.0 - progress * 1.6).clamp(0.0, 1.0);
    final collapsedOpacity = ((progress - 0.6) * 2.5).clamp(0.0, 1.0);
    final initials = restaurant.name.length >= 2
        ? restaurant.name.substring(0, 2).toUpperCase()
        : restaurant.name.toUpperCase();

    return SizedBox(
      height: math.max(minExtent, maxExtent - shrinkOffset),
      child: Stack(
        children: [
          // ── GRADIENT BG ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_AppColors.brandDeep, _AppColors.brand],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
            ),
          ),

          // ── DECORATIVE CIRCLES ──
          Positioned(
            top: -20, right: -30,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 160, height: 160,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
          Positioned(
            bottom: 30, right: 40,
            child: Opacity(
              opacity: 0.07,
              child: Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),

          // ── EXPANDED CONTENT ──
          Positioned(
            top: topPadding + 16, left: 20, right: 20,
            child: Opacity(
              opacity: expandedOpacity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Logo Circle
                      Container(
                        height: 54, width: 54,
                        decoration: BoxDecoration(
                          color: _AppColors.glassBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: _AppColors.glassBorder, width: 1.5),
                        ),
                        child: Center(
                          child: Text(initials, style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1,
                          )),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(children: const [
                              Icon(Icons.location_pin, size: 13, color: Colors.white60),
                              SizedBox(width: 3),
                              Text('Campus Delivery', style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── COLLAPSED APP BAR TITLE ──
          Positioned(
            top: topPadding + 18, left: 20,
            child: Opacity(
              opacity: collapsedOpacity,
              child: Text(
                restaurant.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
            ),
          ),

          // ── STATUS GLASS CARD (always visible) ──
          Positioned(
            bottom: -1, left: 20, right: 20,
            child: _StatusGlassCard(restaurant: restaurant, onToggle: onToggleStatus),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STATUS GLASS CARD
// ─────────────────────────────────────────────────────────────
class _StatusGlassCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onToggle;
  const _StatusGlassCard({required this.restaurant, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isOpen = restaurant.isOpen;
    final color = isOpen ? _AppColors.green : _AppColors.red;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Store Status',
                      style: TextStyle(
                        color: _AppColors.textLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOpen ? 'Accepting Orders' : 'Closed',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch.adaptive(
                  value: isOpen,
                  activeColor: Colors.white,
                  activeTrackColor: _AppColors.green,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE5E7EB),
                  onChanged: (_) => onToggle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ANIMATED PULSE DOT
// ─────────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final bool isOpen;
  const _PulseDot({required this.isOpen});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOpen ? _AppColors.green : _AppColors.red;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isOpen)
            Container(
              width: 20 * _pulse.value, height: 20 * _pulse.value,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2 * _pulse.value), shape: BoxShape.circle),
            ),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STATS STRIP
// ─────────────────────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  final Restaurant restaurant;
  const _StatsStrip({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final totalItems = restaurant.menuItems.length;
    final vegItems = restaurant.menuItems.where((i) => i.isVeg).length;
    final availableItems = restaurant.menuItems.where((i) => i.isAvailable).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          _StatCard(label: 'Total Items', value: '$totalItems', icon: Icons.grid_view_rounded, color: _AppColors.brand),
          const SizedBox(width: 12),
          _StatCard(label: 'Veg', value: '$vegItems', icon: Icons.eco_rounded, color: _AppColors.green),
          const SizedBox(width: 12),
          _StatCard(label: 'Available', value: '$availableItems', icon: Icons.check_circle_outline_rounded, color: const Color(0xFF6366F1)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _AppColors.textDark, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: _AppColors.textMid, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADD ITEM BUTTON
// ─────────────────────────────────────────────────────────────
class _AddItemButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddItemButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_AppColors.brand, _AppColors.brandDeep]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _AppColors.brand.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MENU ITEM CARD (GLASS MORPHISM)
// ─────────────────────────────────────────────────────────────
class _MenuItemCard extends StatefulWidget {
  final MenuItem item;
  final VoidCallback onEdit, onDelete, onToggle;
  const _MenuItemCard({required this.item, required this.onEdit, required this.onDelete, required this.onToggle});

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0.97, upperBound: 1.0, value: 1.0);
    _scale = _pressCtrl;
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isVeg = item.isVeg;
    final isAvailable = item.isAvailable;

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.reverse(),
        onTapUp: (_) => _pressCtrl.forward(),
        onTapCancel: () => _pressCtrl.forward(),
        onTap: widget.onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 16, offset: const Offset(0, 5)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── IMAGE ──
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 80, width: 80,
                        color: const Color(0xFFF5F5F5),
                        child: (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: const Color(0xFFE5E7EB),
                                  highlightColor: const Color(0xFFF9FAFB),
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Color(0xFFD1D5DB), size: 28),
                              )
                            : const Icon(Icons.fastfood_rounded, color: Color(0xFFD1D5DB), size: 28),
                      ),
                    ),
                    if (!isAvailable)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 80, width: 80,
                          color: Colors.black.withValues(alpha: 0.38),
                          child: const Center(child: Text('OFF', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1))),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // ── DETAILS ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Veg badge
                      Row(
                        children: [
                          Container(
                            width: 13, height: 13,
                            decoration: BoxDecoration(
                              border: Border.all(color: isVeg ? _AppColors.green : _AppColors.red, width: 1.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Center(
                              child: Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isVeg ? _AppColors.green : _AppColors.red,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isVeg ? 'VEG' : 'NON-VEG',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: isVeg ? _AppColors.green : _AppColors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: _AppColors.textDark, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '₹${item.price.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.brand, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // ── ACTIONS ──
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IconBtn(icon: Icons.edit_rounded, color: const Color(0xFF6366F1), onTap: widget.onEdit),
                        const SizedBox(width: 6),
                        _IconBtn(icon: Icons.delete_outline_rounded, color: _AppColors.red, onTap: widget.onDelete),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: widget.onToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        width: 46, height: 26,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isAvailable ? _AppColors.green : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeInOut,
                          alignment: isAvailable ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 17),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// PRIMARY BUTTON
// ─────────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_AppColors.brand, _AppColors.brandDeep]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _AppColors.brand.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// MENU ITEM FORM (BOTTOM SHEET)
// ─────────────────────────────────────────────────────────────
class MenuItemForm extends StatefulWidget {
  final MenuItem? existingItem;
  const MenuItemForm({Key? key, this.existingItem}) : super(key: key);

  @override
  State<MenuItemForm> createState() => _MenuItemFormState();
}

class _MenuItemFormState extends State<MenuItemForm> with SingleTickerProviderStateMixin {
  final _nameCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();

  String? _selectedCategory;
  final List<String> _validCategories = ['biryani', 'tiffin', 'cake', 'fried_rice', 'chicken_curry', 'other'];

  bool _isVeg     = true;
  bool _isSaving  = false;
  File? _selectedImage;
  String? _currentImageUrl;

  late AnimationController _sheetCtrl;
  late Animation<Offset> _sheetAnim;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sheetAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));
    _sheetCtrl.forward();

    if (widget.existingItem != null) {
      final e = widget.existingItem!;
      _nameCtrl.text   = e.name;
      _priceCtrl.text  = e.price.toInt().toString();
      _isVeg           = e.isVeg;
      _currentImageUrl = e.imageUrl;
      _selectedCategory = e.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final ext  = pickedFile.path.split('.').last.toLowerCase();

    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a JPG or PNG image.'), backgroundColor: _AppColors.red));
      return;
    }
    final sizeMb = (await file.length()) / (1024 * 1024);
    if (sizeMb > 5.0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image must be under 5 MB.'), backgroundColor: _AppColors.red));
      return;
    }
    setState(() => _selectedImage = file);
  }

  Future<void> _handleSave() async {
    if (_nameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category.'), 
          backgroundColor: _AppColors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
      return; 
    }

    setState(() => _isSaving = true);
    String? finalImageUrl = _currentImageUrl;

    if (_selectedImage != null) {
      final url = await CloudinaryService.uploadImage(_selectedImage!);
      if (url != null) finalImageUrl = url;
    }

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'price': double.parse(_priceCtrl.text),
      'available_qty': 100,
      'is_veg': _isVeg,
      'prep_time_minutes': 15,
      'category': _selectedCategory, 
    };
    
    if (finalImageUrl != null && finalImageUrl.trim().isNotEmpty) data['images'] = [finalImageUrl];

    if (widget.existingItem == null) {
      context.read<RestaurantBloc>().add(AddMenuItemRequested(data));
    } else {
      context.read<RestaurantBloc>().add(EditMenuItemRequested(widget.existingItem!.id, data));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;
    return SlideTransition(
      position: _sheetAnim,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 0,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _AppColors.brand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(isEdit ? Icons.edit_rounded : Icons.add_rounded, color: _AppColors.brand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? 'Edit Menu Item' : 'New Menu Item',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _AppColors.textDark, letterSpacing: -0.4),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── IMAGE PICKER ──
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        height: 110, width: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : (_currentImageUrl != null && _currentImageUrl!.trim().isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _currentImageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Shimmer.fromColors(
                                        baseColor: const Color(0xFFE5E7EB),
                                        highlightColor: const Color(0xFFF9FAFB),
                                        child: Container(color: Colors.white),
                                      ),
                                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Color(0xFFD1D5DB), size: 30),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_outlined, color: _AppColors.brand, size: 28),
                                        const SizedBox(height: 8),
                                        Text('Upload', style: TextStyle(fontSize: 11, color: _AppColors.textMid, fontWeight: FontWeight.w700)),
                                      ],
                                    )),
                        ),
                      ),
                      Positioned(
                        bottom: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: _AppColors.brand, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _AppColors.brand.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── VEG / NON-VEG ──
              Row(
                children: [
                  _DietToggleCard(label: 'Veg', isSelected: _isVeg, isVeg: true, onTap: () => setState(() => _isVeg = true)),
                  const SizedBox(width: 12),
                  _DietToggleCard(label: 'Non-Veg', isSelected: !_isVeg, isVeg: false, onTap: () => setState(() => _isVeg = false)),
                ],
              ),
              const SizedBox(height: 20),

              // ── TEXT FIELDS ──
              _StyledTextField(controller: _nameCtrl, label: 'Item Name', icon: Icons.restaurant_rounded),
              const SizedBox(height: 14),
              _StyledTextField(controller: _priceCtrl, label: 'Price (₹)', icon: Icons.currency_rupee_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 14),

              // ── CATEGORY DROPDOWN ──
              _StyledDropdown(
                value: _selectedCategory,
                items: _validCategories,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 28),

              // ── SAVE BUTTON ──
              GestureDetector(
                onTap: _isSaving ? null : _handleSave,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isSaving
                          ? [Colors.grey.shade300, Colors.grey.shade400]
                          : [_AppColors.brand, _AppColors.brandDeep],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _isSaving ? [] : [BoxShadow(color: _AppColors.brand.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            isEdit ? 'Save Changes' : 'Add to Menu',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.2),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DIET TOGGLE CARD
// ─────────────────────────────────────────────────────────────
class _DietToggleCard extends StatelessWidget {
  final String label;
  final bool isSelected, isVeg;
  final VoidCallback onTap;
  const _DietToggleCard({required this.label, required this.isSelected, required this.isVeg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? _AppColors.green : _AppColors.red;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? color : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 13, height: 13,
                decoration: BoxDecoration(border: Border.all(color: color, width: 1.5), borderRadius: BorderRadius.circular(2)),
                child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? color : Colors.transparent))),
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? color : _AppColors.textMid, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STYLED TEXT FIELD
// ─────────────────────────────────────────────────────────────
class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  const _StyledTextField({required this.controller, required this.label, required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(fontWeight: FontWeight.w700, color: _AppColors.textDark, fontSize: 15),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _AppColors.textMid, fontWeight: FontWeight.w600, fontSize: 14),
      prefixIcon: Icon(icon, color: _AppColors.textLight, size: 20),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _AppColors.brand, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// STYLED DROPDOWN
// ─────────────────────────────────────────────────────────────
class _StyledDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _StyledDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _AppColors.textLight),
    decoration: InputDecoration(
      labelText: 'Category *',
      labelStyle: const TextStyle(color: _AppColors.textMid, fontWeight: FontWeight.w600, fontSize: 14),
      prefixIcon: const Icon(Icons.category_rounded, color: _AppColors.textLight, size: 20),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _AppColors.brand, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    style: const TextStyle(fontWeight: FontWeight.w700, color: _AppColors.textDark, fontSize: 15),
    dropdownColor: Colors.white,
    items: items.map((cat) {
      final pretty = cat.replaceAll('_', ' ').split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
      return DropdownMenuItem(value: cat, child: Text(pretty));
    }).toList(),
    onChanged: onChanged,
  );
}