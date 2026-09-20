import 'package:fake_async/fake_async.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/landscape_fit.dart';
import 'package:remotekeyboard/core/landscape_pad_grow.dart';

void main() {
  test('expanded width covers two letter columns on each side', () {
    const row = 1000.0;
    const pad = kLandscapePadWidth;
    const gaps = kLandscapePadGap * 2;
    final halves = row - pad - gaps;
    expect(
      landscapePadExpandedWidth(row),
      pad + gaps + halves * (2 / 5),
    );
  });

  test('expanded height grows down by one letter row', () {
    expect(
      landscapePadExpandedHeight(collapsedHeight: 200, keyHeight: 50),
      200 + 50 + kLandscapeRowGap,
    );
  });

  test('letter band plus chrome fills available height', () {
    const available = 400.0;
    const space = 48.0;
    final band = landscapeLetterBandHeight(
      availableHeight: available,
      extended: false,
      spaceRowHeight: space,
    );
    expect(
      band +
          landscapeExtendedBlockHeight(false) +
          landscapeBelowLettersHeight(space),
      available,
    );
    expect(
      landscapePadExpandedHeight(collapsedHeight: band, keyHeight: 50),
      greaterThan(band),
    );
  });

  test('middle mouse button keeps the collapsed width when L and R stretch', () {
    expect(
      kLandscapeLmrMiddleWidth,
      (kLandscapePadWidth - kLandscapeLmrGap * 2) / 3,
    );
  });

  test('grown pad top corners match the key radius', () {
    final collapsed = landscapePadSurfaceRadius(expanded: false);
    final grown = landscapePadSurfaceRadius(expanded: true);
    expect(collapsed.topLeft.x, kLandscapePadRadius);
    expect(collapsed.bottomLeft.x, kLandscapePadRadius);
    expect(grown.topLeft.x, kKeyCornerRadius);
    expect(grown.topRight.x, kKeyCornerRadius);
    expect(grown.bottomLeft.x, kLandscapePadRadius);
    expect(grown.bottomRight.x, kLandscapePadRadius);
  });

  test('grow overlay stays at expanded height so the pad can animate', () {
    const band = 200.0;
    const keyH = 50.0;
    expect(
      landscapePadExpandedHeight(collapsedHeight: band, keyHeight: keyH),
      isNot(band),
    );
    expect(kLandscapePadBackdropAlpha, greaterThan(0.18));
    expect(kLandscapePadGrowAnim.inMilliseconds, 280);
  });

  test('landscape chrome insets cover view padding and screen gutters', () {
    final view = EdgeInsets.fromLTRB(47, 12, 47, 24);
    final bleed = landscapePadBackdropBleed(view);
    expect(bleed.left, view.left + kLandscapeScreenGutter);
    expect(bleed.top, view.top);
    expect(bleed.right, view.right + kLandscapeScreenGutter);
    expect(bleed.bottom, view.bottom + kLandscapeScreenGutter);
  });

  test('a quick tap does not grow the pad', () {
    fakeAsync((async) {
      final g = LandscapePadGrow(onChanged: () {});
      g.pointerDown();
      async.elapse(const Duration(milliseconds: 80));
      g.pointerUp();
      expect(g.expanded, isFalse);
      async.elapse(kLandscapePadGrowConfirm);
      expect(g.expanded, isFalse);
    });
  });

  test('movement grows immediately', () {
    fakeAsync((async) {
      final g = LandscapePadGrow(onChanged: () {});
      g.pointerDown();
      g.movement();
      expect(g.expanded, isTrue);
    });
  });

  test('holding 750ms without a click grows the pad', () {
    fakeAsync((async) {
      final g = LandscapePadGrow(onChanged: () {});
      g.pointerDown();
      async.elapse(kLandscapePadGrowConfirm);
      expect(g.expanded, isTrue);
    });
  });

  test('stays large for 3s after lift then shrinks', () {
    fakeAsync((async) {
      final g = LandscapePadGrow(onChanged: () {});
      g.pointerDown();
      g.movement();
      g.pointerUp();
      async.elapse(const Duration(milliseconds: 2999));
      expect(g.expanded, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(g.expanded, isFalse);
    });
  });

  test('collapse button shrinks immediately and ignores the same stroke', () {
    fakeAsync((async) {
      final g = LandscapePadGrow(onChanged: () {});
      g.pointerDown();
      g.movement();
      g.collapseNow();
      expect(g.expanded, isFalse);
      g.movement();
      expect(g.expanded, isFalse);
      g.pointerUp();
      g.pointerDown();
      g.movement();
      expect(g.expanded, isTrue);
    });
  });
}
