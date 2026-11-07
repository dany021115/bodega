import 'package:flutter/material.dart';

abstract class AppGradient {
  /// The brand gradient: cyan to blue to violet.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    stops: [0, 0.55, 1],
  );

  /// A two-color cover, as the one behind each app.
  static LinearGradient cover(Color a, Color b) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [a, b],
  );
}
