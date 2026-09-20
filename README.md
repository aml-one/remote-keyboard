# Remote Keyboard

AmL One World Android app: on-screen keyboard and a compact trackpad that drive a computer over Bluetooth.

- **Package:** `one.aml.remotekeyboard`
- **Client:** Flutter in `app/` (phones and tablets)
- **HID:** the phone can pair as a real Bluetooth keyboard+mouse (no PC app)
- **Helper:** `helper/` BLE receiver for Windows, macOS (Intel 11.7+, Apple Silicon), and Ubuntu

## Build the Android APK

From this directory:

```powershell
.\scripts\build-android.ps1 -Arm64Only
```

Never run a bare `flutter build apk` — that reports v1.0.0 without dart-defines.

## Helper

Windows, Ubuntu, and Mac (Intel from macOS 11.7, Apple Silicon). Tray plus a small waiting/connected window.

```powershell
.\helper\build.ps1 -Target windows
```

On Mac, keep `MACOSX_DEPLOYMENT_TARGET=11.7`. Ubuntu needs the udev rule in `helper/99-aml-remote-keyboard.rules`.
