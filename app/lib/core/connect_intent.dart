import 'prefs.dart';

/// Home Connect follows Settings → Connect with. Never HID vs helper guesswork.
bool padConnectUsesHelper(ConnectionMode mode) => mode == ConnectionMode.helper;
