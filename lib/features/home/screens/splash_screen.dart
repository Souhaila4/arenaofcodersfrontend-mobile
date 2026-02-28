import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:arena/core/theme/app_theme.dart';

import 'package:arena/core/services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _fadeAnim;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.5, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _floatAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    
    // Auto-login check
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await StorageService().isLoggedIn();
    if (isLoggedIn && mounted) {
      // If logged in, wait a bit for splash effect then go to home
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF0EA5E9),
              Color(0xFF1E3A5F),
              Color(0xFF020617),
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Dot pattern overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _DotPatternPainter(),
              ),
            ),
            // Bottom glow
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primary.withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Main content
            FadeTransition(
              opacity: _fadeAnim,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(),
                      // Logo with glow
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: child,
                          );
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow behind
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (context, child) {
                                return Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withAlpha((_pulseAnim.value * 80).round()),
                                        blurRadius: 50,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Shield icon container
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withAlpha(25),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(130),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Stack(
                                  children: [
                                    // Subtle gradient overlay
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withAlpha(13),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Shield SVG equivalent
                                    Center(
                                      child: CustomPaint(
                                        size: const Size(80, 80),
                                        painter: _ShieldPainter(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Title
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w900,
                            fontSize: 30,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Arena Of ',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'Coders',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PLAY. COMPETE. WIN.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          color: const Color(0xFF7DD3FC).withAlpha(200),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Show your skills and rise to the top',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const Spacer(),
                      // Get Started button
                      _buildGetStartedButton(context),
                      const SizedBox(height: 32),
                      // Trusted by
                      Text(
                        'TRUSTED BY TOP INSTITUTIONS',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Esprit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withAlpha(130),
                            ),
                          ),
                          _buildDot(),
                          Text(
                            'Tek-Up',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withAlpha(130),
                            ),
                          ),
                          _buildDot(),
                          Text(
                            'INSAT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withAlpha(130),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (_isLoading) return;
            setState(() => _isLoading = true);
            
            final isLoggedIn = await StorageService().isLoggedIn();
            if (!context.mounted) return;
            
            setState(() => _isLoading = false);
            if (isLoggedIn) {
              Navigator.of(context).pushReplacementNamed('/home');
            } else {
              Navigator.of(context).pushReplacementNamed('/signin');
            }
          },
          borderRadius: BorderRadius.circular(50),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(80),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  else ...[
                    const Text(
                      'Get Started',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the shield + crosshair icon
class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Shield outline
    final shieldPaint = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(cx, size.height * 0.08);
    path.lineTo(size.width * 0.12, size.height * 0.3);
    path.lineTo(size.width * 0.12, size.height * 0.55);
    path.quadraticBezierTo(cx, size.height * 0.98, cx, size.height * 0.98);
    path.quadraticBezierTo(size.width * 0.88, size.height * 0.75, size.width * 0.88, size.height * 0.55);
    path.lineTo(size.width * 0.88, size.height * 0.3);
    path.close();
    canvas.drawPath(path, shieldPaint);

    // Center divider (dashed orange)
    final orangePaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashLength = 4.0;
    const gapLength = 4.0;
    double y = size.height * 0.08;
    while (y < size.height * 0.98) {
      canvas.drawLine(
        Offset(cx, y),
        Offset(cx, math.min(y + dashLength, size.height * 0.98)),
        orangePaint,
      );
      y += dashLength + gapLength;
    }

    // Center circle
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 12, circlePaint);

    // Crosshair lines
    final crosshairBlue = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final crosshairOrange = Paint()
      ..color = const Color(0xFFF97316)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final crosshairWhite = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Left (blue)
    canvas.drawLine(Offset(cx - 20, cy), Offset(cx - 12, cy), crosshairBlue);
    // Right (orange)
    canvas.drawLine(Offset(cx + 12, cy), Offset(cx + 20, cy), crosshairOrange);
    // Top (white)
    canvas.drawLine(Offset(cx, cy - 20), Offset(cx, cy - 12), crosshairWhite);
    // Bottom (white)
    canvas.drawLine(Offset(cx, cy + 12), Offset(cx, cy + 20), crosshairWhite);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws a subtle dot pattern background
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..style = PaintingStyle.fill;

    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
