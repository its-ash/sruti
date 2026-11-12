import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sruti/audio/drone_controller.dart';
import 'package:sruti/audio/tuner_controller.dart';
import 'package:sruti/core/drone.dart';
import 'package:sruti/core/notes.dart';
import 'package:sruti/settings/settings_store.dart';

import 'fake_audio.dart';

Future<void> feed(FakeAudio audio, double freq, {int chunks = 12}) async {
  for (var c = 0; c < chunks; c++) {
    audio.mic.add(sinePcm(freq, 1024, offset: c * 1024));
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('TunerController', () {
    test('reports the pitch of streamed audio', () async {
      final audio = FakeAudio();
      final t = TunerController(audio: audio, requestPermission: () async => PermissionStatus.granted);
      await t.start();
      expect(t.state, TunerState.running);
      await feed(audio, 196.0, chunks: 24);
      expect(t.freq, isNotNull);
      expect(centsBetween(t.freq!, 196).abs(), lessThan(3));
      expect(t.level, greaterThan(0.1));
      t.stop();
      expect(t.freq, isNull);
      expect(t.state, TunerState.idle);
      t.dispose();
    });

    test('silence gives no pitch', () async {
      final audio = FakeAudio();
      final t = TunerController(audio: audio, requestPermission: () async => PermissionStatus.granted);
      await t.start();
      for (var i = 0; i < 12; i++) {
        audio.mic.add(sinePcm(440, 1024, amp: 0));
        await Future<void>.delayed(Duration.zero);
      }
      expect(t.freq, isNull);
      t.dispose();
    });

    test('permission denied and denied forever', () async {
      final t = TunerController(audio: FakeAudio(), requestPermission: () async => PermissionStatus.denied);
      await t.start();
      expect(t.state, TunerState.denied);
      final f = TunerController(audio: FakeAudio(), requestPermission: () async => PermissionStatus.permanentlyDenied);
      await f.start();
      expect(f.state, TunerState.deniedForever);
      t.dispose();
      f.dispose();
    });

    test('stream errors become states', () async {
      final audio = FakeAudio();
      final t = TunerController(audio: audio, requestPermission: () async => PermissionStatus.granted);
      await t.start();
      audio.mic.addError(const MicUnavailableForTest());
      await Future<void>.delayed(Duration.zero);
      expect(t.state, TunerState.unavailable);
      t.dispose();
    });

    test('start twice does not subscribe twice', () async {
      final audio = FakeAudio();
      final t = TunerController(audio: audio, requestPermission: () async => PermissionStatus.granted);
      await t.start();
      await t.start();
      expect(audio.mic.hasListener, isTrue);
      t.dispose();
    });
  });

  group('DroneController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('start renders and plays, stop stops', () async {
      final audio = FakeAudio();
      final settings = await SettingsStore.load();
      final d = DroneController(audio: audio, settings: settings);
      await d.start();
      expect(d.playing, isTrue);
      expect(audio.calls, contains('play'));
      expect(audio.lastDrone, isNotNull);
      // 4 plucks at 45 per minute, 16-bit samples.
      expect(audio.lastDrone!.length, (4 * 60 / 45 * droneSampleRate).round() * 2);
      await d.stop();
      expect(d.playing, isFalse);
      expect(audio.calls.last, 'stop');
      d.dispose();
    });

    test('volume follows the setting at once', () async {
      final audio = FakeAudio();
      final settings = await SettingsStore.load();
      final d = DroneController(audio: audio, settings: settings);
      settings.setDroneVolume(0.3);
      expect(audio.lastVolume, closeTo(0.3, 1e-9));
      d.dispose();
    });

    test('stop while rendering does not play', () async {
      final audio = FakeAudio();
      final settings = await SettingsStore.load();
      final d = DroneController(audio: audio, settings: settings);
      final started = d.start();
      await d.stop();
      await started;
      expect(audio.calls.where((c) => c == 'play'), isEmpty);
      d.dispose();
    });
  });

  group('SettingsStore', () {
    test('defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsStore.load();
      expect(s.refA, 440);
      expect(s.tuningId, 'standard');
      expect(s.sa.label, 'C3');
      expect(s.devanagari, isFalse);
      expect(s.justIntonation, isFalse);
      expect(s.dronePattern, DronePattern.paSa);
    });

    test('values persist and are clamped', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsStore.load();
      s.setRefA(500);
      expect(s.refA, 450);
      s.setRefA(432);
      s.setTuning('drop_d');
      s.setSa(s.sa.copyWith(pitchClass: 2, octave: 4, fineCents: 12));
      s.setDevanagari(true);
      s.setDronePattern(DronePattern.sruti);
      s.setDroneBpm(5);
      expect(s.droneBpm, minDroneBpm);

      final again = await SettingsStore.load();
      expect(again.refA, 432);
      expect(again.tuningId, 'drop_d');
      expect(again.sa.label, 'D4');
      expect(again.sa.fineCents, 12);
      expect(again.devanagari, isTrue);
      expect(again.dronePattern, DronePattern.sruti);
    });

    test('saFreq follows A4 reference', () async {
      SharedPreferences.setMockInitialValues({'ref_a': 432.0, 'sa_class': 9, 'sa_octave': 4});
      final s = await SettingsStore.load();
      expect(s.saFreq, closeTo(432, 1e-9));
    });
  });
}

class MicUnavailableForTest implements Exception {
  const MicUnavailableForTest();
}
