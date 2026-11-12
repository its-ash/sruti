import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/drone.dart';
import '../platform/audio_channel.dart';
import '../settings/settings_store.dart';

/// Renders the drone (in a background isolate) and plays it through the
/// native looped player. It re-renders when Sa, the A4 reference, the pattern
/// or the tempo change while playing; the volume changes at once.
///
/// The drone plays while the app process is alive, including when the screen
/// is off or another app is in front. There is no foreground service, so
/// Android may stop it if it kills the app in the background.
class DroneController extends ChangeNotifier {
  DroneController({required this.audio, required this.settings}) {
    _last = _key();
    settings.addListener(_onSettings);
  }

  final AudioChannel audio;
  final SettingsStore settings;

  bool playing = false;
  bool rendering = false;

  late String _last;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  String _key() => '${settings.saFreq.toStringAsFixed(3)}|${settings.dronePattern.name}|${settings.droneBpm.round()}';

  Future<void> start() async {
    playing = true;
    notifyListeners();
    await _render();
  }

  Future<void> stop() async {
    playing = false;
    rendering = false;
    _generation++;
    _debounce?.cancel();
    await audio.stopDrone();
    if (!_disposed) notifyListeners();
  }

  Future<void> toggle() => playing ? stop() : start();

  void _onSettings() {
    audio.setDroneVolume(settings.droneVolume);
    final key = _key();
    if (key == _last) return;
    _last = key;
    if (!playing) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _render);
  }

  Future<void> _render() async {
    final gen = ++_generation;
    rendering = true;
    notifyListeners();
    final sa = settings.saFreq;
    final pattern = settings.dronePattern;
    final bpm = settings.droneBpm;
    try {
      final pcm = await Isolate.run(() => toPcm16(renderDrone(saFreq: sa, pattern: pattern, bpm: bpm)));
      if (_disposed || gen != _generation || !playing) return;
      await audio.setDroneVolume(settings.droneVolume);
      await audio.playDrone(pcm, droneSampleRate);
    } finally {
      if (gen == _generation) {
        rendering = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    settings.removeListener(_onSettings);
    audio.stopDrone();
    super.dispose();
  }
}
