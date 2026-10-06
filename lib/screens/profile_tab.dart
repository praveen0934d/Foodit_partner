import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../blocs/restaurant/restaurant_bloc.dart'; 
import '../blocs/restaurant/restaurant_event.dart'; 
import '../models/restaurant_model.dart';
import '../services/cloudinary_service.dart';
import '../services/restaurant_service.dart';
import '../services/partner_auth_service.dart';
import 'edit_restaurant_screen.dart';
import 'login_screen.dart';

// ─── Design tokens ──────────────────────────────────────────
const _kBrand     = Color(0xFFFF5722);
const _kBrandDeep = Color(0xFFBF360C);
const _kSurface   = Color(0xFFF7F8FA);
const _kTextDark  = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF6B7280);
const _kTextLight = Color(0xFF9CA3AF);
const _kGreen     = Color(0xFF22C55E);
const _kRed       = Color(0xFFEF4444);
const _kAmber     = Color(0xFFF59E0B);

// ─── Reusable Preview Dialog Helper ─────────────────────────
Future<bool> _showImagePreviewDialog(BuildContext context, File imageFile, String title) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: _kTextDark)),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(imageFile, height: 220, width: double.infinity, fit: BoxFit.cover),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.only(bottom: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBrand,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ],
    ),
  ) ?? false;
}

// ─── Helper to enforce the [Logo, QR] array structure ───────
List<String> _ensureImageArrayStructure(List<dynamic>? existingImages) {
  List<String> images = (existingImages ?? []).map((e) => e.toString()).toList();
  while (images.length < 2) {
    images.add('https://placehold.co/1x1.png'); // Index 0: Logo, Index 1: QR (Use valid URL to pass backend validation)
  }
  return images;
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
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
                decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded, color: _kRed, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Log Out?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kTextDark)),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to log out of your partner account?',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextMid, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        backgroundColor: _kRed, elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        final authService = PartnerAuthService();
        await authService.logout();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        debugPrint("Logout API error, proceeding with local logout: $e");
      }
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()), 
          (route) => false, 
        );
      }
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    final Uri uri = Uri(scheme: 'mailto', path: 'support@fooditcampus.com', query: 'subject=Partner Support Request');
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open email app. Contact: support@fooditcampus.com'),
          backgroundColor: _kRed,
        ));
      }
    }
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(4))),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kBrand.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.notifications_rounded, color: _kBrand, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Notification Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kTextDark)),
              ],
            ),
            const SizedBox(height: 20),
            _NotifToggle(
              title: 'New Order Alerts',
              subtitle: 'Loud ringtone when a new order arrives',
              value: true,
              onChanged: (val) => Navigator.pop(ctx),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _NotifToggle(
              title: 'Agent Arrival Alerts',
              subtitle: 'Notified when delivery agent is near',
              value: true,
              onChanged: (val) => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Column(
          children: [
            _ProfileHeader(
              service: context.read<RestaurantBloc>().service,
            ),
            Expanded(
              child: BlocBuilder<RestaurantBloc, RestaurantState>(
                builder: (context, state) {
                  if (state is RestaurantLoading) {
                    return const Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 2.5));
                  }
                  if (state is RestaurantLoaded) {
                    return _buildProfileContent(context, state.restaurant);
                  }
                  if (state is RestaurantError) {
                    return Center(child: Text('Error: ${state.message}', style: const TextStyle(color: _kRed)));
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

  Widget _buildProfileContent(BuildContext context, Restaurant restaurant) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        // ── RESTAURANT CARD ──
        const SizedBox(height: 20),
        _RestaurantCard(restaurant: restaurant),
        const SizedBox(height: 28),

        // ── ACCOUNT SETTINGS ──
        const _SectionLabel('Account Settings'),
        const SizedBox(height: 10),
        _SettingsGroup(
          items: [
            _SettingItem(
              icon: Icons.storefront_rounded,
              color: _kBrand,
              title: 'Edit Restaurant Info',
              subtitle: 'Update name, description & minimum order',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<RestaurantBloc>(),
                  child: EditRestaurantScreen(restaurant: restaurant),
                ),
              )),
            ),
            // QR Code Tile
            _SettingItem(
              icon: Icons.qr_code_2_rounded,
              color: Colors.blueAccent,
              title: 'Payment QR Code',
              subtitle: 'Upload your UPI QR code for payments',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<RestaurantBloc>(),
                  child: UploadQRScreen(restaurant: restaurant),
                ),
              )),
            ),
            _SettingItem(
              icon: Icons.phone_rounded,
              color: _kGreen,
              title: 'Contact Details',
              subtitle: restaurant.phone ?? 'No phone added',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── SYSTEM ──
        const _SectionLabel('System'),
        const SizedBox(height: 10),
        _SettingsGroup(
          items: [
            _SettingItem(
              icon: Icons.notifications_rounded,
              color: const Color(0xFF6366F1),
              title: 'Notification Preferences',
              subtitle: 'Manage order alerts',
              onTap: () => _showNotificationSettings(context),
            ),
            _SettingItem(
              icon: Icons.support_agent_rounded,
              color: _kAmber,
              title: 'Partner Support',
              subtitle: 'Contact campus administration',
              onTap: () => _contactSupport(context),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // ── LOGOUT ──
        GestureDetector(
          onTap: () => _handleLogout(context),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kRed.withValues(alpha: 0.25), width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: _kRed, size: 20),
                SizedBox(width: 8),
                Text('Log Out', style: TextStyle(color: _kRed, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final dynamic service;
  const _ProfileHeader({required this.service});

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
                  children: const [
                    Text('PROFILE', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    SizedBox(height: 4),
                    Text('Restaurant Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                  ],
                ),
              ),
              FutureBuilder<String>(
                future: service.getUserRole(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final raw = snapshot.data!;
                  final display = raw.isNotEmpty ? '${raw[0].toUpperCase()}${raw.substring(1)}' : 'Owner';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Text(display, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Restaurant Card (With Preview Dialog) ────────────────────
class _RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  const _RestaurantCard({required this.restaurant});

  @override
  State<_RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<_RestaurantCard> {
  bool _isUploading = false;
  String? _localLogoUrl; // Instantly shows the new image without waiting for reload

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);

    final confirm = await _showImagePreviewDialog(context, file, 'Confirm New Logo');
    if (!confirm) return;

    setState(() => _isUploading = true);

    try {
      final imageUrl = await CloudinaryService.uploadImage(file);
      
      if (imageUrl != null && mounted) {
        List<String> imagesArray = _ensureImageArrayStructure(widget.restaurant.images);
        imagesArray[0] = imageUrl; // Update Logo at index 0

        setState(() => _localLogoUrl = imageUrl);

        // Update Backend properly awaiting it to catch DB errors
        try {
          await RestaurantService().updateRestaurant(widget.restaurant.id, {'images': imagesArray});
          context.read<RestaurantBloc>().add(LoadRestaurant());

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logo updated successfully!'), backgroundColor: _kGreen),
            );
          }
        } catch (e) {
          // Revert local UI state if DB fails
          setState(() => _localLogoUrl = null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Database Error: $e'), backgroundColor: _kRed),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading logo: $e'), backgroundColor: _kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final initials = restaurant.name.length >= 2
        ? restaurant.name.substring(0, 2).toUpperCase()
        : (restaurant.name.isNotEmpty ? restaurant.name.toUpperCase() : 'RT');
    final partnerId = restaurant.id.split('-').first.toUpperCase();

    List<String> imagesArray = _ensureImageArrayStructure(restaurant.images);
    final logoUrl = _localLogoUrl ?? imagesArray[0];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // Interactive Logo Upload
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadLogo,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 85, width: 85,
                  decoration: BoxDecoration(
                    gradient: logoUrl.isEmpty ? const LinearGradient(colors: [_kBrand, _kBrandDeep]) : null,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _kBrand.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                    image: logoUrl.isNotEmpty
                        ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: logoUrl.isEmpty
                      ? Center(
                          child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 1)),
                        )
                      : null,
                ),
                if (_isUploading)
                  Container(
                    height: 85, width: 85,
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                // Camera icon badge
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _kSurface, width: 2)),
                  child: const Icon(Icons.camera_alt_rounded, color: _kBrand, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(restaurant.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kTextDark, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text('Partner ID: $partnerId',
              style: const TextStyle(color: _kGreen, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kTextMid)),
  );
}

// ─── Settings Group ───────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  final List<_SettingItem> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                const Divider(height: 1, color: Color(0xFFF5F5F5), indent: 64),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback? onTap;
  const _SettingItem({required this.icon, required this.color, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextDark)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _kTextMid, fontWeight: FontWeight.w500)),
    trailing: onTap != null
        ? Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.chevron_right_rounded, color: _kTextLight, size: 16),
          )
        : null,
  );
}

// ─── Notification Toggle ──────────────────────────────────────
class _NotifToggle extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotifToggle({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: _kTextDark, fontSize: 14)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _kTextMid, fontWeight: FontWeight.w500)),
    value: value,
    activeColor: Colors.white,
    activeTrackColor: _kBrand,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: const Color(0xFFE5E7EB),
    onChanged: onChanged,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  );
}

// ─── Upload QR Screen (With Preview Dialog) ───────────────────
class UploadQRScreen extends StatefulWidget {
  final Restaurant restaurant;
  const UploadQRScreen({super.key, required this.restaurant});

  @override
  State<UploadQRScreen> createState() => _UploadQRScreenState();
}

class _UploadQRScreenState extends State<UploadQRScreen> {
  bool _isUploading = false;
  String _qrUrl = '';

  @override
  void initState() {
    super.initState();
    List<String> imagesArray = _ensureImageArrayStructure(widget.restaurant.images);
    _qrUrl = imagesArray[1]; // Index 1 is the QR Code
  }

  Future<void> _pickAndUploadQR() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);

    final confirm = await _showImagePreviewDialog(context, file, 'Confirm New QR Code');
    if (!confirm) return;

    setState(() => _isUploading = true);

    try {
      final imageUrl = await CloudinaryService.uploadImage(file);
      
      if (imageUrl != null && mounted) {
        List<String> imagesArray = _ensureImageArrayStructure(widget.restaurant.images);
        imagesArray[1] = imageUrl;

        // Update Backend properly awaiting it
        try {
          await RestaurantService().updateRestaurant(widget.restaurant.id, {'images': imagesArray});
          context.read<RestaurantBloc>().add(LoadRestaurant());
          setState(() => _qrUrl = imageUrl);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR Code updated successfully!'), backgroundColor: _kGreen),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Database Error: $e'), backgroundColor: _kRed),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading QR: $e'), backgroundColor: _kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextDark),
        title: const Text('Payment QR Code', style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Upload your UPI QR Code so students can easily make payments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextMid, fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              // QR Display
              Container(
                height: 250, width: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: _isUploading
                    ? const Center(child: CircularProgressIndicator(color: _kBrand))
                    : _qrUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(_qrUrl, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFFE5E7EB)),
                              SizedBox(height: 12),
                              Text('No QR Code Found', style: TextStyle(color: _kTextLight, fontWeight: FontWeight.w600)),
                            ],
                          ),
              ),
              
              const SizedBox(height: 40),
              
              // Upload Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isUploading ? null : _pickAndUploadQR,
                  icon: const Icon(Icons.upload_rounded, color: Colors.white),
                  label: Text(_qrUrl.isEmpty ? 'Upload QR Code' : 'Change QR Code', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}