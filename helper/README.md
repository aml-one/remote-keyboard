# Remote Keyboard desktop helper

BLE central that injects keyboard and mouse reports from the Android app.

## Platforms

| Artifact | Target |
|---|---|
| Windows x64 | native `cargo build --release` |
| Ubuntu x64 | `x86_64-unknown-linux-gnu` |
| macOS Apple Silicon | `aarch64-apple-darwin` |
| macOS Intel | `x86_64-apple-darwin`, **macOS 11.7** (`MACOSX_DEPLOYMENT_TARGET=11.7`) |

From the product root:

```powershell
.\helper\build.ps1 -Target windows
```

On a Mac (Intel or Apple Silicon), keep the floor at 11.7:

```bash
export MACOSX_DEPLOYMENT_TARGET=11.7
cargo build --release
```

## Linux uinput

```bash
sudo cp 99-aml-remote-keyboard.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

macOS: grant Accessibility to the helper in System Settings → Privacy.
