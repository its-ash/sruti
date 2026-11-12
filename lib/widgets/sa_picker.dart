import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/notes.dart';
import '../core/swara.dart';
import '../settings/settings_store.dart';

/// Picks Sa: the note (with its harmonium Kali / Safed number), the octave
/// and a fine tune of up to 50 cents either way.
class SaPicker extends StatelessWidget {
  const SaPicker({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final sa = settings.sa;
    final fine = sa.fineCents;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your Sa', style: context.text.titleMedium),
          const UiGap(UiSpace.sm),
          UiSelect<int>(
            label: 'Note',
            value: sa.pitchClass,
            sheetTitle: 'Sa note',
            options: [
              for (var i = 0; i < 12; i++) UiOption(i, '${noteNames[i]}  (${kaliSafedName(i)})'),
            ],
            onChanged: (v) => settings.setSa(sa.copyWith(pitchClass: v)),
          ),
          const UiGap(UiSpace.md),
          UiSegmentedControl<int>(
            const [UiSegment(2, label: 'Octave 2'), UiSegment(3, label: 'Octave 3'), UiSegment(4, label: 'Octave 4')],
            value: sa.octave,
            expand: true,
            onChanged: (v) => settings.setSa(sa.copyWith(octave: v)),
          ),
          const UiGap(UiSpace.md),
          UiSlider(
            value: fine,
            min: -50,
            max: 50,
            divisions: 100,
            label: 'Fine tune',
            format: (v) => '${v > 0 ? '+' : ''}${v.round()} cents',
            onChanged: (v) => settings.setSa(sa.copyWith(fineCents: v)),
          ),
          Text(
            'Sa = ${sa.label} · ${settings.saFreq.toStringAsFixed(1)} Hz · Kali = black key, Safed = white key',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
