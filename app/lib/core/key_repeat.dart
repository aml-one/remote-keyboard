import 'key_layout.dart';

/// Hold-to-repeat for space, backspace, and delete.
class KeyRepeat {
  static const slow = Duration(milliseconds: 500);
  static const fast = Duration(milliseconds: 250);
  static const speedUpAfter = Duration(milliseconds: 1500);

  static bool repeats(KeyKind kind) {
    return kind == KeyKind.space ||
        kind == KeyKind.backspace ||
        kind == KeyKind.delete;
  }

  /// Interval until the next click after [held] from finger-down.
  static Duration intervalAt(Duration held) {
    return held >= speedUpAfter ? fast : slow;
  }
}
