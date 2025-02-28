import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A custom painter that draws wavy lines in the background
class WavyBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double animationValue;

  WavyBackgroundPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw multiple wavy lines
    for (int i = 0; i < 8; i++) {
      final double offsetY = size.height * (i / 8.0);
      final double amplitude = size.height * 0.05 * (1 + (i % 3) * 0.5);
      final double frequency = (i % 2 == 0) ? 0.02 : 0.015;
      final double phase = animationValue * math.pi * 2 + (i * math.pi / 4);
      
      // Alternate colors
      paint.color = i % 2 == 0 
          ? primaryColor.withOpacity(0.3 - (i * 0.02))
          : secondaryColor.withOpacity(0.3 - (i * 0.02));

      final path = Path();
      path.moveTo(0, offsetY);

      for (double x = 0; x <= size.width; x += 1) {
        final double y = offsetY + 
            amplitude * math.sin((x * frequency) + phase);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WavyBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

/// A widget that displays animated wavy lines in the background
class WavyBackground extends StatefulWidget {
  final Widget child;
  final Color primaryColor;
  final Color secondaryColor;

  const WavyBackground({
    Key? key,
    required this.child,
    required this.primaryColor,
    required this.secondaryColor,
  }) : super(key: key);

  @override
  State<WavyBackground> createState() => _WavyBackgroundState();
}

class _WavyBackgroundState extends State<WavyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: WavyBackgroundPainter(
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            animationValue: _controller.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}
