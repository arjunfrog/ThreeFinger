#!/bin/sh
# Creates a self-signed code signing certificate in the login keychain.
#
# macOS ties the Accessibility permission to an app's signature. Without a certificate every
# build gets a new ad-hoc signature, so each rebuild silently loses the permission. Signing
# every build with the same certificate keeps it.
#
# Remove it any time with: security delete-identity -c "ThreeFinger Local Signing"
set -eu

NAME="ThreeFinger Local Signing"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=$NAME" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null

/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$NAME" -out "$TMP/identity.p12" -passout pass:threefinger

# -T lets codesign use the key without a keychain password prompt.
security import "$TMP/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P threefinger -T /usr/bin/codesign >/dev/null

echo "Created \"$NAME\" in the login keychain"
