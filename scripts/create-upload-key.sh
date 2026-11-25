#!/usr/bin/env bash
# Creates the Google Play upload key and android/key.properties, once.
#
# keytool asks for the password itself; it never appears in this script, the
# shell history or the repository (*.jks and key.properties are git-ignored).
# Back up the .jks and the password somewhere safe (a password manager):
# with Play App Signing a lost upload key can be reset through Play support,
# but it takes days.
set -euo pipefail

cd "$(dirname "$0")/.."
KEYSTORE="${1:-$HOME/keys/monetizer-upload.jks}"
ALIAS=upload

if [[ -e "$KEYSTORE" ]]; then
  echo "A keystore already exists at $KEYSTORE; refusing to overwrite it." >&2
  exit 1
fi
mkdir -p "$(dirname "$KEYSTORE")"

echo "Switch the keyboard to English first: keytool accepts only English letters,"
echo "digits and symbols in the password (an Arabic layout fails with 'Password is not ASCII')."

keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias "$ALIAS" \
  -dname "CN=Monetizer, O=Monetizer, C=EG"
chmod 600 "$KEYSTORE"

read -r -s -p "Type the same keystore password again for key.properties: " PASSWORD
echo
umask 077
cat > android/key.properties <<PROPS
storePassword=$PASSWORD
keyPassword=$PASSWORD
keyAlias=$ALIAS
storeFile=$KEYSTORE
PROPS
unset PASSWORD

echo "Created $KEYSTORE and android/key.properties."
echo "Build: flutter build appbundle --release"
