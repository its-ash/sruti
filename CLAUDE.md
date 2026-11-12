# Sruti (package: sruti / com.itsash.sruti)

Instrument tuner and sruti box for Android, offline. Four tabs in a `UiShell`
bottom navigation: **Guitar** (tunings, auto or locked string), **Chromatic**,
**Swara** (Indian classical: swara of the heard pitch relative to the user's Sa)
and **Drone** (tanpura / sruti synthesized on the phone). Settings (A4
reference) from the app bar icon. The window keeps the screen on while
`HomeScreen` is alive.

## Code layout

- `lib/core/`: pure Dart, all unit tested (`test/`). Add a test for every change.
  - `notes.dart`: `midiToFreq`, `freqToMidi`, `centsBetween`, `NoteReading`
    (nearest note, cents -50..50), A4 range 430..450, detect range 30 Hz..2 kHz,
    in-tune window +-4 cents.
  - `pitch_detector.dart`: `PitchDetector` (YIN: difference function, cumulative
    mean normalization, absolute threshold 0.15 first-dip rule, parabolic
    interpolation; 2048-sample window + lag up to 30 Hz, RMS gate) and
    `PitchTracker` (needs 2 agreeing frames for a jump > 80 cents, EMA otherwise,
    holds 5 frames over gaps, min confidence 0.75).
  - `tunings.dart`: 9 tunings (7 guitar, bass, ukulele), `nearestString`.
  - `swara.dart`: 12 `swaras` (komal/shuddh/tivra, Devanagari, just ratios),
    `swaraForFreq(freq, saFreq, just:)` -> swara, octave (saptak), cents;
    `SaPitch`; `kaliSafedName` (Safed 1 = C, Kali 1 = C#, ... harmonium keys).
  - `drone.dart`: `renderDrone` -> one seamless loop (22.05 kHz mono). Tanpura:
    4 plucks (ratios from `tanpuraRatios`: low Pa/Ma/Ni, Sa, Sa, low Sa), 16
    harmonics with a jawari-like late bloom, tails wrap around the loop. Sruti:
    Sa + Pa + low Sa, loop length chosen (`loopFor`) so every partial has whole
    cycles. `toPcm16`.
- `lib/audio/`: `TunerController` (mic PCM -> ring window -> YIN every 2 chunks
  (~46 ms) -> tracker; permission via `permission_handler`), `DroneController`
  (renders in `Isolate.run`, debounces re-render on Sa / A4 / pattern / tempo
  change, volume applies at once).
- `lib/platform/audio_channel.dart`: `AudioChannel` interface + Kotlin-backed
  `PlatformAudioChannel` (`com.itsash.sruti/mic` events: Int16 LE PCM chunks of
  1024 samples at 44.1 kHz; `com.itsash.sruti/drone` methods: `play`, `volume`,
  `stop`, `keepScreenOn`). Tests use `test/fake_audio.dart`.
- `lib/settings/settings_store.dart`: `ChangeNotifier` over `shared_preferences`
  (A4, tuning, Sa, Devanagari, just intonation, drone pattern / tempo / volume).
- `lib/widgets/`, `lib/screens/`: UI from the shared theme only; `TunerMeter` is
  a CustomPainter using `context.colors`. `settings_screen` ends with
  `UiAppearanceSection`, `UiUpdateSection(storeId: 'sruti')`, `UiDeveloperSection`.
- `android/app/src/main/kotlin/com/itsash/sruti/`: `MainActivity.kt`,
  `MicStreamHandler.kt` (`AudioRecord`, source MIC), `DroneEngine.kt` (static
  `AudioTrack`, loop points, `setVolume`).

## Commands

- `make run`, `make build` (release APK), `make test` (`flutter analyze` +
  `flutter test`), `make clean`.
- Icon: SVG sources in `assets/icon/` (`logo`, `logo_foreground`,
  `logo_background`; pixel-art tuning fork, 16x16 grid) -> `rsvg-convert -w 1024
  -h 1024` to `*-1024.png`, then `dart run flutter_launcher_icons`.

## Conventions

- minSdk 26. UI only from the shared `theme` package (`../theme`, read
  `../theme/COMPONENTS.md`); no hardcoded colors.
- Permissions: `INTERNET` (update check only), `RECORD_AUDIO` (tuner tabs,
  requested when one opens). No analytics; audio is never stored or sent.
- The drone has no foreground service: it plays while the app process lives
  (also screen off / other app in front) and stops when the app is closed. If
  background kill becomes a problem, add a `mediaPlayback` foreground service
  with `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `POST_NOTIFICATIONS`.
- Swara detection is relative to the chosen Sa; swaras use equal temperament by
  default, just-intonation ratios with the toggle.

## Release (Ash Store)

- `store.json` (id `sruti`, repo its-ash/sruti), `store.mk`, `index.html` +
  `CNAME` (`sruti.itsash.in`). See `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version -> build -> commit, tag `vX.Y.Z`, push -> GitHub
  release with `sruti.apk` -> topics, homepage, Pages. Never create releases,
  tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run
  `make store-sync` at the workspace root.
