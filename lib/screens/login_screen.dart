// ignore_for_file: unused_element_parameter, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/partner_auth_bloc.dart';
import 'dashboard_screen.dart';

const _kBrand     = Color(0xFFFF5722);
const _kBrandDeep = Color(0xFFBF360C);
const _kTextDark  = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF6B7280);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  bool _isSheetExpanded = false;

  late AnimationController _sheetCtrl;
  late AnimationController _formCtrl;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _formCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _formFade  = CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _formCtrl.dispose();
    super.dispose();
  }

  void _triggerSheet() {
    setState(() => _isSheetExpanded = true);
    _sheetCtrl.forward();
    _formCtrl.forward(from: 0);
  }

  void _reverseAnimation() {
    _sheetCtrl.reverse().then((_) {
      setState(() => _isSheetExpanded = false);
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: !_isSheetExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSheetExpanded) _reverseAnimation();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: BlocConsumer<PartnerAuthBloc, PartnerAuthState>(
            listener: (context, state) {
              if (state is AuthError) {
                _showSnack(state.message);
              } else if (state is AuthAuthenticated) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  (route) => false,
                );
              }
            },
            builder: (context, state) {
              final isLoading = state is AuthLoading;
              return Stack(
                children: [
                  _buildBackground(size),
                  _buildDecorImage(size),
                  _buildSlidingSheet(size, isLoading),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBrandDeep, _kBrand, Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -50,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle))),
          Positioned(top: 60, left: -40,
            child: Container(width: 120, height: 120,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle))),
          Positioned(
            top: size.height * 0.09,
            left: 28, right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 70, width: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.storefront_rounded, size: 42, color: _kBrand),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Manage orders,\nmenus & your\nrestaurant.',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.15, letterSpacing: -0.8),
                ),
                const SizedBox(height: 12),
                Text('Campus food, powered by you.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorImage(Size size) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
      bottom: _isSheetExpanded ? size.height * 0.82 : size.height * 0.44,
      left: 0, right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _isSheetExpanded ? 0.0 : 1.0,
        child: Center(
          child: SizedBox(
            height: 100,
            child: Image.asset('assets/icons/food_row.png', fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingSheet(Size size, bool isLoading) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.fastOutSlowIn,
      bottom: 0, left: 0, right: 0,
      height: _isSheetExpanded ? size.height * 0.72 : size.height * 0.50,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _isSheetExpanded
                ? _buildGoogleSignInContent(isLoading)
                : _buildInitialUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(4))),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _kTextDark, letterSpacing: -0.6)),
        const SizedBox(height: 6),
        const Text('Sign in to manage your restaurant', style: TextStyle(color: _kTextMid, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 32),
        _GradientButton(label: 'Partner Login / Register', icon: Icons.arrow_forward_rounded, onTap: _triggerSheet),
        const SizedBox(height: 14),
        Center(
          child: Text('By continuing, I accept the Terms & Privacy Policy',
            style: TextStyle(color: _kTextMid.withValues(alpha: 0.7), fontSize: 11)),
        ),
        const SizedBox(height: 28),
        _buildQuickLinks(),
      ],
    );
  }

  Widget _buildGoogleSignInContent(bool isLoading) {
    return SlideTransition(
      position: _formSlide,
      child: FadeTransition(
        opacity: _formFade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(4))),
              ),
            ),
            GestureDetector(
              onTap: _reverseAnimation,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_rounded, size: 20, color: _kTextDark),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Partner Sign In', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _kTextDark, letterSpacing: -0.6)),
            const SizedBox(height: 6),
            const Text('Use your Google account to access your restaurant dashboard.',
              style: TextStyle(color: _kTextMid, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kBrand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBrand.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.storefront_rounded, color: _kBrand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Restaurant Partner', style: TextStyle(fontWeight: FontWeight.w900, color: _kTextDark, fontSize: 13)),
                        SizedBox(height: 3),
                        Text('Sign in with your registered Google account', style: TextStyle(color: _kTextMid, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Google Sign-In Button
            GestureDetector(
              onTap: isLoading ? null : () {
                context.read<PartnerAuthBloc>().add(GoogleSignInRequested());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity, height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                  boxShadow: isLoading ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: _kBrand.withValues(alpha: 0.8), strokeWidth: 2.5)),
                            const SizedBox(width: 14),
                            const Text('Signing in...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextDark)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 22, height: 22,
                              errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 26),
                            ),
                            const SizedBox(width: 12),
                            const Text('Continue with Google',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextDark)),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('Only registered restaurant partners can sign in',
                style: TextStyle(color: _kTextMid.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        children: [
          _QuickLinkTile(icon: Icons.local_offer_outlined, label: 'Partner Guidelines'),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          _QuickLinkTile(icon: Icons.help_outline_rounded, label: 'Help & Support'),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  const _GradientButton({required this.label, required this.icon, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity, height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: (onTap == null || isLoading)
              ? [Colors.grey.shade300, Colors.grey.shade400]
              : [_kBrand, _kBrandDeep],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: (onTap == null || isLoading) ? [] : [
          BoxShadow(color: _kBrand.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.2)),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 18),
                ],
              ),
      ),
    ),
  );
}

class _QuickLinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickLinkTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: _kBrand, size: 18),
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: _kTextDark, fontSize: 14)),
    trailing: const Icon(Icons.chevron_right_rounded, color: _kTextMid, size: 20),
    onTap: () {},
  );
}