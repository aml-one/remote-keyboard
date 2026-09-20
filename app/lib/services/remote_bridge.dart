import 'dart:async';

import 'package:flutter/services.dart';
import 'package:remotekeyboard/core/prefs.dart';

class RemoteStatus {
  const RemoteStatus({
    this.hidAvailable = false,
    this.hidSupported = true,
    this.bleAdvertising = false,
    this.connected = false,
    this.transport = 'none',
    this.deviceName = '',
    this.pairingPin = '',
  });

  final bool hidAvailable;
  final bool hidSupported;
  final bool bleAdvertising;
  final bool connected;
  final String transport;
  final String deviceName;
  final String pairingPin;

  factory RemoteStatus.fromMap(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return RemoteStatus(
      hidAvailable: map['hidAvailable'] == true,
      hidSupported: map['hidSupported'] != false,
      bleAdvertising: map['bleAdvertising'] == true,
      connected: map['connected'] == true,
      transport: (map['transport'] as String?) ?? 'none',
      deviceName: (map['deviceName'] as String?) ?? '',
      pairingPin: (map['pairingPin'] as String?) ?? '',
    );
  }
}

class RemoteBridge {
  RemoteBridge._();
  static const _methods = MethodChannel('one.aml.remotekeyboard/hid');
  static const _events = EventChannel('one.aml.remotekeyboard/events');

  static Stream<RemoteStatus> status() {
    return _events.receiveBroadcastStream().map(RemoteStatus.fromMap);
  }

  static Future<RemoteStatus> getStatus() async {
    return RemoteStatus.fromMap(await _methods.invokeMethod('getStatus'));
  }

  static Future<bool> requestPermissions() async {
    return await _methods.invokeMethod('requestPermissions') == true;
  }

  static Future<bool> startHid() async {
    return await _methods.invokeMethod('startHid') == true;
  }

  static Future<bool> startBle() async {
    return await _methods.invokeMethod('startBle') == true;
  }

  static Future<void> stop() => _methods.invokeMethod('stop');

  static Future<void> keepAwake(bool on) {
    return _methods.invokeMethod('keepAwake', {'on': on});
  }

  static Future<void> sendKeyboard(int modifiers, List<int> keys) {
    return _methods.invokeMethod('sendKeyboard', {
      'modifiers': modifiers,
      'keys': keys,
    });
  }

  static Future<void> tapKey(int hid, {int modifiers = 0}) async {
    if (hid == 0) return;
    final done = _tapNative(hid, modifiers);
    if (_fireAndForgetTaps) {
      unawaited(done);
      return;
    }
    await done;
  }

  static bool get _fireAndForgetTaps {
    try {
      return RemotePrefs.speed.fireAndForget;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _tapNative(int hid, int modifiers) async {
    try {
      await _methods.invokeMethod<void>('tapKey', {
        'hid': hid,
        'modifiers': modifiers,
      });
    } on MissingPluginException {
      await _tapLegacy(hid, modifiers);
    } on PlatformException {
      await _tapLegacy(hid, modifiers);
    }
  }

  static Future<void> _tapLegacy(int hid, int modifiers) async {
    await sendKeyboard(modifiers, [hid]);
    // Always all-keys-up. Leaving Win/Ctrl/Alt in the key-up report sticks
    // them on the host (Win+Q opens Search / Start).
    await sendKeyboard(0, const []);
  }

  static Future<void> sendIdle() async {
    await sendKeyboard(0, const []);
    await sendMouse();
  }

  /// One-shot chord such as Ctrl+C. Always releases modifiers afterward.
  static Future<void> tapChord(int hid, {required int modifiers}) {
    return tapKey(hid, modifiers: modifiers);
  }

  static Future<void> tapSequence(List<int> keys, {int modifiers = 0}) async {
    for (final hid in keys) {
      await tapKey(hid, modifiers: modifiers);
    }
  }

  static Future<void> sendMouse({
    int buttons = 0,
    int dx = 0,
    int dy = 0,
    int wheel = 0,
  }) {
    return _methods.invokeMethod('sendMouse', {
      'buttons': buttons,
      'dx': dx,
      'dy': dy,
      'wheel': wheel,
    });
  }
}
