import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/shift_mode.dart';

void main() {
  final t0 = DateTime(2026, 9, 19, 12);

  test('first tap is one-letter shift', () {
    expect(
      nextShiftMode(current: ShiftMode.off, now: t0, lastTap: null),
      ShiftMode.once,
    );
  });

  test('second tap inside the window locks caps', () {
    expect(
      nextShiftMode(
        current: ShiftMode.once,
        now: t0.add(const Duration(milliseconds: 200)),
        lastTap: t0,
      ),
      ShiftMode.locked,
    );
  });

  test('slow second tap turns one-letter shift off', () {
    expect(
      nextShiftMode(
        current: ShiftMode.once,
        now: t0.add(const Duration(milliseconds: 400)),
        lastTap: t0,
      ),
      ShiftMode.off,
    );
  });

  test('tap on caps lock turns it off', () {
    expect(
      nextShiftMode(
        current: ShiftMode.locked,
        now: t0.add(const Duration(milliseconds: 50)),
        lastTap: t0,
      ),
      ShiftMode.off,
    );
  });
}
