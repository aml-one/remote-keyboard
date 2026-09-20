import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/widgets/trackpad_glyph.dart';

void main() {
  testWidgets('trackpad glyph paints a plate', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TrackpadGlyph(color: Color(0xFFFFFFFF), size: 20),
      ),
    );
    expect(find.byType(TrackpadGlyph), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
