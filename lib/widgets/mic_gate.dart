import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../audio/tuner_controller.dart';

/// Shows [builder] while the microphone is listening, and otherwise a message
/// that explains why it is not (and how to fix it).
class MicGate extends StatelessWidget {
  const MicGate({super.key, required this.tuner, required this.builder});

  final TunerController tuner;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tuner,
      builder: (context, _) {
        switch (tuner.state) {
          case TunerState.running:
            return builder(context);
          case TunerState.idle:
          case TunerState.starting:
            return const Padding(padding: EdgeInsets.symmetric(vertical: UiSpace.xxxl), child: Center(child: UiSpinner()));
          case TunerState.denied:
            return UiEmptyState(
              icon: Icons.mic_off_rounded,
              title: 'Microphone needed',
              message: 'Sruti listens to your instrument or voice to show the pitch. Nothing is recorded or sent anywhere.',
              action: UiButton('Allow microphone', icon: Icons.mic_rounded, onPressed: tuner.start),
            );
          case TunerState.deniedForever:
            return UiEmptyState(
              icon: Icons.mic_off_rounded,
              title: 'Microphone is blocked',
              message: 'Allow the microphone for Sruti in the phone settings. Nothing is recorded or sent anywhere.',
              action: UiButton('Open settings', icon: Icons.settings_rounded, onPressed: tuner.openSettings),
            );
          case TunerState.unavailable:
            return UiEmptyState(
              icon: Icons.mic_off_rounded,
              title: 'Microphone not available',
              message: 'The microphone could not be opened. Close other apps that use it and try again.',
              action: UiButton('Try again', icon: Icons.refresh_rounded, onPressed: tuner.start),
            );
        }
      },
    );
  }
}
