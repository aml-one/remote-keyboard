import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/landscape_fit.dart';
import '../core/palettes.dart';
import '../core/prefs.dart';
import '../core/trackpad_gestures.dart';
import '../core/trackpad_waves.dart';
import '../services/remote_bridge.dart';
import 'trackpad_waves.dart';

class RemoteTrackpad extends StatefulWidget {
  const RemoteTrackpad({
    super.key,
    required this.palette,
    this.height = 140,
    this.showMiddle = true,
    this.haptics = true,
    this.header,
    this.showButtons = true,
    this.buttonMaxWidth,
    this.mouseButtons,
    this.onContactDown,
    this.onContactUp,
    this.onMovement,
    this.waveField,
    this.embedWaves = true,
    this.surfaceRadius,
  });

  final KeyPalette palette;
  final double? height;
  final bool showMiddle;
  final bool haptics;
  final Widget? header;
  final bool showButtons;

  /// Keep L/M/R at this width (centered) when the pad grows wider.
  final double? buttonMaxWidth;
  final ValueNotifier<int>? mouseButtons;
  final VoidCallback? onContactDown;
  final VoidCallback? onContactUp;
  final VoidCallback? onMovement;
  final TrackpadWaveField? waveField;

  /// Landscape paints waves on the keyboard stack so grow cannot freeze them.
  final bool embedWaves;

  /// When set, the pad surface tweens to this radius (grown top corners).
  final BorderRadius? surfaceRadius;

  @override
  State<RemoteTrackpad> createState() => _RemoteTrackpadState();
}

class _RemoteTrackpadState extends State<RemoteTrackpad> {
  final TrackpadGestures _g = TrackpadGestures();
  TrackpadWaveField? _ownedWaves;
  Timer? _hold;
  Timer? _pendingClick;
  ValueNotifier<int>? _ownedButtons;

  TrackpadWaveField get _waves => widget.waveField ?? _ownedWaves!;

  ValueNotifier<int> get _hwButtons => widget.mouseButtons ?? _ownedButtons!;

  double get _gain =>
      RemotePrefs.pointerSensitivity.clamp(0.4, 2.4) *
      TrackpadGestures.pointerScale;

  @override
  void initState() {
    super.initState();
    if (widget.mouseButtons == null) {
      _ownedButtons = ValueNotifier<int>(0);
    }
    if (widget.waveField == null) {
      _ownedWaves = TrackpadWaveField();
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _pendingClick?.cancel();
    if (_hwButtons.value != 0) {
      _hwButtons.value = 0;
      RemoteBridge.sendMouse();
    }
    _ownedButtons?.dispose();
    _dispatch(_g.cancelAll());
    _ownedWaves?.active.clear();
    _ownedWaves?.fading.clear();
    super.dispose();
  }

  void _dispatch(List<TrackpadCmd> cmds) {
    for (final cmd in cmds) {
      switch (cmd.kind) {
        case TrackpadCmdKind.mouse:
          RemoteBridge.sendMouse(
            buttons: cmd.buttons | _hwButtons.value,
            dx: cmd.dx,
            dy: cmd.dy,
            wheel: cmd.wheel,
          );
        case TrackpadCmdKind.haptic:
          if (widget.haptics) HapticFeedback.selectionClick();
        case TrackpadCmdKind.scheduleHold:
          _hold?.cancel();
          _hold = Timer(TrackpadGestures.holdDelay, () {
            if (!mounted) return;
            _dispatch(_g.holdFired());
          });
        case TrackpadCmdKind.cancelHold:
          _hold?.cancel();
          _hold = null;
        case TrackpadCmdKind.scheduleClick:
          _pendingClick?.cancel();
          _pendingClick = Timer(TrackpadGestures.pendingClick, () {
            if (!mounted) return;
            _dispatch(_g.clickFired());
          });
        case TrackpadCmdKind.cancelClick:
          _pendingClick?.cancel();
          _pendingClick = null;
        case TrackpadCmdKind.tapFlash:
        case TrackpadCmdKind.doubleTapFlash:
          break;
      }
    }
  }

  void _onDown(PointerDownEvent e) {
    widget.onContactDown?.call();
    final at = e.position;
    _waves.down(e.pointer, at);
    _dispatch(_g.down(e.pointer, at, DateTime.now()));
    if (_g.usingForMove) widget.onMovement?.call();
  }

  void _onMove(PointerMoveEvent e) {
    final at = e.position;
    _waves.move(e.pointer, at);
    _dispatch(_g.move(e.pointer, at, DateTime.now(), _gain));
    if (_g.usingForMove) widget.onMovement?.call();
  }

  void _onUp(PointerEvent e) {
    _waves.move(e.pointer, e.position);
    final cmds = _g.up(e.pointer, DateTime.now());
    var flash = WaveFlash.lift;
    for (final cmd in cmds) {
      if (cmd.kind == TrackpadCmdKind.tapFlash) flash = WaveFlash.tap;
      if (cmd.kind == TrackpadCmdKind.doubleTapFlash) {
        flash = WaveFlash.doubleTap;
      }
    }
    _waves.up(e.pointer, flash: flash);
    _dispatch(cmds);
    widget.onContactUp?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final expand = widget.height == null;
    final surface = _surface(p, expand);
    if (!widget.showButtons) {
      return expand ? surface : SizedBox(height: widget.height, child: surface);
    }
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (expand)
          Expanded(child: surface)
        else
          SizedBox(height: widget.height, child: surface),
        const SizedBox(height: 8),
        TrackpadMouseButtons(
          palette: p,
          showMiddle: widget.showMiddle,
          haptics: widget.haptics,
          held: _hwButtons,
          maxWidth: widget.buttonMaxWidth,
        ),
      ],
    );
  }

  Widget _surface(KeyPalette p, bool expand) {
    final radius =
        widget.surfaceRadius ?? BorderRadius.circular(kLandscapePadRadius);
    final side = keyBorderSide();
    return AnimatedContainer(
      duration: kLandscapePadGrowAnim,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: p.key,
        borderRadius: radius,
        border: side.style == BorderStyle.none
            ? null
            : Border.fromBorderSide(side),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            child: Center(
              child: Icon(
                Icons.touch_app_rounded,
                size: expand ? 56 : 28,
                color: p.foreground.withValues(alpha: 0.28),
              ),
            ),
          ),
          if (widget.embedWaves)
            Positioned.fill(
              child: IgnorePointer(
                child: TrackpadWaves(field: _waves, palette: p),
              ),
            ),
          if (widget.header != null) Positioned.fill(child: widget.header!),
        ],
      ),
    );
  }
}

class TrackpadMouseButtons extends StatelessWidget {
  const TrackpadMouseButtons({
    super.key,
    required this.palette,
    required this.held,
    this.showMiddle = true,
    this.haptics = true,
    this.maxWidth,
    this.stretchSides = false,
  });

  final KeyPalette palette;
  final ValueNotifier<int> held;
  final bool showMiddle;
  final bool haptics;
  final double? maxWidth;

  /// Landscape grow: L and R fill leftover width; M stays collapsed size.
  final bool stretchSides;

  void _down(int button) {
    if (held.value & button != 0) return;
    held.value |= button;
    if (haptics) HapticFeedback.selectionClick();
    RemoteBridge.sendMouse(buttons: held.value);
  }

  void _up(int button) {
    if (held.value & button == 0) return;
    held.value &= ~button;
    RemoteBridge.sendMouse(buttons: held.value);
  }

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return ValueListenableBuilder<int>(
      valueListenable: held,
      builder: (context, mask, _) {
        Widget click(String label, int button) {
          final on = mask & button != 0;
          return _ClickBtn(
            label: label,
            color: on ? p.highlightedKey : p.functionalKey,
            ink: p.foreground,
            onDown: () => _down(button),
            onUp: () => _up(button),
          );
        }

        final middle = showMiddle
            ? (stretchSides
                  ? SizedBox(
                      width: kLandscapeLmrMiddleWidth,
                      child: click('M', TrackpadGestures.middle),
                    )
                  : Expanded(child: click('M', TrackpadGestures.middle)))
            : null;
        final row = SizedBox(
          height: kLandscapeLmrHeight,
          child: Row(
            children: [
              Expanded(child: click('L', TrackpadGestures.left)),
              const SizedBox(width: kLandscapeLmrGap),
              ?middle,
              if (showMiddle) const SizedBox(width: kLandscapeLmrGap),
              Expanded(child: click('R', TrackpadGestures.right)),
            ],
          ),
        );
        if (maxWidth == null) return row;
        return Align(
          alignment: Alignment.center,
          child: SizedBox(width: maxWidth, child: row),
        );
      },
    );
  }
}

class _ClickBtn extends StatelessWidget {
  const _ClickBtn({
    required this.label,
    required this.color,
    required this.ink,
    this.onDown,
    this.onUp,
  });

  final String label;
  final Color color;
  final Color ink;
  final VoidCallback? onDown;
  final VoidCallback? onUp;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kKeyCornerRadius);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: keyBorderSide(),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTapDown: onDown == null ? null : (_) => onDown!(),
        onTapUp: onUp == null ? null : (_) => onUp!(),
        onTapCancel: onUp,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}
