import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/key_layout.dart';
import 'package:remotekeyboard/core/key_repeat.dart';

void main() {
  test('space, backspace, and delete repeat; letters do not', () {
    expect(KeyRepeat.repeats(KeyKind.space), isTrue);
    expect(KeyRepeat.repeats(KeyKind.backspace), isTrue);
    expect(KeyRepeat.repeats(KeyKind.delete), isTrue);
    expect(KeyRepeat.repeats(KeyKind.letter), isFalse);
    expect(KeyRepeat.repeats(KeyKind.enter), isFalse);
  });

  test('repeat is 500ms for 1.5s then 250ms', () {
    expect(KeyRepeat.intervalAt(Duration.zero), KeyRepeat.slow);
    expect(
      KeyRepeat.intervalAt(const Duration(milliseconds: 1499)),
      KeyRepeat.slow,
    );
    expect(
      KeyRepeat.intervalAt(const Duration(milliseconds: 1500)),
      KeyRepeat.fast,
    );
    expect(
      KeyRepeat.intervalAt(const Duration(seconds: 4)),
      KeyRepeat.fast,
    );
    expect(KeyRepeat.slow, const Duration(milliseconds: 500));
    expect(KeyRepeat.fast, const Duration(milliseconds: 250));
  });
}
