import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'platform/audio_channel.dart';
import 'screens/home_screen.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(SrutiApp(settings: settings, audio: const PlatformAudioChannel()));
}

class SrutiApp extends StatelessWidget {
  const SrutiApp({super.key, required this.settings, required this.audio});

  final SettingsStore settings;
  final AudioChannel audio;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'Sruti',
      home: HomeScreen(audio: audio, settings: settings),
    );
  }
}
