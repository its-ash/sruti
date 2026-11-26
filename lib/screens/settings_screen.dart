import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/notes.dart';
import '../settings/settings_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: const UiAppBar(title: 'Settings'),
      scrollable: true,
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiListGroup(
              header: 'Tuning',
              footer: 'Concert pitch for the guitar and chromatic tuner, the swara tuner and the drone. '
                  'Most instruments use 440 Hz.',
              children: [
                UiListTile(
                  'Reference pitch (A4)',
                  icon: Icons.music_note_rounded,
                  subtitle: '${minReferenceA.round()} to ${maxReferenceA.round()} Hz',
                  trailing: UiStepper<double>(
                    value: settings.refA,
                    min: minReferenceA,
                    max: maxReferenceA,
                    step: 1,
                    decimals: 0,
                    format: (v) => '${v.round()} Hz',
                    semanticLabel: 'Reference pitch A4 in hertz',
                    onChanged: settings.setRefA,
                  ),
                ),
                UiListTile(
                  'Reset to 440 Hz',
                  icon: Icons.restart_alt_rounded,
                  enabled: settings.refA != defaultReferenceA,
                  onTap: () => settings.setRefA(defaultReferenceA),
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            const UiListGroup(
              header: 'Privacy',
              children: [
                UiListTile(
                  'Everything stays on this phone',
                  subtitle: 'The microphone is used only to find the pitch while a tuner tab is open. Sound is '
                      'never recorded or sent. Sruti uses the internet only to check for app updates.',
                  icon: Icons.lock_rounded,
                  iconStatus: UiStatus.success,
                  maxSubtitleLines: 5,
                ),
              ],
            ),
            const UiGap(UiSpace.lg),
            const UiAppearanceSection(),
            const UiGap(UiSpace.lg),
            const UiUpdateSection(storeId: 'sruti'),
            const UiGap(UiSpace.lg),
            const UiDeveloperSection(),
          ],
        ),
      ),
    );
  }
}
