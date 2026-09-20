import 'dart:async';

import 'landscape_fit.dart';

/// Grows the landscape trackpad over nearby letter keys once the gesture
/// is a move or scroll, not a click.
class LandscapePadGrow {
  LandscapePadGrow({required this.onChanged});

  final void Function() onChanged;

  bool expanded = false;
  int _fingers = 0;
  bool _blockUntilUp = false;
  Timer? _confirm;
  Timer? _hold;

  void pointerDown() {
    _fingers++;
    _hold?.cancel();
    if (_blockUntilUp || expanded || _fingers != 1) return;
    _confirm?.cancel();
    _confirm = Timer(kLandscapePadGrowConfirm, _expand);
  }

  void movement() {
    if (_blockUntilUp || _fingers == 0) return;
    _confirm?.cancel();
    _hold?.cancel();
    _expand();
  }

  void pointerUp() {
    if (_fingers > 0) _fingers--;
    if (_fingers > 0) return;
    _blockUntilUp = false;
    _confirm?.cancel();
    if (!expanded) return;
    _hold?.cancel();
    _hold = Timer(kLandscapePadGrowHold, _collapse);
  }

  void collapseNow() {
    _confirm?.cancel();
    _hold?.cancel();
    _blockUntilUp = _fingers > 0;
    _collapse();
  }

  void reset() {
    _confirm?.cancel();
    _hold?.cancel();
    _fingers = 0;
    _blockUntilUp = false;
    expanded = false;
  }

  void dispose() {
    _confirm?.cancel();
    _hold?.cancel();
  }

  void _expand() {
    if (expanded) return;
    expanded = true;
    onChanged();
  }

  void _collapse() {
    if (!expanded) return;
    expanded = false;
    onChanged();
  }
}
