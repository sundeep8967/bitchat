import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../viewmodels/onboarding_viewmodel.dart';
import '../viewmodels/base_viewmodel.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late AnimationController _globeController;

  @override
  void initState() {
    super.initState();
    _globeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _globeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    Color(0xFF2E3A59), // Deep Blue-Grey
                    Color(0xFF0F1218), // Nearly Black
                  ],
                ),
              ),
            ),
          ),

          // 2. 3D Wireframe Globe Animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _globeController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _GlobePainter(
                    rotation: _globeController.value * 2 * math.pi,
                  ),
                );
              },
            ),
          ),

          // 3. Floating Glass UI Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                // Hero Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.public, 
                        color: Colors.white, 
                        size: 48
                      ).animate().fadeIn().scale(delay: 200.ms),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to\nthe Mesh.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1,
                          height: 1.1,
                          shadows: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0),
                      const SizedBox(height: 16),
                      Text(
                        'Decentralized communication.\nNo servers. No internet required.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 500.ms, duration: 800.ms),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Action Area
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Consumer<OnboardingViewModel>(
                    builder: (context, model, child) {
                      return Column(
                        children: [
                          _buildGlassButton(
                            text: model.state == ViewState.busy ? 'Connecting...' : 'Enter Mesh',
                            onPressed: () async {
                              await model.enterMesh();
                              if (context.mounted) {
                                Navigator.of(context).pushReplacement(
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                    transitionDuration: const Duration(milliseconds: 800),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Powered by BitChat Protocol v1.0',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ).animate().fadeIn(delay: 1000.ms).slideY(begin: 1, end: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required String text, required VoidCallback onPressed}) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 3D Wireframe Globe Painter
class _GlobePainter extends CustomPainter {
  final double rotation;

  _GlobePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.6); // Slightly lower center
    final radius = size.width * 0.8;
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final dotPaint = Paint()
      ..color = Colors.blue.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    // Draw Longitude Lines (Vertical ellipses)
    for (int i = 0; i < 12; i++) {
        double angle = (i * math.pi / 6) + rotation;
        // Project 3D circle to 2D ellipse based on rotation
        // Simple projection: x = r * cos(angle), width varies by sin(angle)
        
        // Simpler wireframe: Draw ellipses with varying widths
        double widthFactor = math.cos(angle);
        canvas.drawOval(
          Rect.fromCenter(center: center, width: radius * 2 * widthFactor, height: radius * 2),
          paint,
        );
        
        // Draw dots at intersections (Equator)
        if (widthFactor.abs() > 0.1) { // Don't draw on edge
            double x = center.dx + radius * widthFactor;
            double y = center.dy;
            canvas.drawCircle(Offset(x, y), 3, dotPaint);
            
             // Create a "network" effect by connecting some dots
             if (i % 2 == 0) {
                 double nextAngle = ((i + 1) * math.pi / 6) + rotation;
                 double nextX = center.dx + radius * math.cos(nextAngle);
                 canvas.drawLine(Offset(x, y), Offset(nextX, y), paint..color = Colors.blue.withOpacity(0.2));
             }
        }
    }

    // Draw Latitude Lines (Horizontal ellipses)
    for (int i = 1; i < 5; i++) {
       double latRadius = radius * math.sin(i * math.pi / 6);
       double heightOffset = radius * math.cos(i * math.pi / 6);
       
       canvas.drawOval(
          Rect.fromCenter(center: Offset(center.dx, center.dy - heightOffset), width: latRadius * 2, height: latRadius * 0.4),
          paint,
       );
       canvas.drawOval(
          Rect.fromCenter(center: Offset(center.dx, center.dy + heightOffset), width: latRadius * 2, height: latRadius * 0.4),
          paint,
       );
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) => oldDelegate.rotation != rotation;
}
