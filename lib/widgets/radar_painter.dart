import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RadarPainter extends CustomPainter {
  final double animationValue;
  final List<Offset> peers;

  RadarPainter({required this.animationValue, required this.peers});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 1.5;

    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    for (int i = 1; i <= 4; i++) {
        canvas.drawCircle(center, maxRadius * (i / 4), paint);
    }

    // Draw scanning line
    final scanPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppTheme.primary.withOpacity(0.5),
        ],
        stops: const [0.8, 1.0],
        transform: GradientRotation(animationValue * 2 * pi - pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, scanPaint);

    // Draw peers
    final peerPaint = Paint()
      ..color = AppTheme.secondary
      ..style = PaintingStyle.fill;

    for (final peer in peers) {
        // Calculate opacity based on angular distance from scan line?
        // For now just draw them as glowing dots
        canvas.drawCircle(peer + center, 6, peerPaint..color = AppTheme.secondary);
        canvas.drawCircle(peer + center, 12, peerPaint..color = AppTheme.secondary.withOpacity(0.3));
    }
    
    // Draw Center Self
    final selfPaint = Paint()..color = AppTheme.primary;
    canvas.drawCircle(center, 8, selfPaint);
    canvas.drawCircle(center, 16, selfPaint..color = AppTheme.primary.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
