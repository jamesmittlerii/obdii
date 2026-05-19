// Port of RingGaugeView.swift — Jim Mittler
// Custom arc gauge painter matching the Swift ring gauge:
//   - 240° sweep from ~8-o'clock (300° / 5π/3 radians)
//   - Grey background track + colored progress arc
//   - Rounded stroke caps
//   - Value on first line, unit on second line, centered in arc
//   - Label text below the arc rendered by the parent tile

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/obd_connection_manager.dart';
import '../core/obdiipid.dart';

// ─────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────

class RingGaugeWidget extends StatelessWidget {
  final ObdiiPid pid;
  final PIDStats? stats;
  final bool isMetric;

  const RingGaugeWidget({
    super.key,
    required this.pid,
    required this.stats,
    required this.isMetric,
  });

  @override
  Widget build(BuildContext context) {
    final combinedRange = _combinedRange();
    final minV = combinedRange.min;
    final maxV = combinedRange.max;

    double? currentValue;
    Color progressColor = Colors.blueGrey;
    String valueLine = '—';
    String unitLine = pid.unitLabel(isMetric);

    if (stats != null) {
      final v = stats!.latest.value;
      currentValue = v;
      progressColor = pid.colorForValue(v, isMetric);
      valueLine = pid.formattedValue(v, isMetric, includeUnits: false);
    }

    double normalized = 0.0;
    if (currentValue != null) {
      final range = maxV == minV ? 1.0 : maxV - minV;
      normalized = ((currentValue - minV) / range).clamp(0.0, 1.0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Match Swift approach: width is the master dimension so reducing
        // effective height crops open-arc whitespace instead of shrinking gauge.
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0;
        final dim = width;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: dim,
              height: dim,
              child: CustomPaint(
                painter: _RingGaugePainter(
                  normalized: normalized,
                  progressColor: progressColor,
                ),
                child: Align(
                  // Downward nudge to visually center value+unit in the ring.
                  alignment: const Alignment(0, 0.30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valueLine,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      if (unitLine.isNotEmpty && unitLine.toLowerCase() != pid.label.toLowerCase())
                        Text(
                          unitLine,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            height: 1.0,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  

  ValueRange _combinedRange() {
    final ranges = [
      pid.typicalRangeFor(isMetric),
      pid.warningRangeFor(isMetric),
      pid.dangerRangeFor(isMetric),
    ].whereType<ValueRange>().toList();
    if (ranges.isEmpty) return const ValueRange(min: 0, max: 1);
    final minV = ranges.map((r) => r.min).reduce(math.min);
    final maxV = ranges.map((r) => r.max).reduce(math.max);
    return ValueRange(min: minV, max: maxV);
  }
}

// ─────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────

class _RingGaugePainter extends CustomPainter {
  final double normalized; // 0.0 – 1.0
  final Color progressColor;

  // Arc geometry matching RingGaugeView.swift:
  //   startAngle = 5π/6 rad  (~150° in Flutter's 3-o'clock-origin system = ~8-o'clock)
  //   sweepAngle = 4π/3 rad  (240°)
  static const double _startAngle = 5 * math.pi / 6;
  static const double _totalSweep = 4 * math.pi / 3;

  _RingGaugePainter({required this.normalized, required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Width drives geometry to avoid shrinkage when parent height is cropped.
    final dim = size.width;
    final center = Offset(dim / 2, dim / 2);
    final strokeWidth = math.max(4.0, dim * 0.18);
    final radius = (dim / 2) - strokeWidth / 2;

    final trackPaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw grey track
    canvas.drawArc(rect, _startAngle, _totalSweep, false, trackPaint);

    // Draw progress arc
    if (normalized > 0) {
      canvas.drawArc(rect, _startAngle, _totalSweep * normalized, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_RingGaugePainter old) =>
      old.normalized != normalized || old.progressColor != progressColor;
}
