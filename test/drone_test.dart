import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sruti/core/drone.dart';
import 'package:sruti/core/notes.dart';
import 'package:sruti/core/pitch_detector.dart';

double peak(Float64List x) => x.fold(0.0, (m, v) => math.max(m, v.abs()));

void main() {
  const sa = 130.8128;

  test('tanpura string ratios', () {
    expect(tanpuraRatios(DronePattern.paSa), [0.75, 1, 1, 0.5]);
    expect(tanpuraRatios(DronePattern.maSa)[0], closeTo(2 / 3, 1e-12));
    expect(tanpuraRatios(DronePattern.niSa)[0], closeTo(15 / 16, 1e-12));
  });

  test('tanpura loop length follows the tempo', () {
    final a = renderDrone(saFreq: sa, pattern: DronePattern.paSa, bpm: 60);
    expect(a.length, 4 * droneSampleRate);
    final b = renderDrone(saFreq: sa, pattern: DronePattern.paSa, bpm: 30);
    expect(b.length, 8 * droneSampleRate);
  });

  test('bpm is clamped', () {
    final x = renderDrone(saFreq: sa, pattern: DronePattern.maSa, bpm: 1000);
    expect(x.length, (4 * 60 / maxDroneBpm * droneSampleRate).round());
  });

  for (final p in DronePattern.values) {
    test('${p.name}: normalized, finite and loud enough', () {
      final x = renderDrone(saFreq: sa, pattern: p);
      expect(x.every((v) => v.isFinite), isTrue);
      expect(peak(x), closeTo(0.85, 1e-9));
      final rms = math.sqrt(x.fold(0.0, (s, v) => s + v * v) / x.length);
      expect(rms, greaterThan(0.05));
    });
  }

  test('tanpura loop has no click at the seam', () {
    final x = renderDrone(saFreq: sa, pattern: DronePattern.paSa, bpm: 45);
    var maxStep = 0.0;
    for (var i = 1; i < x.length; i++) {
      maxStep = math.max(maxStep, (x[i] - x[i - 1]).abs());
    }
    final seam = (x[0] - x[x.length - 1]).abs();
    expect(seam, lessThan(maxStep * 1.5 + 0.02));
  });

  test('sruti loop is seamless', () {
    final x = renderDrone(saFreq: sa, pattern: DronePattern.sruti);
    var maxStep = 0.0;
    for (var i = 1; i < x.length; i++) {
      maxStep = math.max(maxStep, (x[i] - x[i - 1]).abs());
    }
    final seam = (x[0] - x[x.length - 1]).abs();
    expect(seam, lessThan(maxStep * 1.2));
  });

  test('loopFor fits a whole even number of cycles', () {
    for (final f in [98.0, 110.0, 130.8128, 146.83, 196.0, 261.63, 392.0]) {
      final l = loopFor(f, droneSampleRate);
      expect(l.cycles.isEven, isTrue);
      final eff = l.cycles * droneSampleRate / l.samples;
      expect(centsBetween(eff, f).abs(), lessThan(0.5), reason: '$f -> $eff');
      expect(l.samples, inInclusiveRange((3.5 * droneSampleRate).round(), (4.5 * droneSampleRate).round()));
    }
  });

  test('sruti is tuned to Sa: low Sa is the fundamental of the mix', () {
    final x = renderDrone(saFreq: sa, pattern: DronePattern.sruti);
    final d = PitchDetector(sampleRate: droneSampleRate, windowSize: 2048);
    final window = Float64List.sublistView(x, 0, d.bufferSize);
    final r = d.detect(window);
    expect(r, isNotNull);
    // The mix of Sa/2, Sa and 3Sa/2 repeats at Sa/2.
    expect(centsBetween(r!.freq, sa / 2).abs(), lessThan(8), reason: 'got ${r.freq}');
  });

  test('a lone pluck has the pitch of its string through its whole life', () {
    final d = PitchDetector(sampleRate: droneSampleRate);
    for (final f in [98.0, 130.81, 165.0, 220.0, 392.0]) {
      final x = renderPluck(f, seconds: 4);
      for (final at in [0.1, 0.5, 1.5, 3.0]) {
        final start = (at * droneSampleRate).round();
        final r = d.detect(Float64List.sublistView(x, start, start + d.bufferSize));
        expect(r, isNotNull, reason: '$f at $at s');
        expect(centsBetween(r!.freq, f).abs(), lessThan(8), reason: '$f at $at s got ${r.freq}');
      }
    }
  });

  test('tanpura mix repeats at the greatest common pitch of its strings', () {
    // Sa 220: strings 165, 220, 220, 110 share a 55 Hz fundamental.
    final x = renderDrone(saFreq: 220, pattern: DronePattern.paSa, bpm: 30);
    final d = PitchDetector(sampleRate: droneSampleRate);
    final start = (0.5 * droneSampleRate).round();
    final r = d.detect(Float64List.sublistView(x, start, start + d.bufferSize));
    expect(r, isNotNull);
    expect(centsBetween(r!.freq, 55).abs(), lessThan(8), reason: 'got ${r.freq}');
  });

  test('pcm16 conversion', () {
    final pcm = toPcm16(Float64List.fromList([0, 1, -1, 0.5, 2]));
    final bd = ByteData.sublistView(pcm);
    expect(pcm.length, 10);
    expect(bd.getInt16(0, Endian.little), 0);
    expect(bd.getInt16(2, Endian.little), 32767);
    expect(bd.getInt16(4, Endian.little), -32767);
    expect(bd.getInt16(6, Endian.little), closeTo(16384, 1));
    expect(bd.getInt16(8, Endian.little), 32767);
  });

  test('pattern labels', () {
    expect(DronePattern.paSa.label, 'Pa Sa Sa Sa');
    expect(DronePattern.sruti.isTanpura, isFalse);
    expect(DronePattern.values.every((p) => p.devanagari.isNotEmpty), isTrue);
  });
}
