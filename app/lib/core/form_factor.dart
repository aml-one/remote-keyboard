/// Phone vs tablet chrome. Connect / disconnect stay on the trackpad.
/// Helper pairing lives in Settings. The old HID+Helper+unlink cluster
/// stays off a phone held landscape.
const kTabletShortestSide = 600.0;

bool isTabletShortestSide(double shortestSide) =>
    shortestSide >= kTabletShortestSide;

/// HID, Helper, and unlink. Hidden on a phone held landscape.
bool showPairingActions({
  required bool landscape,
  required double shortestSide,
}) {
  if (!landscape) return true;
  return isTabletShortestSide(shortestSide);
}
