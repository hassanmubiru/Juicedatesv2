#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# generate_keystore.sh
# Run ONCE to create the Android release signing keystore.
# Store the output files securely — losing the keystore means you CANNOT
# push updates to an existing Play Store listing.
# ─────────────────────────────────────────────────────────────────────────────

set -e

KEYSTORE_PATH="android/app/release.keystore"
KEY_ALIAS="juicedates"
VALIDITY_DAYS=10000         # ~27 years

echo "⚠  This script creates your production signing keystore."
echo "   Back up the resulting file and passwords somewhere safe."
echo ""

read -p "Enter keystore password: " -s KS_PASS; echo
read -p "Confirm keystore password: " -s KS_PASS2; echo
if [ "$KS_PASS" != "$KS_PASS2" ]; then echo "Passwords don't match."; exit 1; fi

read -p "Enter key password (or press Enter to reuse keystore password): " -s KEY_PASS; echo
KEY_PASS=${KEY_PASS:-$KS_PASS}

read -p "Your full name: " FULL_NAME
read -p "Organisation (or your name): " ORG
read -p "City: " CITY
read -p "Country code (e.g. UG): " COUNTRY

keytool -genkeypair \
  -keystore "$KEYSTORE_PATH" \
  -storepass "$KS_PASS" \
  -alias "$KEY_ALIAS" \
  -keypass "$KEY_PASS" \
  -keyalg RSA \
  -keysize 4096 \
  -validity $VALIDITY_DAYS \
  -dname "CN=$FULL_NAME, O=$ORG, L=$CITY, C=$COUNTRY"

echo ""
echo "✅  Keystore created at: $KEYSTORE_PATH"
echo ""

# Write key.properties for Gradle (gitignored)
cat > android/key.properties <<EOF
storePassword=$KS_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=release.keystore
EOF

echo "✅  android/key.properties written."
echo ""

# Print base64 for GitHub Actions secret
echo "─── GitHub Actions secret (KEYSTORE_BASE64) ───"
base64 -w 0 "$KEYSTORE_PATH"
echo ""
echo "─────────────────────────────────────────────────"
echo ""
echo "GitHub Actions secrets to set:"
echo "  KEYSTORE_BASE64    → the base64 string above"
echo "  KEYSTORE_PASSWORD  → $KS_PASS"
echo "  KEY_ALIAS          → $KEY_ALIAS"
echo "  KEY_PASSWORD       → $KEY_PASS"
echo "  FIREBASE_APP_ID    → 1:408134384062:android:cfdf27d88d7c75bddf21ef"
echo "  FIREBASE_SERVICE_ACCOUNT → (download from Firebase Console → Project Settings → Service Accounts)"
