import 'package:flutter/material.dart';
import '../core/theme/juice_theme.dart';

class JuiceButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isGradient;
  final IconData? icon;

  const JuiceButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isGradient = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isGradient
          ? BoxDecoration(
              gradient: JuiceTheme.primaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: JuiceTheme.primaryTangerine.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            )
          : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: isGradient
            ? ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
