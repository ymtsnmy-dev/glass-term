# glass-term

`glass-term` is a macOS block-based terminal app.

It keeps real terminal behavior (PTY + `libvterm`) while adding a UI that treats commands and outputs as blocks.

## Features

- Multi-tab terminal sessions
- Block view (command + output grouped together)
- Automatic Raw Mode when alternate screen is active (`vim`, `less`, etc.)
- Copy Stack (copy blocks and keep a queue)
- Theme switching (Default / Glass)
- zsh-based PTY execution

## Requirements

- macOS
- Xcode (this repo is an Xcode project)
- Project path: `glass-term/glass-term.xcodeproj`

Notes:

- The current project setting is `MACOSX_DEPLOYMENT_TARGET = 26.2`
- You need an Xcode version that includes `MacOSX26.2.sdk` (if you keep the current setting)

## Quick Start (Xcode)

1. Clone the repository

```bash
git clone <YOUR_REPO_URL>
cd glass-term
```

2. Open the project in Xcode

```bash
open glass-term/glass-term.xcodeproj
```

3. Update signing settings (first time only)

This project currently contains the original developer Team ID, so builds may fail on other machines unless you change it.

- Select the `glass-term` project in Xcode
- Go to `Targets` -> `glass-term` -> `Signing & Capabilities`
- Change `Team` to your Apple ID / Personal Team
- Keep `Automatically manage signing` enabled (recommended)

4. Run the app

- Scheme: `glass-term`
- Destination: `My Mac`
- Press `Cmd + R`

## Build from CLI (unsigned)

If you just want to build locally, you can disable code signing:

```bash
xcodebuild \
  -project glass-term/glass-term.xcodeproj \
  -scheme glass-term \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/glass-term-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Output app bundle:

- `/tmp/glass-term-derived/Build/Products/Debug/glass-term.app`

## Run Like a Normal macOS App (click the icon)

Yes, this app can be run by clicking its icon like other macOS apps, as long as you have a built `.app` bundle.

### Option A: After building in Xcode

- Build/Run once in Xcode
- In Finder, locate the generated `glass-term.app` (Xcode Products / DerivedData output)
- Drag `glass-term.app` to `/Applications` (optional but recommended)
- Double-click the app icon to launch

### Option B: After CLI build

```bash
open /tmp/glass-term-derived/Build/Products/Debug/glass-term.app
```

You can also drag that `.app` bundle into `/Applications` and launch it from Launchpad/Finder afterward.

## Sharing with Other People (GitHub)

If you want other people to run it by clicking the app icon without building from source, publish a prebuilt `.app` in GitHub Releases.

Recommended flow:

1. Build a Release app bundle
2. Zip the `.app` bundle
3. Upload the zip to GitHub Releases
4. Users download, unzip, drag to `/Applications`, and double-click the icon

Example Release build (unsigned):

```bash
xcodebuild \
  -project glass-term/glass-term.xcodeproj \
  -scheme glass-term \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/glass-term-release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Important:

- Unsigned apps may trigger Gatekeeper warnings on other Macs
- For smooth distribution, use code signing + notarization before publishing

## Tests

```bash
xcodebuild \
  -project glass-term/glass-term.xcodeproj \
  -scheme glass-term \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/glass-term-derived-test \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Dependencies

- No extra package installation is required
- `libvterm` is vendored in this repository (`glass-term/Vendor/libvterm`)

## Project Structure (excerpt)

- `glass-term/glass-term.xcodeproj`: Xcode project
- `glass-term/glass-term`: app code (SwiftUI)
- `Terminal/PTY`: PTY layer
- `Terminal/Emulator`: terminal emulation layer (`libvterm` wrapper)
- `Terminal/Screen`: rendering/session control
- `Block`: block abstraction / copy features
- `glass-term/glass-termTests`: unit tests

## Troubleshooting

### `No signing certificate "Mac Development" found`

This happens because the project contains a fixed Team ID. Change the Team in Xcode, or use `CODE_SIGNING_ALLOWED=NO` for local CLI builds.

### `MacOSX26.2.sdk` not found

The project is currently set to deployment target `26.2`. Use a compatible Xcode version, or lower the deployment target in the project/target settings.
