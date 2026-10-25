# G3010 Assistant

Native macOS maintenance app for Canon PIXMA G3010 (Wi‑Fi).

Does not use or decompile Canon Windows software. Protocol notes informed by
https://github.com/pdrgds/pixma-rs (MIT OR Apache-2.0).

## Build

Open `G3010Assistant/G3010Assistant.xcodeproj` in Xcode and Run.

`xcodebuild` fails when `xcode-select` points at Command Line Tools. Point it at the Xcode developer directory:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd G3010Assistant
xcodebuild test -scheme G3010Assistant -destination 'platform=macOS'
xcodebuild build -scheme G3010Assistant -destination 'platform=macOS'
```

## Local Network permission

Discovery browses Bonjour `_ipp._tcp`. On first launch macOS asks for Local Network access. Allow **G3010 Assistant** in System Settings → Privacy & Security → Local Network. The system prompt reads “Find your Canon G3010 printer on the local network.” If access is denied, use Select Printer and enter the printer IP.

## Printer password

The app asks for the Remote UI admin password and stores it in Keychain for that host. There is no built-in password: the default varies by unit and firmware. On many G3010 printers the factory Remote UI password is the serial number on the printer label. If you set a different password during setup, use that one.

## Maintenance actions

Maintenance actions post the captured Remote UI forms in `EndpointMap` (`docs/captures/remote-ui-actions.md`). Power Off shows energy/utility status; this G3010 firmware has no power-off CGI. Auto Power writes the power-save schedule. Quiet Settings restores silent mode off. Remaining Ink Notification resets the ink counter. Custom Settings reads device info.

**Open Remote UI in Safari** opens `http://<printer-host>/` with `NSWorkspace` (the printer’s Remote UI home page) so the action can be run there.
