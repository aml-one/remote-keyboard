import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum KeyboardLayout { qwerty, azerty }

enum KeyboardAppearance {
  purple,
  white,
  gray,
  pearl,
  mint,
  lightGray,
  seeThrough,
  frostedWhite,
  sky,
  pink,
  amber,
  night,
  violetNight,
  graphite,
}

enum KeyboardSize { normal, larger }

enum ResponseSpeed { normal, fast, fastest }

enum BorderColor { gray, darkGray, white, black, pearl, mint, lightGray, light }

enum HomeLayout { keyboard, mouse }

class RemotePrefs {
  RemotePrefs._();

  static SharedPreferences? _prefs;

  static Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get p {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('RemotePrefs.load() first');
    }
    return prefs;
  }

  static KeyboardLayout get layout =>
      KeyboardLayout.values.byName(p.getString('layout') ?? 'qwerty');
  static set layout(KeyboardLayout v) => p.setString('layout', v.name);

  static KeyboardAppearance get appearance => KeyboardAppearance.values
      .byName(p.getString('appearance') ?? 'graphite');
  static set appearance(KeyboardAppearance v) =>
      p.setString('appearance', v.name);

  static KeyboardSize get size {
    final raw = p.getString('size');
    for (final value in KeyboardSize.values) {
      if (value.name == raw) return value;
    }
    return KeyboardSize.normal;
  }

  static set size(KeyboardSize v) => p.setString('size', v.name);

  static bool get haptics => p.getBool('haptics') ?? true;
  static set haptics(bool v) => p.setBool('haptics', v);

  static ResponseSpeed get speed =>
      ResponseSpeed.values.byName(p.getString('speed') ?? 'normal');
  static set speed(ResponseSpeed v) => p.setString('speed', v.name);

  static bool get digitHints => false;
  static set digitHints(bool v) => p.setBool('digitHints', v);

  static bool get xdKey => p.getBool('xdKey') ?? true;
  static set xdKey(bool v) => p.setBool('xdKey', v);

  static bool get returnToLetters => p.getBool('returnToLetters') ?? true;
  static set returnToLetters(bool v) => p.setBool('returnToLetters', v);

  static bool get borderEnabled => p.getBool('border') ?? true;
  static set borderEnabled(bool v) => p.setBool('border', v);

  static bool get borderThick => p.getBool('borderThick') ?? false;
  static set borderThick(bool v) => p.setBool('borderThick', v);

  static BorderColor get borderColor =>
      BorderColor.values.byName(p.getString('borderColor') ?? 'darkGray');
  static set borderColor(BorderColor v) => p.setString('borderColor', v.name);

  static double get pointerSensitivity => p.getDouble('pointer') ?? 1.0;
  static set pointerSensitivity(double v) => p.setDouble('pointer', v);

  static bool get liveTheme => p.getBool('liveTheme') ?? false;
  static set liveTheme(bool v) => p.setBool('liveTheme', v);

  static HomeLayout get homeLayout =>
      HomeLayout.values.byName(p.getString('homeLayout') ?? 'keyboard');
  static set homeLayout(HomeLayout v) => p.setString('homeLayout', v.name);

  static bool get extendNumbers => p.getBool('extendNumbers') ?? false;
  static set extendNumbers(bool v) => p.setBool('extendNumbers', v);

  static bool get autoReconnect => p.getBool('autoReconnect') ?? true;
  static set autoReconnect(bool v) => p.setBool('autoReconnect', v);

  /// Last started path: `hid` or `helper`.
  static String get lastTransport {
    final raw = p.getString('lastTransport');
    return raw == 'helper' ? 'helper' : 'hid';
  }

  static set lastTransport(String v) =>
      p.setString('lastTransport', v == 'helper' ? 'helper' : 'hid');

  static T stepEnum<T extends Enum>(List<T> all, T current, int delta) {
    final n = all.length;
    final i = all.indexOf(current);
    return all[(i + delta % n + n) % n];
  }
}

extension KeyboardSizeMetrics on KeyboardSize {
  static const _normalHeight = 42.0;

  double get keyHeight => switch (this) {
        KeyboardSize.normal => _normalHeight,
        KeyboardSize.larger => _normalHeight * 1.25,
      };

  bool get roundLetters => false;
}

extension ResponseSpeedMetrics on ResponseSpeed {
  Duration get tapDelay => switch (this) {
        ResponseSpeed.normal => Duration.zero,
        ResponseSpeed.fast => Duration.zero,
        ResponseSpeed.fastest => Duration.zero,
      };
}

Color borderPaint(BorderColor color) => switch (color) {
      BorderColor.gray => const Color(0xFF9E9EA3),
      BorderColor.darkGray => const Color(0xFF636368),
      BorderColor.white => Colors.white,
      BorderColor.black => Colors.black,
      BorderColor.pearl => const Color(0xFFEDE6F5),
      BorderColor.mint => const Color(0xFF5CCBB4),
      BorderColor.lightGray => const Color(0xFFD0D0D5),
      BorderColor.light => const Color(0xFFE8E4F5),
    };

/// Same stroke keys use: off, or the chosen color at 1px / 2px thick.
BorderSide keyBorderSide() {
  if (!RemotePrefs.borderEnabled) return BorderSide.none;
  return BorderSide(
    color: borderPaint(RemotePrefs.borderColor),
    width: RemotePrefs.borderThick ? 2.0 : 1.0,
  );
}
