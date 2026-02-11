import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<int> waveformData;
  final Color color;
  final double progress;

  WaveformPainter({
    required this.waveformData,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final progressPaint =
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final backgroundPaint =
        Paint()
          // ..color = color.withOpacity(0.3)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final width = size.width / waveformData.length;
    final middle = size.height / 2;
    final progressWidth = size.width * progress;

    for (var i = 0; i < waveformData.length; i++) {
      final x = i * width;
      final amplitude = waveformData[i].toDouble();
      final height = (amplitude / 100) * (size.height / 2);

      final paint = x <= progressWidth ? progressPaint : backgroundPaint;

      canvas.drawLine(
        Offset(x, middle - height),
        Offset(x, middle + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveformData != waveformData;
  }
}
