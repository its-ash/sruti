# Sruti

Guitar and Indian classical tuner with a tanpura drone. Works offline.

**[Website](https://sruti.itsash.in)** · **[Download APK](https://github.com/its-ash/sruti/releases/latest/download/sruti.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Guitar**: Standard, Drop D, D standard, Open G, Open D, DADGAD, half step down, 4-string bass and ukulele GCEA. Finds the nearest string by itself, or lock a string by tapping it.
- **Chromatic**: any note from 30 Hz to 2 kHz with octave and cents.
- **Swara**: pick your Sa (note with its Kali / Safed number, octave 2 to 4, fine tune of 50 cents) and see the swara you sing or play: Sa, komal / shuddh Re, Ga, Dha, Ni, shuddh / tivra Ma, Pa, with mandra, madhya and taar saptak and the deviation in cents. Optional just-intonation ratios and Devanagari names.
- **Drone**: a synthesized tanpura (Pa Sa Sa Sa, Ma Sa Sa Sa, Ni Sa Sa Sa) or a steady sruti (Sa Pa), tuned to your Sa, with tempo and volume.
- Reference pitch A4 adjustable from 430 to 450 Hz.
- Pitch detection runs on your phone (YIN). Sound is never recorded or sent.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Sruti from it.
- **APK**: download the [latest APK](https://github.com/its-ash/sruti/releases/latest/download/sruti.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) or newer.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make build    # release APK
make test     # flutter analyze + flutter test
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `sruti.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
├── main.dart                      # UiApp + HomeScreen
├── core/                          # pure Dart, unit tested
│   ├── notes.dart                 # note / cents math, A4 reference
│   ├── pitch_detector.dart        # YIN detector + PitchTracker smoothing
│   ├── tunings.dart               # guitar, bass, ukulele tunings
│   ├── swara.dart                 # swara mapping, saptak, Sa, just intonation
│   └── drone.dart                 # additive tanpura / sruti synthesis
├── audio/                         # TunerController (mic), DroneController
├── platform/audio_channel.dart    # EventChannel / MethodChannel to Kotlin
├── settings/settings_store.dart   # A4, tuning, Sa, drone settings
├── widgets/                       # meter, reading card, Sa picker, mic gate
└── screens/                       # home (UiShell), guitar, chromatic, swara, drone, settings
android/app/src/main/kotlin/com/itsash/sruti/
├── MainActivity.kt                # channels
├── MicStreamHandler.kt            # AudioRecord PCM stream, 44.1 kHz mono
└── DroneEngine.kt                 # looped static AudioTrack
```

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
