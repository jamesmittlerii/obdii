import 'package:flutter/material.dart';

class CheckEngineIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const CheckEngineIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final IconThemeData iconTheme = IconTheme.of(context);
    final double iconSize = size ?? iconTheme.size ?? 24.0;
    final Color iconColor = color ?? iconTheme.color ?? Colors.black;

    return CustomPaint(
      size: Size(iconSize, iconSize),
      painter: _CheckEnginePainter(color: iconColor),
    );
  }
}

class _CheckEnginePainter extends CustomPainter {
  final Color color;

  _CheckEnginePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // The original path is designed for a 24x24 viewport
    final double scale = size.width / 24.0;
    
    canvas.save();
    canvas.scale(scale, scale);

    Path path = Path();
    path.moveTo(23.0, 11.0);
    path.relativeLineTo(-1.0, 0);
    path.lineTo(22.0, 9.0);
    path.relativeCubicTo(0.0, -1.1, -0.9, -2.0, -2.0, -2.0);
    path.relativeLineTo(-2.0, 0);
    path.lineTo(18.0, 5.0);
    path.relativeCubicTo(0.0, -1.1, -0.9, -2.0, -2.0, -2.0);
    path.relativeLineTo(-4.0, 0);
    path.relativeCubicTo(-1.1, 0.0, -2.0, 0.9, -2.0, 2.0);
    path.relativeLineTo(0, 2.0);
    path.relativeLineTo(-2.0, 0);
    path.relativeCubicTo(-1.1, 0.0, -2.0, 0.9, -2.0, 2.0);
    path.relativeLineTo(0, 1.0);
    path.lineTo(2.5, 10.0);
    path.cubicTo(1.67, 10.0, 1.0, 10.67, 1.0, 11.5);
    path.relativeLineTo(0, 6.0);
    path.relativeCubicTo(0.0, 0.83, 0.67, 1.5, 1.5, 1.5);
    path.lineTo(6.0, 19.0);
    path.relativeLineTo(0, 1.0);
    path.relativeCubicTo(0.0, 1.1, 0.9, 2.0, 2.0, 2.0);
    path.relativeLineTo(4.0, 0);
    path.relativeCubicTo(1.1, 0.0, 2.0, -0.9, 2.0, -2.0);
    path.relativeLineTo(0, -1.0);
    path.relativeLineTo(5.5, 0);
    path.relativeCubicTo(0.83, 0.0, 1.5, -0.67, 1.5, -1.5);
    path.relativeLineTo(0, -1.0);
    path.relativeLineTo(1.0, 0);
    path.relativeCubicTo(0.55, 0.0, 1.0, -0.45, 1.0, -1.0);
    path.relativeLineTo(0, -3.0);
    path.relativeCubicTo(0.0, -0.55, -0.45, -1.0, -1.0, -1.0);
    path.close();
    path.moveTo(18.5, 17.5);
    path.relativeCubicTo(0.0, 0.28, -0.22, 0.5, -0.5, 0.5);
    path.lineTo(5.5, 18.0);
    path.relativeCubicTo(-0.28, 0.0, -0.5, -0.22, -0.5, -0.5);
    path.relativeLineTo(0, -6.0);
    path.relativeCubicTo(0.0, -0.28, 0.22, -0.5, 0.5, -0.5);
    path.relativeLineTo(4.0, 0);
    path.relativeCubicTo(0.55, 0.0, 1.0, -0.45, 1.0, -1.0);
    path.lineTo(10.5, 9.0);
    path.relativeCubicTo(0.0, -0.55, 0.45, -1.0, 1.0, -1.0);
    path.relativeLineTo(6.0, 0);
    path.relativeCubicTo(0.55, 0.0, 1.0, 0.45, 1.0, 1.0);
    path.relativeLineTo(0, 8.5);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CheckEnginePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
