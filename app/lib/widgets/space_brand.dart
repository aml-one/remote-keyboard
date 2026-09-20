import 'package:flutter/material.dart';

import '../core/palettes.dart';

/// Still hummingbird + "AmL Remote" on the bottom of the space key.
///
/// Matches AmL Secure Keyboard: `ic_space_bird.png` (full bird with wings),
/// label then bird on one baseline, 10 dp from the left, sitting on the
/// bottom of the key. Painted outside the key clip so wings are not cropped.
class SpaceBrandMark extends StatelessWidget {
  const SpaceBrandMark({super.key, required this.palette});

  final KeyPalette palette;

  static const birdHeight = 13.2;
  static const birdAspect = 1.21;
  static const birdOverlap = -3.0;
  static const asset = 'assets/branding/ic_space_bird.png';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'AmL Remote',
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: palette.spaceMark,
                  decoration: TextDecoration.none,
                ),
              ),
              Transform.translate(
                offset: const Offset(birdOverlap, -1),
                child: Image.asset(
                  asset,
                  width: birdHeight * birdAspect,
                  height: birdHeight,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
