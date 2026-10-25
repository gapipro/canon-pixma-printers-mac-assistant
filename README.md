# Canon PIXMA Printers — Mac Assistant

Native macOS maintenance app for Canon PIXMA ink-tank printers over Wi‑Fi (built and tested with **G3010**).

![G3010 Assistant main window](docs/images/app-main.png)

## Features

- **Bonjour discovery** of printers on the local network (`_ipp._tcp`), plus manual IP entry
- **Password-less login** on factory setups: reads the serial over SNMP and uses it as the Remote UI password, then stores it in Keychain
- **Maintenance actions** with option sheets where the printer UI has submenus:
  - Cleaning / Deep Cleaning
  - Print Head Alignment (automatic or print alignment values)
  - Nozzle Check
  - Ink Flush
  - Remaining Ink Notification Settings
  - Bottom Plate Cleaning / Roller Cleaning
  - Power Off (CHMP)
  - Auto Power On/Off
  - Quiet Settings
  - Custom Settings
- **CUPS / Gutenprint path** for cleaning, nozzle check, and head alignment when a matching queue exists (no Remote UI password needed)
- **Printer status** view from Remote UI

## Download

Grab the latest macOS build from [Releases](https://github.com/gapipro/canon-pixma-printers-mac-assistant/releases):

1. Download `G3010-Assistant-macOS-*.zip` and unzip it.
2. Drag **G3010 Assistant** to Applications (or run it from anywhere).
3. First launch: right-click the app → **Open** → **Open** (Gatekeeper blocks unsigned downloads once).
   Or clear quarantine in Terminal: `xattr -cr "/Applications/G3010 Assistant.app"`

The release build is a universal binary (Apple Silicon + Intel), ad‑hoc signed. It is **not** notarized with an Apple Developer ID.

## Requirements

- macOS 14+
- Printer on the same LAN (Wi‑Fi)
- **Local Network** permission on first launch (System Settings → Privacy & Security → Local Network)
- Optional: a CUPS queue with Gutenprint for password-less cleaning / nozzle / align
- Xcode 15+ if you build from source

## Build

Open `G3010Assistant/G3010Assistant.xcodeproj` in Xcode and Run.

`xcodebuild` fails when `xcode-select` points at Command Line Tools. Point it at the full Xcode developer directory:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd G3010Assistant
xcodebuild test -scheme G3010Assistant -destination 'platform=macOS'
xcodebuild build -scheme G3010Assistant -destination 'platform=macOS'
```

## Printer password

On many G3010 printers the factory Remote UI password is the **serial number**. The app reads that serial over public SNMP and tries it automatically. You are only prompted if that fails (custom password).

## Notes

- Not affiliated with Canon. PIXMA and related names are trademarks of their owners.

## License

MIT — see [LICENSE](LICENSE).
