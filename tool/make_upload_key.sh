#!/usr/bin/env sh
# Creates the Android upload key for LumiFX and everything that uses it:
#   ~/lumifx-upload.jks       the keystore. Back it up: losing it means you
#                             cannot update the app without Play's help.
#   ~/lumifx-upload.jks.base64  the same, for the ANDROID_KEYSTORE_BASE64
#                             GitHub secret (the CI then signs the bundle).
#   android/key.properties    so `flutter build appbundle --release` signs
#                             with it on this machine (ignored by git).
# Usage: tool/make_upload_key.sh [path/to/keystore.jks]
# See docs/RELEASE.md § 1.
set -eu

keystore=${1:-$HOME/lumifx-upload.jks}
key_alias=upload
cd "$(dirname "$0")/.."

if [ -e "$keystore" ]; then
  echo "$keystore already exists; not touching it." >&2
  exit 1
fi
if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool not found: install a JDK (it comes with Android Studio)." >&2
  exit 1
fi

printf 'Password for the keystore and the key (at least 6 characters): '
if [ -t 0 ]; then stty -echo; fi
read -r password
if [ -t 0 ]; then stty echo; printf '\n'; fi
if [ "${#password}" -lt 6 ]; then
  echo "The password must be at least 6 characters." >&2
  exit 1
fi

keytool -genkeypair -keystore "$keystore" -storepass "$password" \
  -keypass "$password" -alias "$key_alias" -keyalg RSA -keysize 2048 \
  -validity 10000 -dname "CN=LumiFX upload key, O=LumiFX"
base64 < "$keystore" | tr -d '\n' > "$keystore.base64"

umask 077
cat > android/key.properties <<PROPERTIES
storeFile=$keystore
storePassword=$password
keyAlias=$key_alias
keyPassword=$password
PROPERTIES

cat <<SUMMARY

Keystore:            $keystore   (back it up somewhere safe)
android/key.properties written: local release builds are now signed.

GitHub > Settings > Secrets and variables > Actions > New repository secret:
  ANDROID_KEYSTORE_BASE64    the content of $keystore.base64
  ANDROID_KEYSTORE_PASSWORD  the password you typed
  ANDROID_KEY_ALIAS          $key_alias
  ANDROID_KEY_PASSWORD       the password you typed
With the four secrets in place the CI signs the bundle with this key.
SUMMARY
