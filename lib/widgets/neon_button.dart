import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isSecondary;

  const NeonButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (!isSecondary)
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: !isSecondary ? AppTheme.instagramGradient : null,
              border: isSecondary
                  ? Border.all(color: AppTheme.primary.withOpacity(0.5))
                  : null,
              color: isSecondary ? Colors.transparent : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text.toUpperCase(),
                  style: AppTheme.darkTheme.textTheme.labelLarge?.copyWith(
                    color: isSecondary ? AppTheme.primary : Colors.black,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
  }
}
