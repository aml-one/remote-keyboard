import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/key_layout.dart';
import 'package:remotekeyboard/core/palettes.dart';
import 'package:remotekeyboard/core/prefs.dart';
import 'package:remotekeyboard/widgets/remote_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('xD HID reports are unshifted x then Shift+d', () {
    final steps = xdKeyReports();
    expect(steps, hasLength(2));
    expect(steps[0].hid, Hid.x);
    expect(steps[0].modifiers, 0);
    expect(steps[1].hid, Hid.d);
    expect(steps[1].modifiers, Hid.leftShift);
    final withCtrl = xdKeyReports(modifiers: Hid.leftCtrl | Hid.leftShift);
    expect(withCtrl[0].modifiers, Hid.leftCtrl);
    expect(withCtrl[1].modifiers, Hid.leftCtrl | Hid.leftShift);
  });

  test('QWERTY first row is qwertyuiop', () {
    final page = lettersPage(azerty: false, xd: true);
    expect(page.rows.first.map((k) => k.label).join(), 'qwertyuiop');
    expect(page.rows.last.any((k) => k.kind == KeyKind.space), isTrue);
    expect(page.rows.last.any((k) => k.kind == KeyKind.xd), isTrue);
  });

  test('AZERTY first row is azertyuiop', () {
    final page = lettersPage(azerty: true, xd: false);
    expect(page.rows.first.map((k) => k.label).join(), 'azertyuiop');
    expect(page.rows.first.first.hid, Hid.q);
    expect(page.rows[1].first.hid, Hid.a);
    expect(page.rows[2][1].hid, Hid.z);
  });

  test('fastest fire-and-forget taps, others wait', () {
    expect(ResponseSpeed.fastest.fireAndForget, isTrue);
    expect(ResponseSpeed.fast.fireAndForget, isFalse);
    expect(ResponseSpeed.normal.fireAndForget, isFalse);
  });

  test('every appearance has a palette', () {
    for (final appearance in KeyboardAppearance.values) {
      final p = paletteFor(appearance);
      expect(p.foreground, isNotNull);
    }
  });

  test('landscape split letter rows fill their half', () {
    final page = lettersPage(azerty: true, xd: true);
    final split = splitLetters(page);
    final leftTop = split.left.first;
    expect(leftTop.length, 5);
    expect(RemoteKeyGrid.rowPads(leftTop).trail, greaterThan(0));
    expect(RemoteKeyGrid.rowPads(leftTop, fillRow: true), (lead: 0, trail: 0));
    expect(
      RemoteKeyGrid.rowPads(split.right.last, fillRow: true),
      (lead: 0, trail: 0),
    );
  });

  test('landscape split keeps both halves', () {
    final page = lettersPage(azerty: false, xd: true);
    final split = splitLetters(page);
    expect(split.left.first, isNotEmpty);
    expect(split.right.first, isNotEmpty);
    expect(split.left.length, 3);
    expect(split.right.length, 3);
    expect(
      split.left.any((row) => row.any((k) => k.kind == KeyKind.space)),
      isFalse,
    );
    expect(
      split.left.any((row) => row.any((k) => k.kind == KeyKind.symbols)),
      isFalse,
    );
  });

  test('appearance and size cycle wrap', () {
    expect(
      RemotePrefs.stepEnum(
        KeyboardAppearance.values,
        KeyboardAppearance.graphite,
        1,
      ),
      KeyboardAppearance.purple,
    );
    expect(
      RemotePrefs.stepEnum(
        KeyboardAppearance.values,
        KeyboardAppearance.purple,
        -1,
      ),
      KeyboardAppearance.graphite,
    );
    expect(
      RemotePrefs.stepEnum(KeyboardSize.values, KeyboardSize.larger, 1),
      KeyboardSize.normal,
    );
    expect(
      RemotePrefs.stepEnum(HomeLayout.values, HomeLayout.keyboard, 1),
      HomeLayout.mouse,
    );
  });

  test('symbols page matches MessageMe ?123, with =\\< for more symbols', () {
    final page = symbolsPage();
    final abc = page.rows
        .expand((row) => row)
        .where((k) => k.kind == KeyKind.abc)
        .toList();
    expect(abc, hasLength(1));
    expect(page.rows[1].map((k) => k.label).join(), r'@#$_&-+()/');
    final punct = page.rows[2];
    expect(punct.map((k) => k.label).join(), r'''=\<*"':;!?⌫''');
    expect(punct.first.kind, KeyKind.moreSymbols);
    expect(punct.last.kind, KeyKind.backspace);
    expect(punct.first.flex, 1);
    expect(punct.last.flex, 2);
    expect(punct.where((k) => k.label == ';' || k.label == '!' || k.label == '?').every((k) => k.flex == 1), isTrue);
  });

  test('more-symbols page matches MessageMe and returns with ?123', () {
    final page = symbolsMorePage();
    expect(page.rows[0].map((k) => k.label).join(), '~`|•√π÷×<>');
    expect(page.rows[1].map((k) => k.label).join(), '£¢€¥^°={}\\');
    expect(page.rows[2].first.kind, KeyKind.symbols);
    expect(page.rows[2].first.label, '?123');
    expect(page.rows[2].last.kind, KeyKind.backspace);
  });

  test('extended number layout includes Del left of punctuation', () {
    final rows = numberLayoutRows();
    expect(rows, hasLength(3));
    expect(rows[0].map((k) => k.label).join(), '1234567890');
    expect(rows[1].map((k) => k.label).join(), r'@#$_&-+()/');
    expect(rows[2].map((k) => k.label).join(), r'''Del=\<*"':;!?''');
    expect(rows[2].first.kind, KeyKind.delete);
    expect(rows[2].first.hid, Hid.delete);
    expect(rows[2].first.flex, 2);
    expect(rows[2].fold<double>(0, (n, k) => n + k.flex), 10);
    expect(rows[2].any((k) => k.kind == KeyKind.backspace), isFalse);
    expect(rows[2].any((k) => k.kind == KeyKind.moreSymbols), isTrue);
  });

  test('extended more layout keeps Del and swaps to the second page', () {
    final rows = numberLayoutRows(more: true);
    expect(rows[2].first.kind, KeyKind.delete);
    expect(rows[2][1].label, '?123');
    expect(rows[2].first.flex, 2);
    expect(rows[2].fold<double>(0, (n, k) => n + k.flex), 10);
    expect(rows[2].any((k) => k.kind == KeyKind.backspace), isFalse);
  });

  test('extended letters hide the symbols toggle', () {
    final page = lettersPage(
      azerty: false,
      xd: true,
      hideSymbols: true,
    );
    expect(
      page.rows.expand((row) => row).any((k) => k.kind == KeyKind.symbols),
      isFalse,
    );
  });

  test('Larger keys are 25% taller than Normal', () {
    expect(KeyboardSize.larger.keyHeight, KeyboardSize.normal.keyHeight * 1.25);
  });

  test('Dark gray border sits between black and gray', () {
    final dark = borderPaint(BorderColor.darkGray);
    final gray = borderPaint(BorderColor.gray);
    final black = borderPaint(BorderColor.black);
    expect(dark.computeLuminance(), greaterThan(black.computeLuminance()));
    expect(dark.computeLuminance(), lessThan(gray.computeLuminance()));
  });

  test('keyBorderSide follows enabled, color, and thick settings', () async {
    SharedPreferences.setMockInitialValues({
      'border': true,
      'borderThick': true,
      'borderColor': 'mint',
    });
    await RemotePrefs.load();
    final side = keyBorderSide();
    expect(side.width, 2.0);
    expect(side.color, borderPaint(BorderColor.mint));
  });

  test('QWERTY home row is centered under the 10-key row', () {
    final qwerty = lettersPage(azerty: false, xd: true).rows[1];
    expect(qwerty.map((k) => k.label).join(), 'asdfghjkl');
    expect(qwertyHomeRowGutters(qwerty), (lead: 5, trail: 5));
    final azerty = lettersPage(azerty: true, xd: false).rows[1];
    expect(azerty.map((k) => k.label).join(), 'qsdfghjklm');
    expect(qwertyHomeRowGutters(azerty), isNull);
  });

  test('backspace is last, two keys wide, and the row fills to the right', () {
    for (final azerty in [false, true]) {
      final page = lettersPage(azerty: azerty, xd: true);
      final row = page.rows[2];
      expect(row.first.kind, KeyKind.shift);
      expect(row.last.kind, KeyKind.backspace);
      expect(row.last.flex, 2);
      expect(
        row.where((k) => k.kind == KeyKind.letter).every((k) => k.flex == 1),
        isTrue,
      );
      final used = row.fold<double>(0, (sum, k) => sum + k.flex);
      expect(used, 10);
    }
    final azerty = lettersPage(azerty: true, xd: false);
    expect(azerty.rows[2].first.flex, 2);
    final punct = symbolsPage().rows[2];
    expect(punct.last.kind, KeyKind.backspace);
    expect(punct.last.flex, 2);
    expect(punct.first.kind, KeyKind.moreSymbols);
  });

  test('ABC, ?123, and Enter stay the same width; space takes leftover', () {
    KeySpec of(List<KeySpec> row, KeyKind kind) =>
        row.firstWhere((k) => k.kind == kind);

    double used(List<KeySpec> row) =>
        row.fold<double>(0, (sum, k) => sum + k.flex);

    for (final page in [
      lettersPage(azerty: true, xd: true),
      lettersPage(azerty: false, xd: false),
      symbolsPage(),
      symbolsMorePage(),
    ]) {
      final row = page.rows.last;
      expect(of(row, KeyKind.enter).flex, kActionKeyFlex);
      expect(used(row), 10);
      final toggle = row.where(
        (k) => k.kind == KeyKind.symbols || k.kind == KeyKind.abc,
      );
      if (toggle.isNotEmpty) {
        expect(toggle.first.flex, kActionKeyFlex);
        expect(toggle.first.flex, of(row, KeyKind.enter).flex);
      }
    }
  });

  test('landscape ;!? stay letter-wide like vbn', () {
    final letters = splitLetters(lettersPage(azerty: true, xd: true));
    final symbols = splitLetters(symbolsPage());
    final vbn = letters.right.last
        .where((k) => k.kind == KeyKind.letter)
        .toList();
    expect(vbn.map((k) => k.label).join(), 'vbn');
    expect(vbn.every((k) => k.flex == 1), isTrue);
    final punct = symbols.right.last;
    expect(punct.map((k) => k.label).join(), ';!?⌫');
    expect(
      punct.where((k) => k.kind != KeyKind.backspace).every((k) => k.flex == 1),
      isTrue,
    );
    expect(punct.last.flex, 2);
    expect(letters.right.last.last.flex, 2);
    expect(RemoteKeyGrid.rowPads(letters.right.last, fillRow: true), (lead: 0, trail: 0));
    expect(RemoteKeyGrid.rowPads(punct, fillRow: true), (lead: 0, trail: 0));
  });

  testWidgets('root back is ignored; settings back returns home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PopScope(
          canPop: false,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('settings')),
                    ),
                  );
                },
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('home'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('home'), findsOneWidget);

    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  test('letter rows have no digit hints', () {
    final page = lettersPage(azerty: false, xd: true);
    expect(page.rows.expand((row) => row).every((k) => k.hint == null), isTrue);
  });

  test('modifier strip is Tab Esc then Ctrl Alt Win', () {
    expect(modifierStrip().map((k) => k.label).toList(), [
      'Tab',
      'Esc',
      'Ctrl',
      'Alt',
      'Win',
    ]);
  });

  test('wide modifier strip adds Cut Copy Paste as Ctrl chords', () {
    final keys = modifierStrip(clipboard: true);
    expect(keys.map((k) => k.label).toList(), [
      'Tab',
      'Esc',
      'Ctrl',
      'Alt',
      'Win',
      'Cut',
      'Copy',
      'Paste',
    ]);
    final paste = keys.last;
    expect(paste.kind, KeyKind.shortcut);
    expect(paste.hid, Hid.v);
    expect(paste.mod, Hid.leftCtrl);
    expect(clipboardStrip().map((k) => k.label).toList(), [
      'Cut',
      'Copy',
      'Paste',
    ]);
  });

  test('Tab and Esc are not single-letter shift keys', () {
    for (final key in modifierStrip().take(2)) {
      expect(key.isShiftedLetter, isFalse);
      expect(key.label, isNot(key.label.toUpperCase()));
    }
  });
}
