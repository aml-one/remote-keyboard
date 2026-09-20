import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/connect_intent.dart';
import 'package:remotekeyboard/core/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Connect follows Settings helper, not live BLE state', () {
    expect(padConnectUsesHelper(ConnectionMode.helper), isTrue);
  });

  test(
    'Connect follows Settings Bluetooth, even if helper was advertising',
    () {
      expect(padConnectUsesHelper(ConnectionMode.hid), isFalse);
    },
  );

  test('connectionMode migrates lastTransport helper', () async {
    SharedPreferences.setMockInitialValues({'lastTransport': 'helper'});
    await RemotePrefs.load();
    expect(RemotePrefs.connectionMode, ConnectionMode.helper);
  });

  test('connectionMode defaults to Bluetooth HID', () async {
    SharedPreferences.setMockInitialValues({});
    await RemotePrefs.load();
    expect(RemotePrefs.connectionMode, ConnectionMode.hid);
  });
}
