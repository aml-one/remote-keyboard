import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';

import '../core/key_layout.dart';
import '../core/landscape_fit.dart';
import '../core/landscape_pad_grow.dart';
import '../core/palettes.dart';
import '../core/prefs.dart';
import '../core/shift_mode.dart';
import '../core/trackpad_waves.dart';
import '../services/remote_bridge.dart';
import '../widgets/live_theme_bubble.dart';
import '../widgets/remote_keyboard.dart';
import '../widgets/trackpad.dart';
import '../widgets/trackpad_glyph.dart';
import '../widgets/trackpad_waves.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onPrefsChanged});

  final VoidCallback? onPrefsChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RemoteStatus _status = const RemoteStatus();
  ShiftMode _shift = ShiftMode.off;
  DateTime? _lastShiftTap;
  int _mods = 0;
  bool _symbols = false;
  bool _symbolsMore = false;
  late final LandscapePadGrow _padGrow;
  late final ValueNotifier<int> _padMouseButtons;
  final TrackpadWaveField _padWaves = TrackpadWaveField();

  @override
  void initState() {
    super.initState();
    _padGrow = LandscapePadGrow(
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _padMouseButtons = ValueNotifier<int>(0);
    RemoteBridge.getStatus().then((s) {
      if (mounted) setState(() => _status = s);
    });
    RemoteBridge.status().listen((s) {
      if (!mounted) return;
      final becameConnected = s.connected && !_status.connected;
      setState(() {
        _status = s;
        if (becameConnected) {
          _mods = 0;
          _shift = ShiftMode.off;
        }
      });
      RemoteBridge.keepAwake(s.connected);
      if (becameConnected) {
        if (s.transport == 'hid' || s.transport == 'helper') {
          RemotePrefs.lastTransport = s.transport;
        }
        RemoteBridge.sendIdle();
      }
    });
    _maybeAutoReconnect();
  }

  @override
  void dispose() {
    _padGrow.dispose();
    _padMouseButtons.dispose();
    super.dispose();
  }

  KeyPalette get _palette => paletteFor(RemotePrefs.appearance);

  String get _connectionLabel {
    if (_status.connected) {
      final name = _status.deviceName.isEmpty ? 'computer' : _status.deviceName;
      return '${_status.transport == 'hid' ? 'HID' : 'Helper'} · $name';
    }
    if (_status.bleAdvertising) {
      return 'Waiting for helper — open Remote Keyboard on the computer';
    }
    if (_status.hidAvailable) {
      if (_status.pairingPin.isNotEmpty) {
        return 'PIN ${_status.pairingPin} — confirm it on the phone popup, then Connect';
      }
      return 'Waiting — tap AOW Keyboard on the PC, then Pair';
    }
    return 'Not connected';
  }

  Future<void> _connectHid() async {
    RemotePrefs.lastTransport = 'hid';
    await RemoteBridge.requestPermissions();
    final ok = await RemoteBridge.startHid();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This phone cannot act as a Bluetooth HID keyboard. Use helper pairing.',
          ),
        ),
      );
    } else if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'On Windows tap AOW Keyboard. Confirm the matching PIN on this phone, then Connect.',
          ),
        ),
      );
    }
  }

  Future<void> _connectHelper() async {
    RemotePrefs.lastTransport = 'helper';
    await RemoteBridge.requestPermissions();
    await RemoteBridge.startBle();
  }

  Future<void> _maybeAutoReconnect() async {
    if (!RemotePrefs.autoReconnect) return;
    final current = await RemoteBridge.getStatus();
    if (!mounted || current.connected) return;
    if (RemotePrefs.lastTransport == 'helper') {
      if (current.bleAdvertising) return;
      await RemoteBridge.requestPermissions();
      if (!mounted) return;
      await RemoteBridge.startBle();
      return;
    }
    if (current.hidAvailable) return;
    await RemoteBridge.requestPermissions();
    if (!mounted) return;
    await RemoteBridge.startHid();
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    widget.onPrefsChanged?.call();
    if (mounted) setState(() {});
  }

  void _toggleMouseLayout() {
    setState(() {
      RemotePrefs.homeLayout = RemotePrefs.homeLayout == HomeLayout.mouse
          ? HomeLayout.keyboard
          : HomeLayout.mouse;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final landscape = orientation == Orientation.landscape;
        if (!landscape) _padGrow.reset();
        if (RemotePrefs.homeLayout == HomeLayout.mouse) {
          return _mouseOnly(landscape: landscape);
        }
        return landscape ? _landscape() : _portrait();
      },
    );
  }

  Widget _shell({required Widget child, bool landscape = false}) {
    final p = _palette;
    final dark = p.dark;
    return PopScope(
      canPop: false,
      child: AnnotatedRegion(
        value: dark
            ? AmlTheme.darkStatusBarOverlay
            : AmlTheme.lightStatusBarOverlay,
        child: Scaffold(
          backgroundColor: p.background,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              const SettingsAmbientBackground(),
              landscape ? _landscapeChrome(child) : _portraitChrome(child),
              if (RemotePrefs.liveTheme)
                Positioned.fill(
                  child: LiveThemeBubble(
                    onChanged: () {
                      widget.onPrefsChanged?.call();
                      setState(() {});
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portraitChrome(Widget child) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 8,
        ),
        child: child,
      ),
    );
  }

  Widget _landscapeChrome(Widget child) {
    // Full-bleed: keys inset themselves. The grow dim must reach the screen
    // edges, including the status bar and home indicator.
    return child;
  }

  Widget _connectionDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _status.connected ? AmlTheme.mint : AmlTheme.amber,
      ),
    );
  }

  Color get _chromeMuted => _palette.foreground.withValues(alpha: 0.55);

  Widget _iconBtn({
    required String tooltip,
    IconData? icon,
    Widget? glyph,
    required VoidCallback onPressed,
    bool muted = false,
  }) {
    final p = _palette;
    final size = muted ? 32.0 : 40.0;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
      onPressed: onPressed,
      icon:
          glyph ??
          Icon(
            icon!,
            color: muted ? _chromeMuted : p.foreground,
            size: muted ? 20 : 22,
          ),
    );
  }

  Widget _chromeTextBtn({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: _chromeMuted,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _connectOrDisconnect() {
    if (_status.connected) {
      return _iconBtn(
        tooltip: 'Disconnect',
        icon: Icons.link_off_rounded,
        muted: true,
        onPressed: RemoteBridge.stop,
      );
    }
    return _chromeTextBtn(
      label: 'Connect',
      onPressed: _status.hidSupported ? _connectHid : _connectHelper,
    );
  }

  Widget _layoutToggleBtn() {
    final mouseHome = RemotePrefs.homeLayout == HomeLayout.mouse;
    return _iconBtn(
      tooltip: mouseHome ? 'Keyboard' : 'Trackpad',
      icon: mouseHome ? Icons.keyboard_rounded : null,
      glyph: mouseHome ? null : TrackpadGlyph(color: _chromeMuted, size: 20),
      muted: true,
      onPressed: _toggleMouseLayout,
    );
  }

  /// Status on top; trackpad and settings in the bottom corners.
  Widget _padChrome({VoidCallback? onCollapse}) {
    final p = _palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 3, 2, 4),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IgnorePointer(child: _connectionDot()),
                const SizedBox(width: 6),
                Expanded(
                  child: IgnorePointer(
                    child: Text(
                      _connectionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p.foreground,
                        fontSize: 13,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                _connectOrDisconnect(),
              ],
            ),
          ),
          Positioned(left: 0, bottom: 0, child: _layoutToggleBtn()),
          if (onCollapse != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: _iconBtn(
                  tooltip: 'Shrink trackpad',
                  icon: Icons.close_fullscreen_rounded,
                  muted: true,
                  onPressed: onCollapse,
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _iconBtn(
              tooltip: 'Settings',
              icon: Icons.settings_rounded,
              muted: true,
              onPressed: _openSettings,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleShift() {
    final now = DateTime.now();
    setState(() {
      _shift = nextShiftMode(current: _shift, now: now, lastTap: _lastShiftTap);
      _lastShiftTap = now;
    });
  }

  void _toggleMod(int m) {
    final next = _mods ^ m;
    setState(() => _mods = next);
    if (next == 0) {
      RemoteBridge.sendIdle();
    }
  }

  void _onTyped() {
    _consumeShiftOnce();
    if (_mods == 0) return;
    setState(() => _mods = 0);
  }

  void _consumeShiftOnce() {
    if (_shift != ShiftMode.once) return;
    setState(() => _shift = ShiftMode.off);
  }

  Widget _grid(
    List<List<KeySpec>> rows, {
    double? keyHeight,
    bool extendedShade = false,
    bool fillRow = false,
  }) {
    return RemoteKeyGrid(
      rows: rows,
      palette: _palette,
      size: RemotePrefs.size,
      shift: _shift != ShiftMode.off,
      capsLock: _shift == ShiftMode.locked,
      mods: _mods,
      onShift: _toggleShift,
      onMod: _toggleMod,
      onSymbols: () => setState(() {
        if (_symbolsMore) {
          _symbolsMore = false;
          _symbols = true;
        } else {
          _symbols = !_symbols;
          if (!_symbols) _symbolsMore = false;
        }
      }),
      onMoreSymbols: () => setState(() {
        _symbols = true;
        _symbolsMore = !_symbolsMore;
      }),
      onAbc: () => setState(() {
        _symbols = false;
        _symbolsMore = false;
      }),
      onTyped: _onTyped,
      haptics: RemotePrefs.haptics,
      border: RemotePrefs.borderEnabled,
      keyHeight: keyHeight,
      extendedShade: extendedShade,
      fillRow: fillRow,
    );
  }

  Widget _mouseOnly({required bool landscape}) {
    final p = _palette;
    final margin = landscape
        ? landscapeMouseOnlyPadding(MediaQuery.viewPaddingOf(context))
        : const EdgeInsets.fromLTRB(8, 0, 8, 0);
    return _shell(
      landscape: landscape,
      child: Padding(
        padding: margin,
        child: SizedBox.expand(
          child: RemoteTrackpad(
            palette: p,
            height: null,
            header: _padChrome(),
            haptics: RemotePrefs.haptics,
            mouseButtons: _padMouseButtons,
          ),
        ),
      ),
    );
  }

  KeyPage _activePage({required bool extend}) {
    if (extend) {
      return lettersPage(
        azerty: RemotePrefs.layout == KeyboardLayout.azerty,
        xd: RemotePrefs.xdKey,
        hideSymbols: true,
      );
    }
    if (_symbolsMore) return symbolsMorePage();
    if (_symbols) return symbolsPage();
    return lettersPage(
      azerty: RemotePrefs.layout == KeyboardLayout.azerty,
      xd: RemotePrefs.xdKey,
      hideSymbols: false,
    );
  }

  Widget _portrait() {
    final p = _palette;
    final extend = RemotePrefs.extendNumbers;
    return _shell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyH = RemotePrefs.size.keyHeight;
            final wide = clipboardFitsOnModifierRow(constraints.maxWidth);
            final leftover =
                constraints.maxHeight -
                portraitKeyboardNeededHeight(
                  keyHeight: keyH,
                  extended: extend,
                  clipboardRow: false,
                );
            final extraRow =
                !wide &&
                clipboardFitsAsExtraRow(leftover: leftover, keyHeight: keyH);
            return Column(
              children: [
                Expanded(
                  child: RemoteTrackpad(
                    palette: p,
                    height: null,
                    header: _padChrome(),
                    haptics: RemotePrefs.haptics,
                    mouseButtons: _padMouseButtons,
                  ),
                ),
                const SizedBox(height: kPortraitAfterTrackpadGap),
                _grid([modifierStrip(clipboard: wide)]),
                const SizedBox(height: kLandscapeAfterModifierGap),
                if (extraRow) ...[
                  _grid([clipboardStrip()]),
                  const SizedBox(height: kLandscapeRowGap),
                ],
                if (extend) ...[
                  _grid(
                    numberLayoutRows(more: _symbolsMore),
                    extendedShade: true,
                  ),
                  const SizedBox(height: kPortraitAfterExtendedGap),
                ],
                _grid(_activePage(extend: extend).rows),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _landscape() {
    return _shell(
      landscape: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chrome = landscapePadBackdropBleed(
            MediaQuery.viewPaddingOf(context),
          );
          final availableH = constraints.maxHeight - chrome.vertical;
          final availableW = constraints.maxWidth - chrome.horizontal;
          final minH = RemotePrefs.size.keyHeight;
          final wantExtend = RemotePrefs.extendNumbers;
          final extend =
              wantExtend &&
              landscapeFitsExtended(
                availableHeight: availableH,
                keyHeight: minH,
              );
          final letterH = landscapeSplitKeyHeight(
            availableHeight: availableH,
            minKeyHeight: minH,
            extended: extend,
          );
          final page = _activePage(extend: extend);
          final split = splitLetters(page);
          final left = split.left.where((r) => r.isNotEmpty).toList();
          final right = split.right.where((r) => r.isNotEmpty).toList();
          final clipboardOnRow = clipboardFitsOnModifierRow(availableW);
          final extendedBlock = landscapeExtendedBlockHeight(extend);
          final letterBand = landscapeLetterBandHeight(
            availableHeight: availableH,
            extended: extend,
            spaceRowHeight: minH,
          );
          final grownW = landscapePadExpandedWidth(availableW);
          final grownH = landscapePadExpandedHeight(
            collapsedHeight: letterBand,
            keyHeight: letterH,
          );
          final w = _padGrow.expanded ? grownW : kLandscapePadWidth;
          final h = _padGrow.expanded ? grownH : letterBand;
          return Stack(
            children: [
              Padding(
                padding: chrome,
                child: Column(
                  children: [
                    if (extend) ...[
                      _grid(
                        numberLayoutRows(more: _symbolsMore),
                        keyHeight: kLandscapeExtendedRowHeight,
                        extendedShade: true,
                      ),
                      const SizedBox(height: kLandscapeAfterExtendedGap),
                    ],
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _grid(
                              left,
                              keyHeight: letterH,
                              fillRow: true,
                            ),
                          ),
                          const SizedBox(width: kLandscapePadGap),
                          const SizedBox(width: kLandscapePadWidth),
                          const SizedBox(width: kLandscapePadGap),
                          Expanded(
                            flex: 4,
                            child: _grid(
                              right,
                              keyHeight: letterH,
                              fillRow: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: kLandscapeAfterLettersGap),
                    _grid([
                      modifierStrip(clipboard: clipboardOnRow),
                    ], keyHeight: kLandscapeModifierHeight),
                    const SizedBox(height: kLandscapeAfterModifierGap),
                    _grid([page.rows.last]),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_padGrow.expanded,
                  child: GestureDetector(
                    onTap: _padGrow.collapseNow,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedOpacity(
                      duration: kLandscapePadGrowAnim,
                      curve: Curves.easeOutCubic,
                      opacity: _padGrow.expanded ? 1 : 0,
                      child: ColoredBox(
                        color: AmlTheme.ink.withValues(
                          alpha: kLandscapePadBackdropAlpha,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: chrome.top + extendedBlock,
                left: chrome.left,
                right: chrome.right,
                height: grownH,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedContainer(
                    duration: kLandscapePadGrowAnim,
                    curve: Curves.easeOutCubic,
                    width: w,
                    height: h,
                    clipBehavior: Clip.none,
                    decoration: BoxDecoration(
                      borderRadius: landscapePadSurfaceRadius(
                        expanded: _padGrow.expanded,
                      ),
                      boxShadow: _padGrow.expanded
                          ? [
                              BoxShadow(
                                color: AmlTheme.ink.withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : const [],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        children: [
                          Expanded(
                            child: RemoteTrackpad(
                              key: const ValueKey<String>('landscape-pad'),
                              palette: _palette,
                              height: null,
                              header: _padChrome(
                                onCollapse: _padGrow.expanded
                                    ? _padGrow.collapseNow
                                    : null,
                              ),
                              haptics: RemotePrefs.haptics,
                              showButtons: false,
                              mouseButtons: _padMouseButtons,
                              waveField: _padWaves,
                              embedWaves: false,
                              surfaceRadius: landscapePadSurfaceRadius(
                                expanded: _padGrow.expanded,
                              ),
                              onContactDown: _padGrow.pointerDown,
                              onContactUp: _padGrow.pointerUp,
                              onMovement: _padGrow.movement,
                            ),
                          ),
                          const SizedBox(height: kLandscapeLmrGap),
                          SizedBox(
                            height: kLandscapeLmrHeight,
                            child: TrackpadMouseButtons(
                              palette: _palette,
                              haptics: RemotePrefs.haptics,
                              held: _padMouseButtons,
                              stretchSides: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: TrackpadWaves(
                    field: _padWaves,
                    palette: _palette,
                    useOverlay: false,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
