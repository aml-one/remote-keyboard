import 'dart:async';

import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/key_layout.dart';
import '../core/key_repeat.dart';
import '../core/landscape_fit.dart';
import '../core/palettes.dart';
import '../core/prefs.dart';
import '../services/remote_bridge.dart';
import 'space_brand.dart';

class RemoteKeyGrid extends StatelessWidget {
  const RemoteKeyGrid({
    super.key,
    required this.rows,
    required this.palette,
    required this.size,
    required this.shift,
    required this.capsLock,
    required this.mods,
    required this.onShift,
    required this.onMod,
    required this.onSymbols,
    required this.onMoreSymbols,
    required this.onAbc,
    required this.onTyped,
    required this.haptics,
    required this.border,
    this.keyHeight,
    this.extendedShade = false,
    this.fillRow = false,
  });

  final List<List<KeySpec>> rows;
  final KeyPalette palette;
  final KeyboardSize size;
  final bool shift;
  final bool capsLock;
  final int mods;
  final VoidCallback onShift;
  final ValueChanged<int> onMod;
  final VoidCallback onSymbols;
  final VoidCallback onMoreSymbols;
  final VoidCallback onAbc;
  final VoidCallback onTyped;
  final bool haptics;
  final bool border;
  final double? keyHeight;
  final bool extendedShade;
  /// Landscape halves pad to a 5-key width so letter-sized keys stay
  /// letter-sized instead of stretching when the row is shorter.
  final bool fillRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 6),
            child: Row(
              children: [
                if (_leadingPad(rows[i], fillRow: fillRow) > 0)
                  Spacer(flex: _leadingPad(rows[i], fillRow: fillRow)),
                for (final key in rows[i])
                  Expanded(
                    flex: _flexUnits(key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _KeyCap(
                        spec: key,
                        palette: palette,
                        size: size,
                        shift: shift,
                        capsLock: capsLock,
                        mods: mods,
                        onShift: onShift,
                        onMod: onMod,
                        onSymbols: onSymbols,
                        onMoreSymbols: onMoreSymbols,
                        onAbc: onAbc,
                        onTyped: onTyped,
                        haptics: haptics,
                        border: border,
                        height: keyHeight,
                        extendedShade: extendedShade,
                      ),
                    ),
                  ),
                if (_trailingPad(rows[i], fillRow: fillRow) > 0)
                  Spacer(flex: _trailingPad(rows[i], fillRow: fillRow)),
              ],
            ),
          ),
      ],
    );
  }

  static int _flexUnits(KeySpec key) => (key.flex * 10).round().clamp(1, 80);

  static bool _isFixedWidthRow(List<KeySpec> row) {
    return row.any(
      (k) =>
          k.kind == KeyKind.space ||
          k.kind == KeyKind.modifier ||
          k.kind == KeyKind.shortcut,
    );
  }

  static int _unusedFlex(List<KeySpec> row, {bool fillRow = false}) {
    if (_isFixedWidthRow(row)) return 0;
    final used = row.fold<int>(0, (sum, key) => sum + _flexUnits(key));
    final cap = fillRow ? 50 : 100;
    return used >= cap ? 0 : cap - used;
  }

  static bool _packToEnd(List<KeySpec> row) {
    if (row.isEmpty) return false;
    // Shift stays on the left and eats leftover width. Do not inset the row.
    if (row.any((k) => k.kind == KeyKind.shift)) return false;
    // Del / =\ stay on the left of the punct row.
    if (row.any(
      (k) => k.kind == KeyKind.delete || k.kind == KeyKind.moreSymbols,
    )) {
      return false;
    }
    if (row.last.kind == KeyKind.backspace) return true;
    const punct = {'.', ',', '?', '!', "'"};
    return row.every((k) => punct.contains(k.label));
  }

  /// Backspace / punct cluster sit on the right. Leftover space is on the left.
  static int _leadingPad(List<KeySpec> row, {bool fillRow = false}) {
    final home = qwertyHomeRowGutters(row);
    if (home != null) return home.lead;
    if (!_packToEnd(row)) return 0;
    return _unusedFlex(row, fillRow: fillRow);
  }

  /// Short letter rows keep key width vs a 10-key row (or a 5-key half).
  static int _trailingPad(List<KeySpec> row, {bool fillRow = false}) {
    final home = qwertyHomeRowGutters(row);
    if (home != null) return home.trail;
    if (_packToEnd(row)) return 0;
    return _unusedFlex(row, fillRow: fillRow);
  }

  static ({int lead, int trail}) rowPads(
    List<KeySpec> row, {
    bool fillRow = false,
  }) {
    return (
      lead: _leadingPad(row, fillRow: fillRow),
      trail: _trailingPad(row, fillRow: fillRow),
    );
  }
}

class _KeyCap extends StatefulWidget {
  const _KeyCap({
    required this.spec,
    required this.palette,
    required this.size,
    required this.shift,
    required this.capsLock,
    required this.mods,
    required this.onShift,
    required this.onMod,
    required this.onSymbols,
    required this.onMoreSymbols,
    required this.onAbc,
    required this.onTyped,
    required this.haptics,
    required this.border,
    this.height,
    this.extendedShade = false,
  });

  final KeySpec spec;
  final KeyPalette palette;
  final KeyboardSize size;
  final bool shift;
  final bool capsLock;
  final int mods;
  final VoidCallback onShift;
  final ValueChanged<int> onMod;
  final VoidCallback onSymbols;
  final VoidCallback onMoreSymbols;
  final VoidCallback onAbc;
  final VoidCallback onTyped;
  final bool haptics;
  final bool border;
  final double? height;
  final bool extendedShade;

  @override
  State<_KeyCap> createState() => _KeyCapState();
}

class _KeyCapState extends State<_KeyCap> {
  static const _xdHold = Duration(milliseconds: 500);
  Timer? _xdTimer;
  Timer? _repeatTimer;
  DateTime? _repeatStarted;

  KeySpec get spec => widget.spec;

  bool get _wide => spec.flex > 1.2 || spec.kind == KeyKind.space;

  bool get _repeats => KeyRepeat.repeats(spec.kind);

  @override
  void dispose() {
    _xdTimer?.cancel();
    _stopRepeat();
    super.dispose();
  }

  void _cancelXd() {
    _xdTimer?.cancel();
    _xdTimer = null;
  }

  void _armXd() {
    _cancelXd();
    _xdTimer = Timer(_xdHold, () {
      _xdTimer = null;
      _tap();
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatStarted = null;
  }

  void _startRepeat() {
    _stopRepeat();
    _repeatStarted = DateTime.now();
    unawaited(_tap());
    _scheduleRepeat();
  }

  void _scheduleRepeat() {
    final started = _repeatStarted;
    if (started == null) return;
    final wait = KeyRepeat.intervalAt(DateTime.now().difference(started));
    _repeatTimer = Timer(wait, () {
      if (_repeatStarted == null || !mounted) return;
      unawaited(_tap());
      _scheduleRepeat();
    });
  }

  Future<void> _tap() async {
    if (widget.haptics) HapticFeedback.selectionClick();
    switch (spec.kind) {
      case KeyKind.shift:
        widget.onShift();
        return;
      case KeyKind.symbols:
        widget.onSymbols();
        return;
      case KeyKind.moreSymbols:
        widget.onMoreSymbols();
        return;
      case KeyKind.abc:
        widget.onAbc();
        return;
      case KeyKind.modifier:
        widget.onMod(spec.mod);
        return;
      case KeyKind.xd:
        for (final step in xdKeyReports(modifiers: widget.mods)) {
          await RemoteBridge.tapKey(step.hid, modifiers: step.modifiers);
        }
        widget.onTyped();
        return;
      case KeyKind.shortcut:
        await RemoteBridge.tapChord(spec.hid, modifiers: spec.mod);
        widget.onTyped();
        return;
      default:
        break;
    }
    if (spec.hid == 0) return;
    var usedMods = widget.mods;
    final shifted = (widget.shift && spec.isShiftedLetter) || spec.withShift;
    if (shifted) usedMods |= Hid.leftShift;
    await RemoteBridge.tapKey(spec.hid, modifiers: usedMods);
    widget.onTyped();
  }

  @override
  Widget build(BuildContext context) {
    final latched =
        spec.kind == KeyKind.shift && widget.shift ||
        spec.kind == KeyKind.modifier && (widget.mods & spec.mod) != 0;
    final fill = latched
        ? widget.palette.highlightedKey
        : spec.kind == KeyKind.enter
        ? widget.palette.primaryKey
        : widget.extendedShade
        ? widget.palette.extendedKey
        : spec.kind == KeyKind.letter || spec.kind == KeyKind.space
        ? widget.palette.key
        : widget.palette.functionalKey;
    final ink = spec.kind == KeyKind.enter
        ? widget.palette.primaryForeground
        : widget.palette.foreground;
    final round = widget.size.roundLetters && !_wide;
    final radius = BorderRadius.circular(round ? 99 : kKeyCornerRadius);
    final height = widget.height ?? widget.size.keyHeight;
    final icon = _icon;
    final space = spec.kind == KeyKind.space;
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: widget.border ? keyBorderSide() : BorderSide.none,
    );
    final label = spec.isShiftedLetter && widget.shift
        ? spec.label.toUpperCase()
        : spec.label;
    final inkWell = InkWell(
      onTap: spec.kind == KeyKind.xd
          ? _cancelXd
          : _repeats
              ? _stopRepeat
              : _tap,
      onTapDown: spec.kind == KeyKind.xd
          ? (_) => _armXd()
          : _repeats
              ? (_) => _startRepeat()
              : null,
      onTapCancel: spec.kind == KeyKind.xd
          ? _cancelXd
          : _repeats
              ? _stopRepeat
              : null,
      customBorder: shape,
      child: Stack(
        children: [
          Center(
            child: space
                ? const SizedBox.shrink()
                : icon != null
                ? Icon(icon, size: height > 46 ? 22 : 20, color: ink)
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: spec.label.length > 2
                          ? (height > 46 ? 14 : 13)
                          : (height > 46 ? 17 : 16),
                      color: ink,
                    ),
                  ),
          ),
          if (spec.kind == KeyKind.modifier &&
              (widget.mods & spec.mod) != 0)
            Positioned(
              top: 5,
              right: 6,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AmlTheme.mint,
                ),
              ),
            ),
        ],
      ),
    );
    final cap = Material(
      color: fill,
      elevation: 0,
      shadowColor: widget.palette.shadow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: inkWell,
    );
    if (!space) {
      return SizedBox(
        height: height,
        child: Semantics(button: true, label: spec.label, child: cap),
      );
    }
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: cap),
          SpaceBrandMark(palette: widget.palette),
        ],
      ),
    );
  }

  IconData? get _icon {
    switch (spec.kind) {
      case KeyKind.shift:
        return widget.capsLock
            ? Icons.keyboard_capslock_rounded
            : Icons.arrow_upward_rounded;
      case KeyKind.backspace:
        return Icons.backspace_outlined;
      case KeyKind.enter:
        return Icons.keyboard_return_rounded;
      default:
        return null;
    }
  }
}
