import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/notes.dart';

/// A horizontal cents strip, -50 .. +50, with a green window around 0 and a
/// needle that glides to the reading. A null [cents] parks the needle in the
/// middle in a muted color.
class TunerMeter extends StatelessWidget {
  const TunerMeter({super.key, required this.cents, this.height = 96});

  final double? cents;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = cents;
    final colors = context.colors;
    final Color needle;
    if (c == null) {
      needle = colors.textDisabled;
    } else if (isInTune(c)) {
      needle = colors.success;
    } else if (c.abs() < 15) {
      needle = colors.warning;
    } else {
      needle = colors.danger;
    }
    return Semantics(
      label: c == null ? 'No note' : '${c.round()} cents',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: (c ?? 0).clamp(-50.0, 50.0).toDouble()),
        duration: context.motion(UiMotion.fast),
        builder: (context, value, _) => CustomPaint(
          size: Size(double.infinity, height),
          painter: _MeterPainter(
            cents: value,
            needle: needle,
            tick: colors.borderStrong,
            label: colors.textMuted,
            zone: colors.successSoft,
            track: colors.surfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.cents,
    required this.needle,
    required this.tick,
    required this.label,
    required this.zone,
    required this.track,
  });

  final double cents;
  final Color needle;
  final Color tick;
  final Color label;
  final Color zone;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 16.0;
    final w = size.width - 2 * pad;
    double x(double c) => pad + (c + 50) / 100 * w;
    final midY = size.height * 0.55;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(pad - 8, 0, size.width - pad + 8, size.height), const Radius.circular(14)),
      Paint()..color = track,
    );
    canvas.drawRect(Rect.fromLTRB(x(-inTuneCents), 6, x(inTuneCents), size.height - 6), Paint()..color = zone);

    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 1.5;
    for (var c = -50; c <= 50; c += 10) {
      final major = c % 50 == 0 || c == 0;
      final len = major ? 22.0 : 12.0;
      canvas.drawLine(Offset(x(c.toDouble()), midY - len / 2), Offset(x(c.toDouble()), midY + len / 2), tickPaint);
    }
    for (final c in [-50, 0, 50]) {
      final tp = TextPainter(
        text: TextSpan(
          text: c > 0 ? '+$c' : '$c',
          style: TextStyle(color: label, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x(c.toDouble()) - tp.width / 2, size.height - tp.height - 6));
    }

    final nx = x(cents);
    canvas.drawLine(
      Offset(nx, 10),
      Offset(nx, midY + 22),
      Paint()
        ..color = needle
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(nx, 12), 6, Paint()..color = needle);
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.cents != cents || old.needle != needle || old.tick != tick || old.zone != zone || old.track != track;
}
