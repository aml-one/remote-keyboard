import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/prefs.dart';
import 'package:remotekeyboard/widgets/live_theme_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('X on the live theme panel turns off the flying bubble', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'liveTheme': true});
    await RemotePrefs.load();
    var notified = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveThemeBubble(onChanged: () => notified++),
        ),
      ),
    );

    expect(RemotePrefs.liveTheme, isTrue);
    await tester.tap(find.byType(InkWell).first);
    await tester.pump();

    await tester.tap(find.byTooltip('Turn off live theme'));
    await tester.pump();

    expect(RemotePrefs.liveTheme, isFalse);
    expect(notified, 1);
  });
}
