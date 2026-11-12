import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:theme/theme.dart';

import '../audio/drone_controller.dart';
import '../audio/tuner_controller.dart';
import '../platform/audio_channel.dart';
import '../settings/settings_store.dart';
import 'chromatic_screen.dart';
import 'drone_screen.dart';
import 'guitar_screen.dart';
import 'settings_screen.dart';
import 'swara_screen.dart';

/// Four tabs in a bottom navigation shell: Guitar, Chromatic, Swara, Drone.
/// The three tuner tabs share one microphone stream (`TunerController`), which
/// runs only while a tuner tab is open and the app is in front. The drone
/// keeps playing in the background.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.audio, required this.settings, this.requestMic});

  final AudioChannel audio;
  final SettingsStore settings;

  /// Replaces the microphone permission request (tests).
  final Future<PermissionStatus> Function()? requestMic;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _items = [
    UiNavItem(Icons.music_note_outlined, 'Guitar', selectedIcon: Icons.music_note_rounded),
    UiNavItem(Icons.tune_rounded, 'Chromatic'),
    UiNavItem(Icons.graphic_eq_rounded, 'Swara'),
    UiNavItem(Icons.spatial_audio_off_outlined, 'Drone', selectedIcon: Icons.spatial_audio_off_rounded),
  ];

  late final TunerController _tuner = TunerController(audio: widget.audio, requestPermission: widget.requestMic);
  late final DroneController _drone = DroneController(audio: widget.audio, settings: widget.settings);

  int _tab = 0;
  bool _foreground = true;

  bool get _tunerTab => _tab < 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.audio.keepScreenOn(true);
    _syncMic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.keepScreenOn(false);
    _tuner.dispose();
    _drone.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _foreground = false;
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
    } else {
      return;
    }
    _syncMic();
  }

  void _syncMic() {
    if (_tunerTab && _foreground) {
      _tuner.start();
    } else {
      _tuner.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return UiShell(
      items: _items,
      index: _tab,
      onChanged: (i) {
        setState(() => _tab = i);
        _syncMic();
      },
      appBar: UiAppBar(
        title: _items[_tab].label,
        actions: [
          UiIconButton(
            Icons.settings_rounded,
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: settings)),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          GuitarScreen(tuner: _tuner, settings: settings),
          ChromaticScreen(tuner: _tuner, settings: settings),
          SwaraScreen(tuner: _tuner, settings: settings),
          DroneScreen(drone: _drone, settings: settings),
        ],
      ),
    );
  }
}
