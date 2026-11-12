import 'dart:math' as math;
import 'dart:typed_data';

import 'notes.dart';

/// One pitch estimate.
class PitchResult {
  const PitchResult({required this.freq, required this.confidence, required this.rms});

  /// Fundamental frequency in Hz.
  final double freq;

  /// 0..1, higher is more periodic (1 - YIN's normalized difference).
  final double confidence;

  /// Signal level of the analysed window, 0..1 (full scale = 1).
  final double rms;
}

/// Monophonic pitch detection with the YIN algorithm (de Cheveigne and
/// Kawahara, 2002) on mono PCM.
///
/// It needs [bufferSize] samples: a [windowSize] integration window plus the
/// longest lag searched. Only the last [bufferSize] samples of the input are
/// used. Lags are searched for [minFreq]..[maxFreq]. The first dip of the
/// normalized difference function under [threshold] is taken as the period
/// (this is what avoids octave errors on harmonic-rich signals), then refined
/// with a parabola through its neighbours.
class PitchDetector {
  PitchDetector({
    this.sampleRate = 44100,
    this.windowSize = 2048,
    this.threshold = 0.15,
    this.fallbackThreshold = 0.25,
    this.minFreq = minDetectHz,
    this.maxFreq = maxDetectHz,
    this.minRms = 0.004,
  })  : tauMin = math.max(2, (sampleRate / maxFreq).floor()),
        tauMax = (sampleRate / minFreq).ceil() {
    _diff = Float64List(tauMax + 2);
    _cmnd = Float64List(tauMax + 2);
  }

  final int sampleRate;
  final int windowSize;

  /// A dip under this value is accepted at once.
  final double threshold;

  /// With no dip under [threshold], the deepest dip is used if under this.
  final double fallbackThreshold;
  final double minFreq;
  final double maxFreq;

  /// Windows quieter than this (RMS) are treated as silence.
  final double minRms;

  final int tauMin;
  final int tauMax;

  late final Float64List _diff;
  late final Float64List _cmnd;

  /// Samples needed for one analysis.
  int get bufferSize => windowSize + tauMax + 2;

  /// Estimates the pitch of the end of [samples] (-1..1), or null when the
  /// window is silent, noisy or not periodic enough.
  PitchResult? detect(List<double> samples) {
    if (samples.length < bufferSize) return null;
    final x = samples is Float64List ? samples : Float64List.fromList(samples);
    final start = x.length - bufferSize;

    var energy = 0.0;
    for (var i = 0; i < windowSize; i++) {
      final v = x[start + i];
      energy += v * v;
    }
    final rms = math.sqrt(energy / windowSize);
    if (rms < minRms) return null;

    // Difference function.
    for (var tau = 1; tau <= tauMax + 1; tau++) {
      var sum = 0.0;
      final off = start + tau;
      for (var j = 0; j < windowSize; j++) {
        final d = x[start + j] - x[off + j];
        sum += d * d;
      }
      _diff[tau] = sum;
    }

    // Cumulative mean normalized difference.
    _cmnd[0] = 1;
    var running = 0.0;
    for (var tau = 1; tau <= tauMax + 1; tau++) {
      running += _diff[tau];
      _cmnd[tau] = running == 0 ? 1 : _diff[tau] * tau / running;
    }

    // Absolute threshold: first dip under the threshold, walked to its bottom.
    var best = -1;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (_cmnd[tau] < threshold) {
        while (tau + 1 <= tauMax && _cmnd[tau + 1] < _cmnd[tau]) {
          tau++;
        }
        best = tau;
        break;
      }
    }
    if (best < 0) {
      // No clear dip: take the deepest one, if it is deep enough.
      var min = double.infinity;
      for (var tau = tauMin; tau <= tauMax; tau++) {
        if (_cmnd[tau] < min) {
          min = _cmnd[tau];
          best = tau;
        }
      }
      if (best < 0 || min > fallbackThreshold) return null;
    }

    final tau = _refine(best);
    final freq = sampleRate / tau;
    if (freq < minFreq || freq > maxFreq) return null;
    final confidence = (1 - _cmnd[best]).clamp(0.0, 1.0).toDouble();
    return PitchResult(freq: freq, confidence: confidence, rms: rms);
  }

  /// Parabolic interpolation of the minimum around [tau].
  double _refine(int tau) {
    if (tau <= 1 || tau >= tauMax + 1) return tau.toDouble();
    final a = _cmnd[tau - 1], b = _cmnd[tau], c = _cmnd[tau + 1];
    final denom = a - 2 * b + c;
    if (denom.abs() < 1e-12) return tau.toDouble();
    final shift = 0.5 * (a - c) / denom;
    return tau + shift.clamp(-1.0, 1.0);
  }
}

/// Steadies a stream of [PitchResult]s for display.
///
/// A new pitch far from the shown one (more than [jumpCents]) must show up
/// in two frames in a row before the display moves, which hides single
/// octave blips on a note attack. Close readings are smoothed in the cents
/// domain. Short gaps (up to [holdFrames] frames) keep the last pitch.
class PitchTracker {
  PitchTracker({this.jumpCents = 80, this.alpha = 0.35, this.holdFrames = 5, this.minConfidence = 0.75});

  final double jumpCents;
  final double alpha;
  final int holdFrames;
  final double minConfidence;

  double? _current;
  double? _pending;
  int _misses = 0;

  /// The pitch to show, or null when nothing is playing.
  double? get freq => _current;

  void reset() {
    _current = null;
    _pending = null;
    _misses = 0;
  }

  /// Feeds one analysis result (null = none) and returns the pitch to show.
  double? update(PitchResult? result) {
    if (result == null || result.confidence < minConfidence) {
      _misses++;
      _pending = null;
      if (_misses > holdFrames) _current = null;
      return _current;
    }
    _misses = 0;
    final f = result.freq;
    final cur = _current;
    if (cur != null && centsBetween(f, cur).abs() <= jumpCents) {
      _pending = null;
      final cents = centsBetween(f, cur);
      _current = cur * math.pow(2, alpha * cents / 1200);
      return _current;
    }
    // A far jump, or the first sound after silence.
    final pending = _pending;
    if (pending != null && centsBetween(f, pending).abs() <= 50) {
      _current = f;
      _pending = null;
    } else {
      _pending = f;
    }
    return _current;
  }
}
