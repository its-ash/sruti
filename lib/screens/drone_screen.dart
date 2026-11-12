import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../audio/drone_controller.dart';
import '../core/drone.dart';
import '../settings/settings_store.dart';
import '../widgets/sa_picker.dart';

/// Tanpura and sruti box, tuned to the chosen Sa.
class DroneScreen extends StatelessWidget {
  const DroneScreen({super.key, required this.drone, required this.settings});

  final DroneController drone;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([drone, settings]),
      builder: (context, _) {
        final deva = settings.devanagari;
        final pattern = settings.dronePattern;
        return ListView(
          padding: const EdgeInsets.all(UiSpace.page),
          children: [
            SaPicker(settings: settings),
            const UiGap(UiSpace.md),
            UiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Pattern', style: context.text.titleMedium),
                  const UiGap(UiSpace.sm),
                  UiChoiceChips<DronePattern>(
                    options: [
                      for (final p in DronePattern.values) UiChoice(p, deva ? p.devanagari : p.label),
                    ],
                    value: pattern,
                    onChanged: settings.setDronePattern,
                  ),
                  const UiGap(UiSpace.md),
                  UiSlider(
                    value: settings.droneBpm,
                    min: minDroneBpm,
                    max: maxDroneBpm,
                    divisions: (maxDroneBpm - minDroneBpm).round(),
                    label: 'Tempo',
                    format: (v) => '${v.round()} plucks/min',
                    onChanged: pattern.isTanpura ? settings.setDroneBpm : null,
                  ),
                  UiSlider(
                    value: settings.droneVolume,
                    label: 'Volume',
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: settings.setDroneVolume,
                  ),
                ],
              ),
            ),
            const UiGap(UiSpace.lg),
            UiButton(
              drone.playing ? 'Stop drone' : 'Start drone',
              icon: drone.playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: UiSize.lg,
              expand: true,
              loading: drone.rendering && !drone.playing,
              variant: drone.playing ? UiButtonVariant.danger : UiButtonVariant.primary,
              onPressed: drone.toggle,
            ),
            const UiGap(UiSpace.md),
            Text(
              drone.rendering
                  ? 'Preparing the sound...'
                  : 'Synthesized on your phone, tuned to your Sa. It keeps playing with the screen off or '
                      'another app open, and stops when you close Sruti.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}
