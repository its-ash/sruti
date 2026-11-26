import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/pitch_detector.dart';
import '../platform/audio_channel.dart';

enum TunerState { idle, starting, running, denied, deniedForever, unavailable }

/// Microphone to pitch: reads PCM from [AudioChannel], keeps a sliding
/// window, runs the YIN detector every [analyzeEvery] chunks and smooths the
/// result with a [PitchTracker]. One instance serves all tuner tabs.
class TunerController extends ChangeNotifier {
  TunerController({
    required this.audio,
    Future<PermissionStatus> Function()? requestPermission,
    this.analyzeEvery = 2,
  })  : _requestPermission = requestPermission ?? (() => Permission.microphone.request()),
        _detector = PitchDetector(sampleRate: AudioChannel.micSampleRate) {
    _window = Float64List(_detector.bufferSize);
  }

  final AudioChannel audio;
  final int analyzeEvery;
  final Future<PermissionStatus> Function() _requestPermission;
  final PitchDetector _detector;
  final PitchTracker _tracker = PitchTracker();
  late final Float64List _window;

  StreamSubscription<Uint8List>? _sub;
  int _chunks = 0;
  int _filled = 0;
  int _gen = 0;
  bool _disposed = false;

  TunerState state = TunerState.idle;

  /// Smoothed pitch in Hz, or null when nothing is playing.
  double? freq;

  /// Latest signal level, 0..1.
  double level = 0;

  bool get running => state == TunerState.running;

  /// Asks for the microphone and starts listening. Safe to call repeatedly.
  Future<void> start() async {
    if (_sub != null || state == TunerState.starting) return;
    final gen = ++_gen;
    _set(TunerState.starting);
    final status = await _requestPermission();
    if (_disposed || gen != _gen || state != TunerState.starting) return;
    if (!status.isGranted) {
      _set(status.isPermanentlyDenied ? TunerState.deniedForever : TunerState.denied);
      return;
    }
    _tracker.reset();
    _filled = 0;
    _chunks = 0;
    _sub = audio.micChunks().listen(_onChunk, onError: (Object e) {
      _sub?.cancel();
      _sub = null;
      _set(e is MicUnavailable && e.permissionDenied ? TunerState.denied : TunerState.unavailable);
    });
    _set(TunerState.running);
  }

  /// Releases the microphone.
  void stop() {
    _gen++;
    _sub?.cancel();
    _sub = null;
    if (state == TunerState.running || state == TunerState.starting) state = TunerState.idle;
    freq = null;
    level = 0;
    _tracker.reset();
    if (!_disposed) notifyListeners();
  }

  /// Opens the system settings page of the app (after a permanent denial).
  Future<void> openSettings() => openAppSettings();

  void _onChunk(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    if (n == 0 || n >= _window.length) return;
    _window.setRange(0, _window.length - n, _window, n);
    final base = _window.length - n;
    for (var i = 0; i < n; i++) {
      _window[base + i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    _filled = (_filled + n).clamp(0, _window.length);
    if (++_chunks % analyzeEvery != 0 || _filled < _window.length) return;

    final result = _detector.detect(_window);
    level = result?.rms ?? _rms(n);
    freq = _tracker.update(result);
    if (!_disposed) notifyListeners();
  }

  double _rms(int n) {
    var e = 0.0;
    for (var i = _window.length - n; i < _window.length; i++) {
      e += _window[i] * _window[i];
    }
    return n == 0 ? 0 : math.sqrt(e / n);
  }

  void _set(TunerState s) {
    state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    _sub?.cancel();
    super.dispose();
  }
}
