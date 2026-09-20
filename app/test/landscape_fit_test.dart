import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/landscape_fit.dart';
import 'package:remotekeyboard/core/prefs.dart';

void main() {
  test('tall landscape keeps the extended bank', () {
    expect(
      landscapeFitsExtended(
        availableHeight: 800,
        keyHeight: KeyboardSize.normal.keyHeight,
      ),
      isTrue,
    );
  });

  test('phone landscape with Larger keys hides the extended bank', () {
    expect(
      landscapeFitsExtended(
        availableHeight: 367,
        keyHeight: KeyboardSize.larger.keyHeight,
      ),
      isFalse,
    );
  });

  test('hiding extended is only while it would overflow', () {
    const phone = 367.0;
    expect(
      landscapeFitsExtended(
        availableHeight: phone,
        keyHeight: KeyboardSize.normal.keyHeight,
      ),
      isTrue,
    );
    expect(
      landscapeKeyboardNeededHeight(
        keyHeight: KeyboardSize.larger.keyHeight,
        extended: false,
      ),
      lessThan(phone),
    );
  });

  test('landscape height includes the gap under Tab Esc Ctrl', () {
    const keyHeight = 42.0;
    final withGap = landscapeKeyboardNeededHeight(
      keyHeight: keyHeight,
      extended: false,
    );
    expect(withGap, 3 * keyHeight + 2 * 6 + 6 + 34 + 6 + keyHeight);
  });

  test('Cut Copy Paste sit on the modifier row when it is wide', () {
    expect(clipboardFitsOnModifierRow(519), isFalse);
    expect(clipboardFitsOnModifierRow(520), isTrue);
    expect(clipboardFitsOnModifierRow(768), isTrue);
  });

  test('Cut Copy Paste get their own row when leftover height allows it', () {
    expect(
      clipboardFitsAsExtraRow(leftover: 40, keyHeight: 42),
      isFalse,
    );
    expect(
      clipboardFitsAsExtraRow(leftover: 80, keyHeight: 42),
      isTrue,
    );
  });

  test('split letter keys grow into leftover height', () {
    final minH = KeyboardSize.normal.keyHeight;
    expect(
      landscapeSplitKeyHeight(
        availableHeight: 500,
        minKeyHeight: minH,
        extended: true,
      ),
      greaterThan(minH),
    );
    expect(
      landscapeSplitKeyHeight(
        availableHeight: 200,
        minKeyHeight: minH,
        extended: true,
      ),
      minH,
    );
  });

  test('landscape trackpad-only keeps 10px outside the system insets', () {
    const view = EdgeInsets.fromLTRB(48, 24, 48, 21);
    expect(
      landscapeMouseOnlyPadding(view),
      const EdgeInsets.fromLTRB(58, 34, 58, 31),
    );
  });
}
