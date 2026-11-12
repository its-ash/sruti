import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sruti/platform/audio_channel.dart';

/// An [AudioChannel] for tests: the mic is a controller you push PCM into.
class FakeAudio implements AudioChannel {
  final mic = StreamController<Uint8List>.broadcast();
  int micListeners = 0;
  final calls = <String>[];
  Uint8List? lastDrone;
  double? lastVolume;

  @override
  Stream<Uint8List> micChunks() {
    return mic.stream;
  }

  @override
  Future<void> playDrone(Uint8List pcm, int sampleRate) async {
    calls.add('play');
    lastDrone = pcm;
  }

  @override
  Future<void> setDroneVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> stopDrone() async {
    calls.add('stop');
  }

  @override
  Future<void> keepScreenOn(bool on) async {
    calls.add('screen:$on');
  }
}

/// 16-bit PCM of a sine, [n] samples starting at sample [offset].
Uint8List sinePcm(double freq, int n, {int offset = 0, int sr = 44100, double amp = 0.5}) {
  final bd = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    final v = amp * math.sin(2 * math.pi * freq * (i + offset) / sr);
    bd.setInt16(i * 2, (v * 32767).round(), Endian.little);
  }
  return bd.buffer.asUint8List();
}
