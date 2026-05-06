# InDrop

InDrop is a macOS menu bar app for converting dropped WhatsApp/image/PDF files into InDesign-friendly output files.

## Requirements

- macOS 14 or later
- Swift 6 toolchain
- Xcode command line tools

## Build

```sh
swift build
```

To create the distributable app bundle:

```sh
./Scripts/build-app.sh
```

The app bundle is created at:

```text
dist/InDrop.app
```

## Test

```sh
swift test
```

Before shipping UI or packaging changes, also run the manual checklist:

```text
Tests/ManualSmokeChecklist.md
```

## Release Notes

- The marketing version is read from `VERSION`.
- The build number defaults to `1` and can be overridden with `BUILD_NUMBER`.

Example:

```sh
BUILD_NUMBER=42 ./Scripts/build-app.sh
```
