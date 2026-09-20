import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';

import '../core/app_version.dart';
import '../core/prefs.dart';
import '../services/remote_bridge.dart';
import '../widgets/appearance_thumb.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: SettingsPageScaffold(
        title: 'Settings',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
          children: [
            SettingsAboutHero(
              productName: 'Remote Keyboard',
              versionLabel: kAppVersionLabel,
              creditLabel: 'AmL Systems',
              semanticsLabel: 'Remote Keyboard',
            ),
            const SizedBox(height: 20),
            _section(
              'Home',
              SettingsChoicePicker(
                selected: RemotePrefs.homeLayout,
                onSelected: (v) => setState(() => RemotePrefs.homeLayout = v),
                choices: const [
                  SettingsChoice(
                    value: HomeLayout.keyboard,
                    label: 'Keyboard',
                    icon: Icons.keyboard_rounded,
                  ),
                  SettingsChoice(
                    value: HomeLayout.mouse,
                    label: 'Mouse',
                    icon: Icons.mouse_rounded,
                  ),
                ],
              ),
            ),
            _section(
              'Connect with',
              SettingsChoicePicker<ConnectionMode>(
                selected: RemotePrefs.connectionMode,
                onSelected: _pickConnection,
                choices: const [
                  SettingsChoice(
                    value: ConnectionMode.hid,
                    label: 'Bluetooth',
                    icon: Icons.bluetooth_rounded,
                  ),
                  SettingsChoice(
                    value: ConnectionMode.helper,
                    label: 'Helper',
                    icon: Icons.laptop_windows_rounded,
                  ),
                ],
              ),
            ),
            _panel(
              SettingsCard(
                children: [
                  SettingsSwitchTile(
                    title: const Text('Reconnect on start'),
                    subtitle:
                        'Open the path you picked above when the app starts',
                    value: RemotePrefs.autoReconnect,
                    onChanged: (v) =>
                        setState(() => RemotePrefs.autoReconnect = v),
                  ),
                ],
              ),
            ),
            _section(
              'Layout',
              SettingsChoicePicker(
                selected: RemotePrefs.layout,
                onSelected: (v) => setState(() => RemotePrefs.layout = v),
                choices: const [
                  SettingsChoice(
                    value: KeyboardLayout.qwerty,
                    label: 'QWERTY',
                    icon: Icons.keyboard_rounded,
                  ),
                  SettingsChoice(
                    value: KeyboardLayout.azerty,
                    label: 'AZERTY',
                    icon: Icons.keyboard_alt_rounded,
                  ),
                ],
              ),
            ),
            _section(
              'Size',
              SettingsChoicePicker(
                selected: RemotePrefs.size,
                onSelected: (v) => setState(() => RemotePrefs.size = v),
                choices: const [
                  SettingsChoice(value: KeyboardSize.normal, label: 'Normal'),
                  SettingsChoice(value: KeyboardSize.larger, label: 'Larger'),
                ],
              ),
            ),
            _section(
              'Look',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final appearance in KeyboardAppearance.values)
                    AppearanceThumb(
                      appearance: appearance,
                      selected: RemotePrefs.appearance == appearance,
                      onTap: () =>
                          setState(() => RemotePrefs.appearance = appearance),
                    ),
                ],
              ),
            ),
            _panel(
              SettingsCard(
                children: [
                  SettingsSwitchTile(
                    title: const Text('Live theme'),
                    subtitle: 'A flying bubble on the home screen to try looks',
                    value: RemotePrefs.liveTheme,
                    onChanged: (v) => setState(() => RemotePrefs.liveTheme = v),
                  ),
                  SettingsSwitchTile(
                    title: const Text('Key border'),
                    value: RemotePrefs.borderEnabled,
                    onChanged: (v) =>
                        setState(() => RemotePrefs.borderEnabled = v),
                  ),
                  if (RemotePrefs.borderEnabled)
                    SettingsSwitchTile(
                      title: const Text('Thick border'),
                      value: RemotePrefs.borderThick,
                      onChanged: (v) =>
                          setState(() => RemotePrefs.borderThick = v),
                    ),
                ],
              ),
            ),
            if (RemotePrefs.borderEnabled)
              _section(
                'Border color',
                SettingsChoicePicker(
                  selected: RemotePrefs.borderColor,
                  onSelected: (v) =>
                      setState(() => RemotePrefs.borderColor = v),
                  choices: const [
                    SettingsChoice(value: BorderColor.gray, label: 'Gray'),
                    SettingsChoice(
                      value: BorderColor.darkGray,
                      label: 'Dark gray',
                    ),
                    SettingsChoice(value: BorderColor.black, label: 'Black'),
                    SettingsChoice(value: BorderColor.white, label: 'White'),
                    SettingsChoice(value: BorderColor.pearl, label: 'Pearl'),
                    SettingsChoice(value: BorderColor.mint, label: 'Mint'),
                    SettingsChoice(
                      value: BorderColor.lightGray,
                      label: 'Light gray',
                    ),
                    SettingsChoice(value: BorderColor.light, label: 'Light'),
                  ],
                ),
              ),
            _section(
              'Response',
              SettingsChoicePicker(
                selected: RemotePrefs.speed,
                onSelected: (v) => setState(() => RemotePrefs.speed = v),
                choices: const [
                  SettingsChoice(value: ResponseSpeed.normal, label: 'Normal'),
                  SettingsChoice(value: ResponseSpeed.fast, label: 'Fast'),
                  SettingsChoice(
                    value: ResponseSpeed.fastest,
                    label: 'Fastest',
                  ),
                ],
              ),
            ),
            _panel(
              SettingsCard(
                children: [
                  SettingsSwitchTile(
                    title: const Text('Haptics'),
                    value: RemotePrefs.haptics,
                    onChanged: (v) => setState(() => RemotePrefs.haptics = v),
                  ),
                  SettingsSwitchTile(
                    title: const Text('xD key'),
                    subtitle: 'Hold 500ms to type xD',
                    value: RemotePrefs.xdKey,
                    onChanged: (v) => setState(() => RemotePrefs.xdKey = v),
                  ),
                  SettingsSwitchTile(
                    title: const Text('Return to letters after symbol'),
                    value: RemotePrefs.returnToLetters,
                    onChanged: (v) =>
                        setState(() => RemotePrefs.returnToLetters = v),
                  ),
                  SettingsSwitchTile(
                    title: const Text('Extended keyboard'),
                    subtitle:
                        'Numbers, symbols, and punctuation sit above the letter keys',
                    value: RemotePrefs.extendNumbers,
                    onChanged: (v) =>
                        setState(() => RemotePrefs.extendNumbers = v),
                  ),
                ],
              ),
            ),
            _section(
              'Pointer',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensitivity',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AmlTheme.inkOf(context),
                    ),
                  ),
                  Slider(
                    value: RemotePrefs.pointerSensitivity.clamp(0.4, 2.4),
                    min: 0.4,
                    max: 2.4,
                    onChanged: (v) =>
                        setState(() => RemotePrefs.pointerSensitivity = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickConnection(ConnectionMode mode) async {
    if (mode == RemotePrefs.connectionMode) return;
    setState(() => RemotePrefs.connectionMode = mode);
    await RemoteBridge.stop();
  }

  Widget _panel(Widget child) {
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: child);
  }

  Widget _section(String title, Widget child) {
    return _panel(
      SettingsCard(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AmlTheme.inkOf(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}
