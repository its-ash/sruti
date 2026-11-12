import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/notes.dart';
import 'tuner_meter.dart';

/// The big note name, a cents meter, the frequency and a tune up / down hint.
/// With [cents] null it shows [idleTitle] and a muted meter.
class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.title,
    required this.cents,
    required this.freq,
    this.subtitle,
    this.titleStyle,
    this.idleTitle = '-',
    this.idleHint = 'Play or sing a note',
  });

  /// Main label such as `A2` or `komal Re`; null when nothing is heard.
  final String? title;
  final String? subtitle;
  final double? cents;
  final double? freq;
  final TextStyle? titleStyle;
  final String idleTitle;
  final String idleHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = cents;
    final active = title != null && c != null;
    final inTune = active && isInTune(c);
    final status = !active
        ? UiStatus.neutral
        : inTune
            ? UiStatus.success
            : c.abs() < 15
                ? UiStatus.warning
                : UiStatus.danger;
    final hint = !active
        ? idleHint
        : inTune
            ? 'In tune'
            : c < 0
                ? 'Too low: tune up'
                : 'Too high: tune down';
    return UiCard(
      padding: const EdgeInsets.all(UiSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title ?? idleTitle,
                style: (titleStyle ?? context.text.displayLarge)?.copyWith(
                  color: inTune ? colors.success : (active ? colors.text : colors.textDisabled),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (subtitle != null)
            Center(child: Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: colors.textMuted))),
          const UiGap(UiSpace.md),
          TunerMeter(cents: c),
          const UiGap(UiSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                active ? '${c > 0 ? '+' : ''}${c.toStringAsFixed(1)} cents' : '- cents',
                style: context.text.titleMedium,
              ),
              Text(freq == null ? '- Hz' : '${freq!.toStringAsFixed(1)} Hz', style: context.text.titleMedium),
            ],
          ),
          const UiGap(UiSpace.sm),
          Center(child: UiStatusPill(hint, status: status, dot: active)),
        ],
      ),
    );
  }
}
