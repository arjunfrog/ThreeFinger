# ThreeFinger

A menu bar app that adds three-finger trackpad gestures for media:

| Gesture | Does |
| --- | --- |
| Tap with three fingers | Play or pause |
| Swipe up or down with three fingers | Volume up or down, one step per ~1 cm |
| Swipe left or right with three fingers | Previous or next track |

It sends the same events as the media keys on an Apple keyboard, so it works with
Music, Spotify, browsers and anything else that responds to F7–F9, and the normal
volume overlay appears.

## Download

Get **[ThreeFinger.dmg](https://github.com/arjunfrog/ThreeFinger/releases/latest/download/ThreeFinger.dmg)**
from the latest release. It runs on Apple Silicon and Intel Macs with macOS 13 or later.

1. Open the .dmg and drag ThreeFinger into Applications.
2. Open ThreeFinger. It isn't notarized by Apple, so macOS stops it the first time.
   On macOS 15 or later, go to System Settings > Privacy & Security and click
   **Open Anyway**. On macOS 13 or 14, Control-click the app and choose **Open**.
3. When macOS asks, allow ThreeFinger in System Settings > Privacy & Security >
   Accessibility. It needs this to press media keys.

## Using it

Everything is in the panel under the hand icon in the menu bar. To hide the icon, turn
off **Show in menu bar**. Gestures keep working, and opening ThreeFinger from Spotlight
or Finder drops the panel down again.

The panel also lists any macOS gesture that still uses three fingers, with a button to
the setting that fixes it:

- **Mission Control** and **Swipe between full-screen apps**: change to four fingers
  in Trackpad > More Gestures.
- **Three-finger drag**: turn off in Accessibility > Pointer Control > Trackpad
  Options, or swipes will also drag windows.
- **Look up**: change to Force Click in Trackpad > Point & Click.

## Build from source

Needs macOS 13 or later and the Xcode Command Line Tools.

```sh
./build.sh install    # build, install to /Applications and open it
./build.sh dmg        # build build/ThreeFinger.dmg for Apple Silicon and Intel
./build.sh uninstall  # remove the app, its permission and its settings
Scripts/test.sh       # run the gesture tests
```

The first build creates a certificate called "ThreeFinger Local Signing" in your login
keychain and signs every build with it. macOS ties the Accessibility permission to that
signature, so it survives rebuilds. To remove the certificate:
`security delete-identity -c "ThreeFinger Local Signing"`.

## How it works

`Sources/CMultitouch` loads Apple's private MultitouchSupport framework at runtime
to read raw finger positions from every trackpad, the same way BetterTouchTool and
MiddleClick do. `GestureRecognizer.swift` turns those frames into gestures, and the
distances and timings at the top of that file are the values to change if gestures
feel too sensitive or not sensitive enough.
