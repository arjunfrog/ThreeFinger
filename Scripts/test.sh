#!/bin/sh
# Runs the tests. With only the Command Line Tools installed, SwiftPM can't find Swift Testing on its own.
set -eu
cd "$(dirname "$0")/.."

DEV=/Library/Developer/CommandLineTools/Library/Developer
if [ -d "$DEV/Frameworks/Testing.framework" ]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$DEV/Frameworks" \
        -Xlinker -F -Xlinker "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/Frameworks" \
        -Xlinker -rpath -Xlinker "$DEV/usr/lib"
fi
exec swift test
