import 'package:flutter/material.dart';

class SquareActionButton extends StatelessWidget {
  const SquareActionButton({
    super.key,
    required this.label,
    this.icon,
    this.iconWidget,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = 150,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget ?? Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
