import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class TemperatureGraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minTemp;
  final double maxTemp;
  final double tempRange;

  TemperatureGraphPainter({
    required this.data,
    required this.minTemp,
    required this.maxTemp,
    required this.tempRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.45),
          Colors.white.withOpacity(0.15),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    double effectiveMinTemp = minTemp;
    double effectiveTempRange = tempRange;

    if (tempRange < 10) {
      final midTemp = (minTemp + maxTemp) / 2;
      effectiveMinTemp = midTemp - 5;
      effectiveTempRange = 10;
    }

    final points = <Offset>[];
    final fillPath = ui.Path();
    final hourWidth = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final temp = data[i]['temp']?.toDouble() ?? 0.0;
      final x = (i * hourWidth) + (hourWidth / 2);

      final normalizedTemp = effectiveTempRange == 0
          ? 0.5
          : (temp - effectiveMinTemp) / effectiveTempRange;

      final y = size.height * (1 - normalizedTemp) * 0.8 + size.height * 0.1;

      points.add(Offset(x, y));

      if (i == 0) {
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        fillPath.lineTo(x, y);
      }
    }

    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
    }

    // Draw gradient fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw temperature line with smooth curves
    if (points.length > 1) {
      final path = ui.Path();
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        final controlPoint1 = Offset(
          points[i - 1].dx + (points[i].dx - points[i - 1].dx) / 3,
          points[i - 1].dy,
        );
        final controlPoint2 = Offset(
          points[i].dx - (points[i].dx - points[i - 1].dx) / 3,
          points[i].dy,
        );

        path.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          points[i].dx,
          points[i].dy,
        );
      }

      canvas.drawPath(path, paint);
    }

    // Draw temperature dots and labels
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final temp = data[i]['temp']?.round() ?? 0;
      
      // Draw dot
      canvas.drawCircle(point, 5.0, dotPaint);
      
      // Show temperature label
      textPainter.text = TextSpan(
        text: '$temp°',
        style: TextStyle(
          color: Colors.blueGrey.shade800,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              offset: Offset(0.8, 0.8),
              blurRadius: 2.0,
              color: Colors.white,
            ),
          ],
        ),
      );
      textPainter.layout();
      final labelOffset = Offset(
        point.dx - textPainter.width / 2,
        point.dy - textPainter.height - 8,
      );
      final labelBg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        labelBg,
        Paint()..color = Colors.black.withOpacity(0.18),
      );
      textPainter.paint(canvas, labelOffset);
    }

    // Draw horizontal grid lines
    const gridLineCount = 5;
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.35)
      ..strokeWidth = 1.0;
    for (int i = 0; i <= gridLineCount; i++) {
      final y = size.height * i / gridLineCount;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}