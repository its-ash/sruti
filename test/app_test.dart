import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sruti/screens/home_screen.dart';
import 'package:sruti/settings/settings_store.dart';
import 'package:theme/theme.dart';

import 'fake_audio.dart';

Future<void> pumpApp(WidgetTester tester, FakeAudio audio, SettingsStore settings, {PermissionStatus status = PermissionStatus.granted}) async {
  UiTypography.useGoogleFonts = false;
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UiApp(
      title: 'Sruti',
      home: HomeScreen(audio: audio, settings: settings, requestMic: () async => status),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the guitar tuner, switches tabs, opens settings', (tester) async {
    final audio = FakeAudio();
    final settings = await SettingsStore.load();
    await pumpApp(tester, audio, settings);

    expect(find.text('Guitar'), findsWidgets);
    expect(find.text('Pluck a string'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);

    await tester.tap(find.text('Swara'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your Sa'), findsWidgets);
    expect(find.text('Devanagari names'), findsOneWidget);

    await tester.tap(find.text('Drone'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start drone'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    // Not pumpAndSettle: the update row keeps a spinner running.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reference pitch (A4)'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
  });

  testWidgets('asks for the microphone when it is denied', (tester) async {
    final settings = await SettingsStore.load();
    await pumpApp(tester, FakeAudio(), settings, status: PermissionStatus.denied);
    expect(find.text('Microphone needed'), findsOneWidget);
    expect(find.text('Allow microphone'), findsOneWidget);
  });
}
