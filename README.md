# ShiftType

ShiftType is a lightweight macOS menu bar app that cycles through every enabled input method when you tap Shift by itself. Holding Shift while typing or clicking still behaves normally.

Add an app rule when one app should always use one input method. ShiftType applies that method when the app gains focus and ignores Shift-only switching until you leave.

ShiftType works on macOS Ventura 13 or higher.

## Features

- Tap either Shift key by itself to cycle through all enabled input methods.
- Keep normal Shift shortcuts, capital letters, selections, clicks, and scrolling unchanged.
- Lock one input method to any app.
- Launch automatically when you log in.
- No analytics or network access.

## Install

ShiftType currently builds from source. You need Swift 5.9 or newer.

From the ShiftType source directory:

```sh
./bundle.sh
cp -R ShiftType.app /Applications/
open /Applications/ShiftType.app
```

On first launch, allow **Accessibility**. ShiftType uses it to detect the Shift gesture and identify the focused app for app rules.

ShiftType observes key and modifier event types only long enough to distinguish a standalone Shift tap from normal typing. It does not record characters or save keystrokes.

## Usage

1. Enable the input methods you want in macOS System Settings.
2. Tap Shift by itself to move to the next enabled input method.
3. Open **App Rules…** to lock an input method to a specific app.

If another input method or utility already uses Shift alone as a shortcut, disable that shortcut there to avoid double switching.

## Development

Run the gesture self-tests and build the app:

```sh
swift run ShiftTypeSelfTests
swift build
```

Build a release app bundle:

```sh
./bundle.sh
```

The bundle uses an ad-hoc signature by default, so macOS may ask for permissions again after each changed build. Use a stable signing identity to preserve them:

```sh
SHIFTTYPE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./bundle.sh
```

Set `SHIFTTYPE_DEBUG=1` when launching a development build to write bounded diagnostic logs under `~/Library/Logs/ShiftType`.

## License

[MIT](./LICENSE)
