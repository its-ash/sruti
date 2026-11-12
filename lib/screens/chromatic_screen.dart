import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../audio/tuner_controller.dart';
import '../core/notes.dart';
import '../settings/settings_store.dart';
import '../widgets/mic_gate.dart';
import '../widgets/reading_card.dart';

/// Any note, octave and cents, from 30 Hz to 2 kHz.
class ChromaticScreen extends StatelessWidget {
  const ChromaticScreen({super.key, required this.tuner, required this.settings});

  final TunerController tuner;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tuner, settings]),
      builder: (context, _) {
        final f = tuner.freq;
        final note = f == null ? null : NoteReading.fromFreq(f, refA: settings.refA);
        return ListView(
          padding: const EdgeInsets.all(UiSpace.page),
          children: [
            MicGate(
              tuner: tuner,
              builder: (context) => ReadingCard(
                title: note?.label,
                subtitle: note == null ? null : '${note.targetFreq.toStringAsFixed(1)} Hz target',
                cents: note?.cents,
                freq: f,
              ),
            ),
            const UiGap(UiSpace.md),
            Text(
              'A4 = ${settings.refA.toStringAsFixed(settings.refA == settings.refA.roundToDouble() ? 0 : 1)} Hz. Change it in Settings.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}
