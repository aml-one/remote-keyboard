import 'package:flutter/painting.dart';

/// Landscape chrome for the extended number bank vs letter rows.
///
/// Keep these in lockstep with `_landscape` in `home_screen.dart`.

const kLandscapeExtendedRowHeight = 34.0;
const kLandscapeModifierHeight = 34.0;
const kLandscapeRowGap = 6.0;
const kLandscapeAfterExtendedGap = 8.0;
const kLandscapeAfterLettersGap = 6.0;
const kLandscapeAfterModifierGap = 6.0;
const kLandscapeLetterRows = 3;
const kLandscapeExtendedRows = 3;
const kPortraitTrackpadHeight = 220.0;
const kPortraitAfterTrackpadGap = 8.0;
const kPortraitAfterExtendedGap = 10.0;
const kPortraitLetterRows = 4;
const kLandscapePadWidth = 200.0;
const kLandscapePadGap = 8.0;
const kLandscapePadGrowAnim = Duration(milliseconds: 280);
const kLandscapePadGrowConfirm = Duration(milliseconds: 750);
const kLandscapePadGrowHold = Duration(milliseconds: 3000);
const kLandscapePadGrowKeyColumns = 2;
const kLandscapePadGrowKeyRows = 1;
const kLandscapePadLetterColumns = 5;
const kLandscapeLmrHeight = 48.0;
const kLandscapeLmrGap = 8.0;

/// Collapsed L/M/R share the 200px pad; M keeps this width when L and R stretch.
const kLandscapeLmrMiddleWidth =
    (kLandscapePadWidth - kLandscapeLmrGap * 2) / 3;
const kLandscapePadBackdropAlpha = 0.32;
const kLandscapePadRadius = 18.0;

/// Letter keys. Grown pad top corners tween to this so they cover key corners.
const kKeyCornerRadius = 10.0;

/// Left/right inset of the landscape keyboard, and extra clearance under the
/// last row (home indicator). Keys sit inside this chrome; the grow dim does not.
const kLandscapeScreenGutter = 8.0;

/// Landscape trackpad-only home: 10px from the screen on every side, on top of
/// the status bar / home indicator / notch insets.
const kLandscapeMouseMargin = 10.0;

EdgeInsets landscapeMouseOnlyPadding(EdgeInsets viewPadding) {
  return EdgeInsets.fromLTRB(
    viewPadding.left + kLandscapeMouseMargin,
    viewPadding.top + kLandscapeMouseMargin,
    viewPadding.right + kLandscapeMouseMargin,
    viewPadding.bottom + kLandscapeMouseMargin,
  );
}

EdgeInsets landscapePadBackdropBleed(EdgeInsets viewPadding) {
  return EdgeInsets.fromLTRB(
    viewPadding.left + kLandscapeScreenGutter,
    viewPadding.top,
    viewPadding.right + kLandscapeScreenGutter,
    viewPadding.bottom + kLandscapeScreenGutter,
  );
}

/// Eight equal keys (Tab…Win plus Cut/Copy/Paste) stay usable from this width.
const kClipboardOnModifierMinWidth = 520.0;
const kClipboardExtraRowBreathe = 12.0;

bool clipboardFitsOnModifierRow(double width) =>
    width >= kClipboardOnModifierMinWidth;

bool clipboardFitsAsExtraRow({
  required double leftover,
  required double keyHeight,
}) {
  return leftover >= keyHeight + kLandscapeRowGap + kClipboardExtraRowBreathe;
}

double landscapeKeyboardNeededHeight({
  required double keyHeight,
  required bool extended,
}) {
  var h =
      _rowsHeight(kLandscapeLetterRows, keyHeight) +
      kLandscapeAfterLettersGap +
      kLandscapeModifierHeight +
      kLandscapeAfterModifierGap +
      keyHeight;
  if (extended) {
    h +=
        _rowsHeight(kLandscapeExtendedRows, kLandscapeExtendedRowHeight) +
        kLandscapeAfterExtendedGap;
  }
  return h;
}

/// Whether the extra number / punctuation bank can sit above the letters
/// without overflowing the landscape keyboard column.
bool landscapeFitsExtended({
  required double availableHeight,
  required double keyHeight,
}) {
  return availableHeight >=
      landscapeKeyboardNeededHeight(keyHeight: keyHeight, extended: true);
}

/// Grow split letter keys into leftover landscape height instead of
/// leaving a dead band above them.
double landscapeSplitKeyHeight({
  required double availableHeight,
  required double minKeyHeight,
  required bool extended,
}) {
  final used = landscapeKeyboardNeededHeight(
    keyHeight: minKeyHeight,
    extended: extended,
  );
  final extra = availableHeight - used;
  if (extra <= 0) return minKeyHeight;
  final grown = minKeyHeight + extra / kLandscapeLetterRows;
  return grown.clamp(minKeyHeight, minKeyHeight + 22);
}

double _rowsHeight(int n, double h) {
  if (n <= 0) return 0;
  return n * h + (n - 1) * kLandscapeRowGap;
}

double portraitKeyboardNeededHeight({
  required double keyHeight,
  required bool extended,
  required bool clipboardRow,
}) {
  var h =
      kPortraitTrackpadHeight +
      kPortraitAfterTrackpadGap +
      keyHeight +
      kLandscapeAfterModifierGap +
      _rowsHeight(kPortraitLetterRows, keyHeight);
  if (clipboardRow) {
    h += keyHeight + kLandscapeRowGap;
  }
  if (extended) {
    h +=
        _rowsHeight(kLandscapeExtendedRows, keyHeight) +
        kPortraitAfterExtendedGap;
  }
  return h;
}

/// Overlay width covering [kLandscapePadGrowKeyColumns] letter keys on each
/// side of the collapsed pad. Letter keys stay put underneath.
double landscapePadExpandedWidth(double rowWidth) {
  const pad = kLandscapePadWidth;
  const gaps = kLandscapePadGap * 2;
  final halves = rowWidth - pad - gaps;
  if (halves <= 0) return pad;
  return pad +
      gaps +
      halves * (kLandscapePadGrowKeyColumns / kLandscapePadLetterColumns);
}

double landscapeExtendedBlockHeight(bool extended) {
  if (!extended) return 0;
  return kLandscapeExtendedRows * kLandscapeExtendedRowHeight +
      (kLandscapeExtendedRows - 1) * kLandscapeRowGap +
      kLandscapeAfterExtendedGap;
}

double landscapeBelowLettersHeight(double spaceRowHeight) {
  return kLandscapeAfterLettersGap +
      kLandscapeModifierHeight +
      kLandscapeAfterModifierGap +
      spaceRowHeight;
}

/// Height of the letter halves (the collapsed pad overlay). Must stay in
/// lockstep with `_landscape`'s Column.
double landscapeLetterBandHeight({
  required double availableHeight,
  required bool extended,
  required double spaceRowHeight,
}) {
  return availableHeight -
      landscapeExtendedBlockHeight(extended) -
      landscapeBelowLettersHeight(spaceRowHeight);
}

/// Grow the collapsed letter-column overlay down by [kLandscapePadGrowKeyRows]
/// letter keys so L/M/R sit on the next row.
///
/// Apply this as a [Positioned] height on the keyboard [Stack] — never as a
/// child of an [Expanded] over the letter band, or the parent max height
/// clamps the grow.
double landscapePadExpandedHeight({
  required double collapsedHeight,
  required double keyHeight,
}) {
  return collapsedHeight +
      kLandscapePadGrowKeyRows * (keyHeight + kLandscapeRowGap);
}

/// Collapsed pad uses 18px all around. Grown, the top corners match the keys
/// so they cover the letter-key corners exactly while the size animates.
BorderRadius landscapePadSurfaceRadius({required bool expanded}) {
  final top = expanded ? kKeyCornerRadius : kLandscapePadRadius;
  return BorderRadius.only(
    topLeft: Radius.circular(top),
    topRight: Radius.circular(top),
    bottomLeft: const Radius.circular(kLandscapePadRadius),
    bottomRight: const Radius.circular(kLandscapePadRadius),
  );
}
