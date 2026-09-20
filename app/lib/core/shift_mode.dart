enum ShiftMode { off, once, locked }

const kShiftDoubleTapWindow = Duration(milliseconds: 360);

ShiftMode nextShiftMode({
  required ShiftMode current,
  required DateTime now,
  required DateTime? lastTap,
}) {
  final doubleTap =
      lastTap != null && now.difference(lastTap) <= kShiftDoubleTapWindow;
  if (current == ShiftMode.locked) return ShiftMode.off;
  if (doubleTap) return ShiftMode.locked;
  if (current == ShiftMode.once) return ShiftMode.off;
  return ShiftMode.once;
}
