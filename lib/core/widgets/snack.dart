import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Snack {
  static void error(String message) => _show(message, const Color(0xFFB3261E), Icons.error_outline);
  static void success(String message) => _show(message, const Color(0xFF1B7F4B), Icons.check_circle_outline);
  static void info(String message) => _show(message, const Color(0xFF374151), Icons.info_outline);

  static void _show(String message, Color color, IconData icon) {
    Get.closeCurrentSnackbar();
    Get.rawSnackbar(
      messageText: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      icon: Icon(icon, color: Colors.white),
      backgroundColor: color,
      borderRadius: 12,
      margin: const EdgeInsets.all(12),
      maxWidth: 520,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }
}
