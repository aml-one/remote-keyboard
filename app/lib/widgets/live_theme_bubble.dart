import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/palettes.dart';
import '../core/prefs.dart';
import 'appearance_thumb.dart';

/// Drifting home overlay: a tiny bubble that opens a live look panel.
///
/// Position is a [ValueNotifier] so the flying ticker does not rebuild the
/// tap target (a parent setState every frame cancels GestureDetector).
class LiveThemeBubble extends StatefulWidget {
  const LiveThemeBubble({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<LiveThemeBubble> createState() => _LiveThemeBubbleState();
}

class _LiveThemeBubbleState extends State<LiveThemeBubble>
    with SingleTickerProviderStateMixin {
  static const _bubble = 56.0;
  static const _panelW = 300.0;
  static const _panelH = 132.0;

  late final Ticker _ticker;
  final ValueNotifier<Offset> _pos = ValueNotifier(const Offset(24, 96));
  Offset _vel = const Offset(22, 16);
  Duration _lastTick = Duration.zero;
  bool _open = false;
  Size _area = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pos.dispose();
    super.dispose();
  }

  Size get _box =>
      _open ? const Size(_panelW, _panelH) : const Size(_bubble, _bubble);

  void _onTick(Duration elapsed) {
    if (!mounted || _area == Size.zero || _open) {
      _lastTick = elapsed;
      return;
    }
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.08) return;
    var next = _pos.value + _vel * dt;
    var vx = _vel.dx;
    var vy = _vel.dy;
    final maxX = (_area.width - _box.width).clamp(0.0, double.infinity);
    final maxY = (_area.height - _box.height).clamp(0.0, double.infinity);
    if (next.dx <= 0) {
      next = Offset(0, next.dy);
      vx = vx.abs();
    } else if (next.dx >= maxX) {
      next = Offset(maxX, next.dy);
      vx = -vx.abs();
    }
    if (next.dy <= 0) {
      next = Offset(next.dx, 0);
      vy = vy.abs();
    } else if (next.dy >= maxY) {
      next = Offset(next.dx, maxY);
      vy = -vy.abs();
    }
    _vel = Offset(vx, vy);
    if ((next - _pos.value).distanceSquared < 0.01) return;
    _pos.value = next;
  }

  void _clampToArea() {
    final maxX = (_area.width - _box.width).clamp(0.0, double.infinity);
    final maxY = (_area.height - _box.height).clamp(0.0, double.infinity);
    _pos.value = Offset(
      _pos.value.dx.clamp(0, maxX),
      _pos.value.dy.clamp(0, maxY),
    );
  }

  void _notify() {
    HapticFeedback.selectionClick();
    widget.onChanged();
    setState(() {});
  }

  void _turnOff() {
    RemotePrefs.liveTheme = false;
    HapticFeedback.selectionClick();
    widget.onChanged();
  }

  void _stepLook(int delta) {
    RemotePrefs.appearance = RemotePrefs.stepEnum(
      KeyboardAppearance.values,
      RemotePrefs.appearance,
      delta,
    );
    _notify();
  }

  void _stepSize(int delta) {
    RemotePrefs.size = RemotePrefs.stepEnum(
      KeyboardSize.values,
      RemotePrefs.size,
      delta,
    );
    _notify();
  }

  void _stepBorderColor(int delta) {
    RemotePrefs.borderColor = RemotePrefs.stepEnum(
      BorderColor.values,
      RemotePrefs.borderColor,
      delta,
    );
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _area = Size(constraints.maxWidth, constraints.maxHeight);
        return ValueListenableBuilder<Offset>(
          valueListenable: _pos,
          builder: (context, pos, child) {
            final maxX =
                (_area.width - _box.width).clamp(0.0, double.infinity);
            final maxY =
                (_area.height - _box.height).clamp(0.0, double.infinity);
            return Stack(
              children: [
                Positioned(
                  left: pos.dx.clamp(0.0, maxX),
                  top: pos.dy.clamp(0.0, maxY),
                  child: child!,
                ),
              ],
            );
          },
          child: _open ? _panel(context) : _bubbleButton(context),
        );
      },
    );
  }

  Widget _bubbleButton(BuildContext context) {
    final appearance = RemotePrefs.appearance;
    final p = paletteFor(appearance);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _open = true;
            _clampToArea();
          });
        },
        child: Container(
          width: _bubble,
          height: _bubble,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.key,
            border: Border.all(color: AmlTheme.violet, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AmlTheme.violet.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: ClipOval(
            child: AppearanceThumb(
              appearance: appearance,
              selected: true,
              width: _bubble,
              height: _bubble,
              showLabel: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final p = paletteFor(RemotePrefs.appearance);
    final ink = p.dark ? p.foreground : AmlTheme.ink;
    final muted = ink.withValues(alpha: 0.62);
    return Material(
      color: p.glass ? p.key.withValues(alpha: 0.96) : p.key,
      elevation: 10,
      shadowColor: p.shadow,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AmlTheme.violet, width: 1.5),
        ),
        child: SizedBox(
          width: _panelW,
          height: _panelH,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    _arrow(Icons.chevron_left_rounded, ink, () => _stepLook(-1)),
                    Expanded(
                      child: AppearanceThumb(
                        appearance: RemotePrefs.appearance,
                        selected: true,
                        width: null,
                        height: 56,
                      ),
                    ),
                    _arrow(
                      Icons.chevron_right_rounded,
                      ink,
                      () => _stepLook(1),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Turn off live theme',
                      onPressed: _turnOff,
                      icon: Icon(Icons.close_rounded, size: 18, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _arrow(Icons.chevron_left_rounded, ink, () => _stepSize(-1)),
                    Expanded(
                      child: Text(
                        _sizeLabel(RemotePrefs.size),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: ink,
                        ),
                      ),
                    ),
                    _arrow(Icons.chevron_right_rounded, ink, () => _stepSize(1)),
                    const SizedBox(width: 4),
                    _chip(
                      label: 'Border',
                      selected: RemotePrefs.borderEnabled,
                      ink: ink,
                      fill: p.functionalKey,
                      onTap: () {
                        RemotePrefs.borderEnabled = !RemotePrefs.borderEnabled;
                        _notify();
                      },
                    ),
                    if (RemotePrefs.borderEnabled) ...[
                      const SizedBox(width: 4),
                      _arrow(
                        Icons.chevron_left_rounded,
                        ink,
                        () => _stepBorderColor(-1),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: borderPaint(RemotePrefs.borderColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: ink.withValues(alpha: 0.25)),
                        ),
                      ),
                      _arrow(
                        Icons.chevron_right_rounded,
                        ink,
                        () => _stepBorderColor(1),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, Color ink, VoidCallback onTap) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 36),
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: ink),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color ink,
    required Color fill,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? fill : fill.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }

  static String _sizeLabel(KeyboardSize size) => switch (size) {
        KeyboardSize.normal => 'Normal',
        KeyboardSize.larger => 'Larger',
      };
}
