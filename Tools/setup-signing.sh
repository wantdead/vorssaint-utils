#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Creates a stable, self-signed code-signing identity named "Vorssaint Utils
# Signing" in a dedicated keychain. build.sh uses it automatically, giving every
# build the same code signature — so macOS keeps granted permissions
# (Accessibility, Screen Recording) across updates instead of re-prompting.
#
# This identity name keeps its original "Vorssaint Utils Signing" on purpose: it
# is the lookup key build.sh matches, and the released app's designated
# requirement is pinned to this exact certificate. Renaming it would change that
# requirement and drop every user's granted permissions. The name lives only in
# the keychain and codesign output, never in anything the app shows.
#
# The keychain stays locked except while build.sh signs. Its password is random,
# kept in the login keychain with no application trusted to read it, so each
# build asks once before it can sign. Anything else that tries to sign as the
# Developer app, and so borrow the permissions granted to it, meets the same
# prompt. Answer it with Allow, not Always Allow: Always Allow trusts the
# `security` tool, which every program on the Mac can run.
#
# A keychain from an earlier version, locked with the fixed password this script
# used to set, keeps its identity and only has its password replaced, so the
# permissions granted to builds signed with it stay.
#
# Free, offline, and idempotent (re-running is a no-op once a working identity exists).
# It does NOT replace Apple notarization: downloaded builds still show Gatekeeper's
# "unverified developer" prompt on first launch. It only stabilizes the identity.
#
# Maintainers: official releases use the protected release-signing environment.
# Run this only to get the same permission-preserving behavior for local builds.
set -euo pipefail

IDENTITY="Vorssaint Utils Signing"
KC="$HOME/Library/Keychains/vorssaint-signing.keychain-db"
# Where the keychain's password is kept in the login keychain; build.sh reads it
# from the same place.
PASSWORD_SERVICE="Vorssaint signing keychain"
PASSWORD_ACCOUNT="vorssaint-signing"
LEGACY_KCPASS="vorssaint-signing"

# Passwords travel to security(1) on its standard input: an argument would be
# readable by every process of this user for as long as the command runs.
security_quietly() {
    print -r -- "$1" | security -i >/dev/null 2>&1
}

password_is_stored() {
    security find-generic-password -s "$PASSWORD_SERVICE" -a "$PASSWORD_ACCOUNT" >/dev/null 2>&1
}

store_password() {
    security_quietly "add-generic-password -U -s \"$PASSWORD_SERVICE\" -a $PASSWORD_ACCOUNT -T \"\" -j \"Unlocks the Vorssaint signing keychain for build.sh\" -w $1"
}

# Lock on sleep and after ten idle minutes, in case a build is killed before
# it can lock the keychain itself.
protect_keychain() {
    security set-keychain-settings -l -u -t 600 "$KC"
    security lock-keychain "$KC"
}

new_password() {
    openssl rand -hex 32
}

if [[ -f "$KC" ]] && password_is_stored; then
    echo "✓ Signing identity already installed."
    exit 0
fi

if [[ -f "$KC" ]] && security_quietly "unlock-keychain -p $LEGACY_KCPASS \"$KC\""; then
    KCPASS="$(new_password)"
    security_quietly "set-keychain-password -o $LEGACY_KCPASS -p $KCPASS \"$KC\""
    store_password "$KCPASS"
    password_is_stored || {
        echo "✗ The new keychain password could not be stored in the login keychain." >&2
        exit 1
    }
    protect_keychain
    echo "✓ Signing keychain now locks between builds; its identity is unchanged."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
KCPASS="$(new_password)"

openssl req -x509 -newkey rsa:2048 -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -days 3650 -nodes \
    -subj "/CN=$IDENTITY/O=Vorssaint" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" 2>/dev/null
# The PBE and MAC algorithms are named explicitly: the stock /usr/bin/openssl
# is LibreSSL, which rejects OpenSSL 3's -legacy flag, while OpenSSL 3's
# defaults (AES-256, PBKDF2) are newer than what security(1) imports reliably.
# These three are accepted by both and produce the same portable file.
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/id.p12" -passout fd:3 -name "$IDENTITY" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 3<<<"$KCPASS" || {
    echo "✗ openssl pkcs12 could not export the identity." >&2
    exit 1
}

security delete-keychain "$KC" 2>/dev/null || true
security_quietly "create-keychain -p $KCPASS \"$KC\""
security_quietly "unlock-keychain -p $KCPASS \"$KC\""
security_quietly "import \"$WORK/id.p12\" -k \"$KC\" -P $KCPASS -T /usr/bin/codesign"
security_quietly "set-key-partition-list -S apple-tool:,apple:,codesign: -s -k $KCPASS \"$KC\""
EXISTING=$(security list-keychains -d user | sed 's/"//g' | xargs)
security list-keychains -d user -s "$KC" ${=EXISTING}

# Import succeeding is not evidence codesign can sign with it: try it the same
# way build.sh signs, so a broken search list fails here and not as a silent
# ad-hoc fallback three builds later.
probe="$WORK/probe"
cp /bin/echo "$probe"
codesign --force --strip-disallowed-xattrs --sign "$IDENTITY" "$probe" >/dev/null 2>&1 || {
    echo "✗ Identity imported but codesign cannot sign with it; keychain search list may be off." >&2
    exit 1
}
store_password "$KCPASS"
password_is_stored || {
    echo "✗ The keychain password could not be stored in the login keychain." >&2
    exit 1
}
protect_keychain
echo "✓ Created signing identity '$IDENTITY'. Future ./build.sh runs use it automatically."
