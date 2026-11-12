import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../audio/tuner_controller.dart';
import '../core/tunings.dart';
import '../settings/settings_store.dart';
import '../widgets/mic_gate.dart';
import '../widgets/reading_card.dart';

/// Guitar, bass and ukulele tuner. Picks the nearest string by itself, or
/// locks onto the string you tap.
class GuitarScreen extends StatefulWidget {
  const GuitarScreen({super.key, required this.tuner, required this.settings});

  final TunerController tuner;
  final SettingsStore settings;

  @override
  State<GuitarScreen> createState() => _GuitarScreenState();
}

class _GuitarScreenState extends State<GuitarScreen> {
  /// Locked string index, or -1 for automatic.
  int _lock = -1;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.tuner, settings]),
      builder: (context, _) {
        final tuning = tuningById(settings.tuningId);
        final lock = _lock < tuning.strings.length ? _lock : -1;
        final freq = widget.tuner.freq;
        int? index;
        double? cents;
        if (freq != null) {
          index = lock >= 0 ? lock : tuning.nearestString(freq, settings.refA);
          cents = tuning.centsFromString(freq, index, settings.refA);
        }
        final target = index == null ? null : tuning.strings[index];
        return ListView(
          padding: const EdgeInsets.all(UiSpace.page),
          children: [
            UiSelect<String>(
              label: 'Tuning',
              value: tuning.id,
              sheetTitle: 'Tuning',
              options: [
                for (final t in tunings) UiOption(t.id, '${t.instrument}: ${t.name}', subtitle: t.notes),
              ],
              onChanged: (v) {
                setState(() => _lock = -1);
                settings.setTuning(v);
              },
            ),
            const UiGap(UiSpace.md),
            UiChoiceChips<int>(
              options: [
                const UiChoice(-1, 'Auto'),
                for (var i = 0; i < tuning.strings.length; i++) UiChoice(i, tuning.strings[i].label),
              ],
              value: lock,
              onChanged: (v) => setState(() => _lock = v),
            ),
            const UiGap(UiSpace.lg),
            MicGate(
              tuner: widget.tuner,
              builder: (context) => ReadingCard(
                title: target?.label,
                subtitle: target == null ? null : 'String ${index! + 1} · ${target.freq(settings.refA).toStringAsFixed(1)} Hz target',
                cents: cents,
                freq: freq,
                idleHint: lock >= 0 ? 'Pluck ${tuning.strings[lock].label}' : 'Pluck a string',
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
