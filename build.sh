#!/bin/sh
# ./build.sh            builds build/ThreeFinger.app
# ./build.sh install    builds, installs to /Applications and opens it
# ./build.sh dmg        builds build/ThreeFinger.dmg for sharing, for Apple Silicon and Intel
# ./build.sh uninstall  quits ThreeFinger and removes it, its permission and its settings
set -eu
cd "$(dirname "$0")"

ID=com.arjunar.ThreeFinger
APP=build/ThreeFinger.app
IDENTITY="ThreeFinger Local Signing"

if [ "${1:-}" = "uninstall" ]; then
    pkill -x ThreeFinger 2>/dev/null || true
    # Media keys need the PostEvent permission, which System Settings lists under Accessibility.
    tccutil reset PostEvent "$ID" >/dev/null 2>&1 || true
    tccutil reset Accessibility "$ID" >/dev/null 2>&1 || true
    rm -rf /Applications/ThreeFinger.app "$APP"
    defaults delete "$ID" 2>/dev/null || true
    echo "Uninstalled ThreeFinger"
    exit 0
fi

swift build -c release
BINARY="$(swift build -c release --show-bin-path)/ThreeFinger"

if [ "${1:-}" = "dmg" ]; then
    # SwiftPM can only build one architecture at a time without Xcode, so build Intel separately and merge.
    INTEL="swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build/intel"
    $INTEL
    mkdir -p build
    lipo -create -output build/ThreeFinger-universal "$BINARY" "$($INTEL --show-bin-path)/ThreeFinger"
    BINARY=build/ThreeFinger-universal
fi

[ -f Resources/AppIcon.icns ] || swift Scripts/make-icon.swift Resources/AppIcon.icns

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/ThreeFinger"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# Signing every build with the same certificate keeps the Accessibility permission across rebuilds.
security find-certificate -c "$IDENTITY" >/dev/null 2>&1 || Scripts/make-signing-identity.sh
codesign --force --sign "$IDENTITY" "$APP"
echo "Built $APP"

if [ "${1:-}" = "dmg" ]; then
    STAGE=build/dmg
    rm -rf "$STAGE" build/ThreeFinger.dmg
    mkdir -p "$STAGE"
    # Move rather than copy, so Spotlight doesn't find a second copy of the app.
    mv "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    cp "Resources/Read Me.txt" "$STAGE/"
    hdiutil create -volname ThreeFinger -srcfolder "$STAGE" -format UDZO -quiet build/ThreeFinger.dmg
    rm -rf "$STAGE" build/ThreeFinger-universal
    echo "Built build/ThreeFinger.dmg"
fi

if [ "${1:-}" = "install" ]; then
    pkill -x ThreeFinger 2>/dev/null || true
    rm -rf /Applications/ThreeFinger.app
    # Move rather than copy, so Spotlight only ever finds the installed copy.
    mv "$APP" /Applications/
    open /Applications/ThreeFinger.app
    echo "Installed to /Applications"
fi
