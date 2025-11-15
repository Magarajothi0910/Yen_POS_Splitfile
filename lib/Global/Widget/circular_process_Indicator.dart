// ignore: file_names
import 'dart:math';

import 'package:flutter/material.dart';

class CircularLoadingIndicator extends StatefulWidget {
  const CircularLoadingIndicator({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _CircularLoadingIndicatorState createState() =>
      _CircularLoadingIndicatorState();
}

class _CircularLoadingIndicatorState extends State<CircularLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Loop animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: LoadingPainter(_controller.value),
            size: const Size(100, 100), // Set size of loader
          );
        },
      ),
    );
  }
}

class LoadingPainter extends CustomPainter {
  final double progress;
  LoadingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    const int numDots = 12; // Number of dots in the animation
    final double radius = size.width / 2;
    final double dotRadius = 6;

    for (int i = 0; i < numDots; i++) {
      double angle = (i / numDots) * 2 * pi;
      double opacity = (i / numDots + progress) % 1.0;
      double scale = 1.0 + (0.3 * sin(opacity * pi));

      final Offset dotPosition = Offset(
        radius + cos(angle) * (radius - dotRadius * 2),
        radius + sin(angle) * (radius - dotRadius * 2),
      );

      canvas.drawCircle(
        dotPosition,
        dotRadius * scale,
        paint..color = Colors.blue.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(LoadingPainter oldDelegate) => true;
}
