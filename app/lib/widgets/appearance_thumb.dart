import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';

import '../core/palettes.dart';
import '../core/prefs.dart';

/// Mini look tile used in Settings and the live-theme panel.
class AppearanceThumb extends StatelessWidget {
  const AppearanceThumb({
    super.key,
    required this.appearance,
    this.selected = false,
    this.width = 92,
    this.height = 56,
    this.showLabel = true,
    this.onTap,
  });

  final KeyboardAppearance appearance;
  final bool selected;
  final double? width;
  final double height;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(appearance);
    final radius = BorderRadius.circular(16);
    return Material(
      color: p.background,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AmlTheme.violet : AmlTheme.strokeOf(context),
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: showLabel ? 14 : 10,
                decoration: BoxDecoration(
                  color: p.key,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p.foreground.withValues(alpha: 0.12)),
                ),
              ),
              if (showLabel) ...[
                const Spacer(),
                Text(
                  appearanceLabel(appearance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: p.dark ? p.foreground : AmlTheme.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
