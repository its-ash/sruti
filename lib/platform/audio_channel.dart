import 'dart:async';

import 'package:flutter/services.dart';

const _base = 'com.itsash.sruti';

/// The microphone cannot be used.
class MicUnavailable implements Exception {
  const MicUnavailable(this.message, {this.permissionDenied = false});

  final String message;
  final bool permissionDenied;

  @override
  String toString() => message;
}

/// Native audio: microphone input for the tuner and looped playback for the
/// drone. Implemented in Kotlin (`MainActivity.kt`).
abstract class AudioChannel {
  /// Raw microphone audio as 16-bit little-endian mono PCM at
  /// [micSampleRate], in small chunks. Needs the microphone permission.
  Stream<Uint8List> micChunks();

  static const micSampleRate = 44100;

  /// Plays [pcm] (16-bit mono) in a loop until [stopDrone].
  Future<void> playDrone(Uint8List pcm, int sampleRate);
  Future<void> setDroneVolume(double volume);
  Future<void> stopDrone();

  Future<void> keepScreenOn(bool on);
}

class PlatformAudioChannel implements AudioChannel {
  const PlatformAudioChannel();

  static const _mic = EventChannel('$_base/mic');
  static const _drone = MethodChannel('$_base/drone');

  @override
  Stream<Uint8List> micChunks() => _mic.receiveBroadcastStream().map((e) => e as Uint8List).transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) => sink.add(data),
          handleError: (error, stack, sink) {
            if (error is PlatformException) {
              final denied = error.code == 'no_permission';
              sink.addError(
                MicUnavailable(denied ? 'Microphone permission is needed.' : 'The microphone is not available.',
                    permissionDenied: denied),
                stack,
              );
            } else if (error is MissingPluginException) {
              sink.addError(const MicUnavailable('The microphone is not available.'), stack);
            } else {
              sink.addError(error, stack);
            }
          },
        ),
      );

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _drone.invokeMethod<void>(method, args);
    } on PlatformException {
      // Best effort: audio output may be busy.
    } on MissingPluginException {
      // No native side (tests).
    }
  }

  @override
  Future<void> playDrone(Uint8List pcm, int sampleRate) => _call('play', {'pcm': pcm, 'sampleRate': sampleRate});

  @override
  Future<void> setDroneVolume(double volume) => _call('volume', volume);

  @override
  Future<void> stopDrone() => _call('stop');

  @override
  Future<void> keepScreenOn(bool on) => _call('keepScreenOn', on);
}
