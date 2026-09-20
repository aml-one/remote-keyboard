import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/form_factor.dart';

void main() {
  test('pairing actions stay on portrait', () {
    expect(
      showPairingActions(landscape: false, shortestSide: 400),
      isTrue,
    );
  });

  test('phone landscape hides pairing actions', () {
    expect(
      showPairingActions(landscape: true, shortestSide: 400),
      isFalse,
    );
  });

  test('tablet landscape keeps pairing actions', () {
    expect(
      showPairingActions(landscape: true, shortestSide: 800),
      isTrue,
    );
    expect(
      showPairingActions(landscape: false, shortestSide: 800),
      isTrue,
    );
  });
}
