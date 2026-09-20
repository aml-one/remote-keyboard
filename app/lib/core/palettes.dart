import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';

import 'prefs.dart';

class KeyPalette {
  const KeyPalette({
    required this.background,
    required this.key,
    required this.functionalKey,
    required this.highlightedKey,
    required this.foreground,
    required this.primaryKey,
    required this.primaryForeground,
    required this.shadow,
    required this.glass,
    required this.dark,
    required this.spaceMark,
  });

  final Color background;
  final Color key;
  final Color functionalKey;
  final Color highlightedKey;
  final Color foreground;
  final Color primaryKey;
  final Color primaryForeground;
  final Color shadow;
  final bool glass;
  final bool dark;
  final Color spaceMark;

  /// Slightly off the letter-key fill for the extended number / punctuation bank.
  Color get extendedKey => Color.lerp(key, functionalKey, dark ? 0.4 : 0.55)!;
}

const _darkText = Color(0xFF202124);
const _amlPrimary = Color(0xFF6C5CE7);
const _onPrimary = Color(0xFFFFFFFF);

KeyPalette paletteFor(KeyboardAppearance appearance) {
  const solids = KeyPalette(
    background: Color(0xFFEDEAF8),
    key: Color(0xFFFFFFFF),
    functionalKey: Color(0xFFF0EDF8),
    highlightedKey: Color(0xFFD9D2FF),
    foreground: _darkText,
    primaryKey: _amlPrimary,
    primaryForeground: _onPrimary,
    shadow: Color(0x33000000),
    glass: false,
    dark: false,
    spaceMark: Color(0xFF9E9EA3),
  );
  return switch (appearance) {
    KeyboardAppearance.purple => solids,
    KeyboardAppearance.white => solids.copyWith(
        background: Colors.white,
        key: const Color(0xFFF5F5F7),
        functionalKey: const Color(0xFFE5E5EA),
      ),
    KeyboardAppearance.gray => solids.copyWith(
        background: const Color(0xFFD5D6DC),
        key: const Color(0xFFF8F8FA),
        functionalKey: const Color(0xFFBEC0C8),
      ),
    KeyboardAppearance.pearl => solids.copyWith(
        background: const Color(0xFFF7F4FC),
        key: const Color(0xFFFFFCFF),
        functionalKey: const Color(0xFFEFE8F8),
      ),
    KeyboardAppearance.mint => solids.copyWith(
        background: const Color(0xFFE6F7F2),
        key: const Color(0xFFFAFFFD),
        functionalKey: const Color(0xFFD4EFE8),
        highlightedKey: const Color(0xFFB8E8DC),
      ),
    KeyboardAppearance.lightGray => solids.copyWith(
        background: const Color(0xFFE8E8ED),
        key: const Color(0xFFFBFBFC),
        functionalKey: const Color(0xFFDCDCE2),
      ),
    KeyboardAppearance.seeThrough => solids.copyWith(
        background: const Color(0x66FBFAFF),
        key: const Color(0xCCFFFFFF),
        functionalKey: const Color(0x99EDE9FF),
        glass: true,
      ),
    KeyboardAppearance.frostedWhite => solids.copyWith(
        background: const Color(0xE6FFFFFF),
        key: const Color(0xF2FFFFFF),
        functionalKey: const Color(0xD9F7F5FC),
        glass: true,
      ),
    KeyboardAppearance.sky => solids.copyWith(
        background: const Color(0xFFE8F2FE),
        key: const Color(0xFFF7FBFF),
        functionalKey: const Color(0xFFD4E6FA),
        highlightedKey: const Color(0xFFB7D6F8),
        primaryKey: AmlTheme.sky,
      ),
    KeyboardAppearance.pink => solids.copyWith(
        background: const Color(0xFFFDEAF2),
        key: const Color(0xFFFFF7FA),
        functionalKey: const Color(0xFFF8D4E4),
        highlightedKey: const Color(0xFFF5C0D8),
        primaryKey: AmlTheme.pink,
      ),
    KeyboardAppearance.amber => solids.copyWith(
        background: const Color(0xFFFFF3E0),
        key: const Color(0xFFFFFBF3),
        functionalKey: const Color(0xFFF8E2B8),
        highlightedKey: const Color(0xFFF6D39A),
        primaryKey: AmlTheme.amber,
      ),
    KeyboardAppearance.night => const KeyPalette(
        background: Color(0xFF12182A),
        key: Color(0xFF1E2740),
        functionalKey: Color(0xFF182036),
        highlightedKey: Color(0xFF2A3558),
        foreground: Color(0xFFF2EDF6),
        primaryKey: Color(0xFF7C6FF0),
        primaryForeground: Color(0xFFFFFFFF),
        shadow: Color(0x66000000),
        glass: false,
        dark: true,
        spaceMark: Color(0xFFC5C0D4),
      ),
    KeyboardAppearance.violetNight => const KeyPalette(
        background: Color(0xFF1A1024),
        key: Color(0xFF2A1C3A),
        functionalKey: Color(0xFF231632),
        highlightedKey: Color(0xFF3A2750),
        foreground: Color(0xFFF6EEFA),
        primaryKey: Color(0xFF9B7CF0),
        primaryForeground: Color(0xFFFFFFFF),
        shadow: Color(0x66000000),
        glass: true,
        dark: true,
        spaceMark: Color(0xFFD8C8E8),
      ),
    KeyboardAppearance.graphite => const KeyPalette(
        background: Color(0xFF1C1C1E),
        key: Color(0xFF2C2C2E),
        functionalKey: Color(0xFF3A3A3C),
        highlightedKey: Color(0xFF48484A),
        foreground: Color(0xFFF2F2F7),
        primaryKey: Color(0xFF8E8E93),
        primaryForeground: Color(0xFFFFFFFF),
        shadow: Color(0x66000000),
        glass: false,
        dark: true,
        spaceMark: Color(0xFFC7C7CC),
      ),
  };
}

extension on KeyPalette {
  KeyPalette copyWith({
    Color? background,
    Color? key,
    Color? functionalKey,
    Color? highlightedKey,
    Color? foreground,
    Color? primaryKey,
    Color? primaryForeground,
    Color? shadow,
    bool? glass,
    bool? dark,
    Color? spaceMark,
  }) {
    return KeyPalette(
      background: background ?? this.background,
      key: key ?? this.key,
      functionalKey: functionalKey ?? this.functionalKey,
      highlightedKey: highlightedKey ?? this.highlightedKey,
      foreground: foreground ?? this.foreground,
      primaryKey: primaryKey ?? this.primaryKey,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      shadow: shadow ?? this.shadow,
      glass: glass ?? this.glass,
      dark: dark ?? this.dark,
      spaceMark: spaceMark ?? this.spaceMark,
    );
  }
}

String appearanceLabel(KeyboardAppearance v) => switch (v) {
      KeyboardAppearance.purple => 'Purple',
      KeyboardAppearance.white => 'White',
      KeyboardAppearance.gray => 'Gray',
      KeyboardAppearance.pearl => 'Pearl',
      KeyboardAppearance.mint => 'Mint',
      KeyboardAppearance.lightGray => 'Light gray',
      KeyboardAppearance.seeThrough => 'See-through',
      KeyboardAppearance.frostedWhite => 'Frosted white',
      KeyboardAppearance.sky => 'Sky',
      KeyboardAppearance.pink => 'Pink',
      KeyboardAppearance.amber => 'Amber',
      KeyboardAppearance.night => 'Night',
      KeyboardAppearance.violetNight => 'Violet night',
      KeyboardAppearance.graphite => 'Graphite',
    };

Color appearanceSwatch(KeyboardAppearance v) => paletteFor(v).background;
