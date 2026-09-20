import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/trackpad_waves.dart';

void main() {
  test('one and two fingers each keep a ripple', () {
    final field = TrackpadWaveField();
    field.down(1, Offset.zero);
    field.down(2, const Offset(40, 12));
    expect(field.active, hasLength(2));
    expect(field.active[1]!.tone, isNot(field.active[2]!.tone));
    expect(field.busy, isTrue);
  });

  test('move can leave the pad bounds', () {
    final field = TrackpadWaveField();
    field.down(1, const Offset(10, 10));
    field.move(1, const Offset(-40, 280));
    expect(field.active[1]!.pos, const Offset(-40, 280));
  });

  test('lift fades a burst then goes idle', () {
    final field = TrackpadWaveField();
    field.down(1, const Offset(8, 8));
    field.tick(0.1);
    field.up(1);
    expect(field.active, isEmpty);
    expect(field.fading, hasLength(1));
    field.tick(TrackpadWaveField.fadeSeconds + 0.05);
    expect(field.fading, isEmpty);
    expect(field.busy, isFalse);
  });

  test('first finger is always tone 0; a second contact is tone 1', () {
    final field = TrackpadWaveField();
    field.down(1, Offset.zero);
    field.up(1);
    field.down(3, const Offset(4, 4));
    expect(field.active[3]!.tone, 0);
    field.down(4, const Offset(20, 8));
    expect(field.active[3]!.tone, 0);
    expect(field.active[4]!.tone, 1);
  });

  test('tap and double-tap flashes are stored on the burst', () {
    final field = TrackpadWaveField();
    field.down(1, Offset.zero);
    field.up(1, flash: WaveFlash.tap);
    expect(field.fading.single.flash, WaveFlash.tap);
    field.down(2, Offset.zero);
    field.up(2, flash: WaveFlash.doubleTap);
    expect(field.fading.last.flash, WaveFlash.doubleTap);
  });
}
