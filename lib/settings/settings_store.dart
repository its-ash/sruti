import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/drone.dart';
import '../core/notes.dart';
import '../core/swara.dart';

/// User settings, persisted in `shared_preferences`.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs) {
    refA = (_prefs.getDouble(_kRefA) ?? defaultReferenceA).clamp(minReferenceA, maxReferenceA).toDouble();
    tuningId = _prefs.getString(_kTuning) ?? 'standard';
    sa = SaPitch(
      pitchClass: (_prefs.getInt(_kSaClass) ?? 0).clamp(0, 11),
      octave: (_prefs.getInt(_kSaOctave) ?? 3).clamp(2, 4),
      fineCents: (_prefs.getDouble(_kSaFine) ?? 0).clamp(-50.0, 50.0).toDouble(),
    );
    devanagari = _prefs.getBool(_kDeva) ?? false;
    justIntonation = _prefs.getBool(_kJust) ?? false;
    dronePattern = DronePattern.values.firstWhere(
      (p) => p.name == _prefs.getString(_kPattern),
      orElse: () => DronePattern.paSa,
    );
    droneBpm = (_prefs.getDouble(_kBpm) ?? 45).clamp(minDroneBpm, maxDroneBpm).toDouble();
    droneVolume = (_prefs.getDouble(_kVolume) ?? 0.8).clamp(0.0, 1.0).toDouble();
  }

  static const _kRefA = 'ref_a';
  static const _kTuning = 'tuning';
  static const _kSaClass = 'sa_class';
  static const _kSaOctave = 'sa_octave';
  static const _kSaFine = 'sa_fine';
  static const _kDeva = 'devanagari';
  static const _kJust = 'just';
  static const _kPattern = 'drone_pattern';
  static const _kBpm = 'drone_bpm';
  static const _kVolume = 'drone_volume';

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async => SettingsStore._(await SharedPreferences.getInstance());

  /// Frequency of A4 in Hz (430..450).
  late double refA;
  late String tuningId;

  /// The singer's Sa: note, octave and fine tuning.
  late SaPitch sa;

  /// Show swara names in Devanagari.
  late bool devanagari;

  /// Judge swaras against just-intonation ratios instead of equal temperament.
  late bool justIntonation;

  late DronePattern dronePattern;
  late double droneBpm;
  late double droneVolume;

  double get saFreq => sa.freq(refA);

  void setRefA(double value) {
    refA = value.clamp(minReferenceA, maxReferenceA).toDouble();
    _prefs.setDouble(_kRefA, refA);
    notifyListeners();
  }

  void setTuning(String id) {
    tuningId = id;
    _prefs.setString(_kTuning, id);
    notifyListeners();
  }

  void setSa(SaPitch value) {
    sa = value;
    _prefs.setInt(_kSaClass, value.pitchClass);
    _prefs.setInt(_kSaOctave, value.octave);
    _prefs.setDouble(_kSaFine, value.fineCents);
    notifyListeners();
  }

  void setDevanagari(bool value) {
    devanagari = value;
    _prefs.setBool(_kDeva, value);
    notifyListeners();
  }

  void setJustIntonation(bool value) {
    justIntonation = value;
    _prefs.setBool(_kJust, value);
    notifyListeners();
  }

  void setDronePattern(DronePattern value) {
    dronePattern = value;
    _prefs.setString(_kPattern, value.name);
    notifyListeners();
  }

  void setDroneBpm(double value) {
    droneBpm = value.clamp(minDroneBpm, maxDroneBpm).toDouble();
    _prefs.setDouble(_kBpm, droneBpm);
    notifyListeners();
  }

  void setDroneVolume(double value) {
    droneVolume = value.clamp(0.0, 1.0).toDouble();
    _prefs.setDouble(_kVolume, droneVolume);
    notifyListeners();
  }
}
