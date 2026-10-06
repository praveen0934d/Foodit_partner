import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/restaurant/restaurant_bloc.dart';
import '../blocs/restaurant/restaurant_event.dart'; 
import '../models/restaurant_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cloudinary_service.dart';

// ─── Design tokens ──────────────────────────────────────────
const _kBrand     = Color(0xFFFF5722);
const _kBrandDeep = Color(0xFFBF360C);
const _kTextDark  = Color(0xFF1A1A2E);
const _kGreen     = Color(0xFF22C55E);

class EditRestaurantScreen extends StatefulWidget {
  final Restaurant restaurant;
  const EditRestaurantScreen({super.key, required this.restaurant});

  @override
  State<EditRestaurantScreen> createState() => _EditRestaurantScreenState();
}

class _EditRestaurantScreenState extends State<EditRestaurantScreen> with SingleTickerProviderStateMixin {
  final _nameCtrl     = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _minOrderCtrl = TextEditingController();

  bool _isSaving = false;
  late AnimationController _saveCtrl;
  late Animation<double> _saveFade;

  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text     = widget.restaurant.name;
    _descCtrl.text     = widget.restaurant.description;
    _phoneCtrl.text    = widget.restaurant.phone ?? '';
    _minOrderCtrl.text = widget.restaurant.minOrderAmount.toInt().toString();

    _saveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _saveFade = CurvedAnimation(parent: _saveCtrl, curve: Curves.easeOut);
    _saveCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _minOrderCtrl.dispose();
    _saveCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
    }
  }

  void _handleSave() async {
    if (_nameCtrl.text.isEmpty) return;
    
    // Starts the spinner
    setState(() => _isSaving = true);

    List<dynamic> imagesToSave = widget.restaurant.images ?? [];
    if (_pickedImage != null) {
      final url = await CloudinaryService.uploadImage(_pickedImage!);
      if (url != null) {
        imagesToSave = [url];
      } else {
        // If upload fails, show error and stop
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    context.read<RestaurantBloc>().add(UpdateRestaurantRequested(widget.restaurant.id, {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'min_order_amount': double.tryParse(_minOrderCtrl.text) ?? 0,
      'images': imagesToSave, 
    }));
    
    // ❌ REMOVED Navigator.pop() from here.
    // We let the BlocListener handle it below when it actually finishes!
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RestaurantBloc, RestaurantState>(
      listener: (context, state) {
        if (_isSaving) {
          if (state is RestaurantError) {
            // If backend throws an error, stop spinner and show red error bar
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
            );
          } else if (state is RestaurantLoaded) {
            // If backend succeeds, stop spinner, pop screen, and show green success bar
            setState(() => _isSaving = false);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('Profile Updated!', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                backgroundColor: _kGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          body: Column(
            children: [
              _EditHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _saveFade,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                    children: [
                      // Profile Image Picker
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(color: _kBrand.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: _pickedImage != null
                                      ? Image.file(_pickedImage!, fit: BoxFit.cover)
                                      : (widget.restaurant.images != null && widget.restaurant.images!.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: widget.restaurant.images![0].toString(),
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: _kBrand)),
                                              errorWidget: (context, url, error) => const Icon(Icons.storefront_rounded, size: 50, color: Colors.grey),
                                            )
                                          : const Icon(Icons.add_a_photo_rounded, size: 40, color: _kBrand),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _kBrand,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _EditField(
                        label: 'Restaurant Name',
                        icon: Icons.storefront_rounded,
                        controller: _nameCtrl,
                        color: _kBrand,
                      ),
                      const SizedBox(height: 16),
                      _EditField(
                        label: 'Description',
                        icon: Icons.description_rounded,
                        controller: _descCtrl,
                        color: const Color(0xFF6366F1),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _EditField(
                        label: 'Contact Phone',
                        icon: Icons.phone_rounded,
                        controller: _phoneCtrl,
                        color: _kGreen,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _EditField(
                        label: 'Minimum Order Amount (₹)',
                        icon: Icons.currency_rupee_rounded,
                        controller: _minOrderCtrl,
                        color: const Color(0xFFF59E0B),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 36),

                      // Save Button
                      GestureDetector(
                        onTap: _isSaving ? null : _handleSave,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isSaving
                                  ? [Colors.grey.shade300, Colors.grey.shade400]
                                  : [_kBrand, _kBrandDeep],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: _isSaving ? [] : [
                              BoxShadow(color: _kBrand.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Edit Header ─────────────────────────────────────────────
class _EditHeader extends StatelessWidget {
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
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SETTINGS', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    SizedBox(height: 4),
                    Text('Edit Restaurant', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Edit Field ───────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final Color color;
  final int maxLines;
  final TextInputType keyboardType;

  const _EditField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.color,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kTextDark, letterSpacing: 0.1)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _kTextDark, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}