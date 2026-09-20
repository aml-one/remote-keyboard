import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/palettes.dart';
import 'core/prefs.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemotePrefs.load();
  runApp(const RemoteKeyboardApp());
}

class RemoteKeyboardApp extends StatefulWidget {
  const RemoteKeyboardApp({super.key});

  @override
  State<RemoteKeyboardApp> createState() => _RemoteKeyboardAppState();
}

class _RemoteKeyboardAppState extends State<RemoteKeyboardApp> {
  void _reload() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = paletteFor(RemotePrefs.appearance);
    return MaterialApp(
      title: 'Remote Keyboard',
      debugShowCheckedModeBanner: false,
      theme: AmlTheme.light(),
      darkTheme: AmlTheme.dark(),
      themeMode: palette.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: palette.dark
              ? AmlTheme.darkStatusBarOverlay
              : AmlTheme.lightStatusBarOverlay,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(onPrefsChanged: _reload),
    );
  }
}
