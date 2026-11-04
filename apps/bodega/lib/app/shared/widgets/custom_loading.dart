import 'package:flutter/material.dart';

class CustomLoading extends StatelessWidget {
  final double? value;
  final double? size;
  final Color? color;

  const CustomLoading({super.key, this.value, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final indicator = CircularProgressIndicator.adaptive(
      value: value,
      strokeWidth: 2,
      valueColor: color != null ? AlwaysStoppedAnimation<Color>(color!) : null,
    );

    if (size != null) {
      return Center(
        child: SizedBox(width: size, height: size, child: indicator),
      );
    }

    return Center(child: indicator);
  }
}
