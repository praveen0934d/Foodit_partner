import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dz9wql9so';
  static const String uploadPreset = 'ke1eh3rr';
  static String toJpegUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // Only transform Cloudinary URLs — leave other URLs untouched
    if (!url.contains('res.cloudinary.com')) return url;

    // Already has a transformation — prepend format override
    if (url.contains('/upload/')) {
      // Insert f_jpg,q_auto right after /upload/
      return url.replaceFirst('/upload/', '/upload/f_jpg,q_auto/');
    }

    return url;
  }

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));

        final rawUrl = jsonMap['secure_url'] as String?;
        return toJpegUrl(rawUrl);
      } else {
        debugPrint('Cloudinary upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary Upload Error: $e');
      return null;
    }
  }
}