import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../audio/tuner_controller.dart';
import '../core/swara.dart';
import '../settings/settings_store.dart';
import '../widgets/mic_gate.dart';
import '../widgets/reading_card.dart';
import '../widgets/sa_picker.dart';

/// Indian classical mode: the swara you sing or play relative to your Sa.
class SwaraScreen extends StatelessWidget {
  const SwaraScreen({super.key, required this.tuner, required this.settings});

  final TunerController tuner;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tuner, settings]),
      builder: (context, _) {
        final deva = settings.devanagari;
        final f = tuner.freq;
        final reading = f == null ? null : swaraForFreq(f, settings.saFreq, just: settings.justIntonation);
        final swara = reading?.swara;
        final saptak = reading?.saptak;
        return ListView(
          padding: const EdgeInsets.all(UiSpace.page),
          children: [
            SaPicker(settings: settings),
            const UiGap(UiSpace.md),
            UiListGroup(
              children: [
                UiSwitchTile(
                  'Devanagari names',
                  subtitle: 'सा रे ग म प ध नि',
                  icon: Icons.translate_rounded,
                  value: deva,
                  onChanged: settings.setDevanagari,
                ),
                UiSwitchTile(
                  'Just intonation',
                  subtitle: 'Judge swaras against pure ratios (3/2 for Pa, 5/4 for Ga) instead of equal temperament',
                  icon: Icons.straighten_rounded,
                  value: settings.justIntonation,
                  onChanged: settings.setJustIntonation,
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            MicGate(
              tuner: tuner,
              builder: (context) => ReadingCard(
                title: swara?.label(devanagariScript: deva),
                idleTitle: deva ? 'सा' : 'Sa',
                idleHint: 'Sing or play a note',
                subtitle: saptak == null
                    ? null
                    : '${deva ? saptak.devanagari : saptak.roman} saptak · ${reading!.targetFreq.toStringAsFixed(1)} Hz target',
                cents: reading?.cents,
                freq: f,
                titleStyle: context.text.displayMedium,
              ),
            ),
            const UiGap(UiSpace.md),
            _Ladder(current: swara?.degree, deva: deva),
          ],
        );
      },
    );
  }
}

/// The 12 swarasthanas as a row of cells; the one heard is highlighted.
class _Ladder extends StatelessWidget {
  const _Ladder({required this.current, required this.deva});

  final int? current;
  final bool deva;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: UiSpace.xs,
      runSpacing: UiSpace.xs,
      alignment: WrapAlignment.center,
      children: [
        for (final s in swaras)
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: UiSpace.sm),
            decoration: BoxDecoration(
              color: s.degree == current ? colors.accent : colors.surfaceMuted,
              borderRadius: UiRadius.all(UiRadius.sm),
            ),
            child: Column(
              children: [
                Text(
                  deva ? s.devanagari : s.short,
                  style: context.text.labelLarge?.copyWith(color: s.degree == current ? colors.onAccent : colors.text),
                ),
                Text(
                  s.variant == SwaraVariant.komal
                      ? (deva ? 'कोमल' : 'komal')
                      : s.variant == SwaraVariant.tivra
                          ? (deva ? 'तीव्र' : 'tivra')
                          : '',
                  style: context.text.labelSmall?.copyWith(
                    color: s.degree == current ? colors.onAccent : colors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
