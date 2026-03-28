import 'dart:convert';
import 'package:flutter/material.dart';

class ImageUtils {
  static ImageProvider? getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;

    // Handle Base64 strings
    if (url.startsWith('data:image') || url.length > 500) {
      try {
        final String base64Str = url.contains(',') ? url.split(',').last : url;
        return MemoryImage(base64Decode(base64Str.trim()));
      } catch (e) {
        debugPrint("Error decoding Base64 avatar: $e");
        return null;
      }
    }

    // Handle Network URLs
    return NetworkImage(url);
  }
}
