#!/usr/bin/env bash
# Build → sign (Developer ID + Hardened Runtime) → DMG → notarize → staple →
# Sparkle-sign → appcast.xml.
#
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ SPARKLE SIGNING KEY — DO NOT REGENERATE                                    │
# │                                                                            │
# │ Updates are EdDSA-signed with the private key in the login keychain under  │
# │ account "StarlinkInfos" (used by sign_update below). Its public half is    │
# │ embedded in the app as SUPublicEDKey in project.yml:                       │
# │     dfikprsOcAmXXkLq821pg7SpSbr73EIHsSIOTyYeYj8=                          │
# │                                                                            │
# │ NEVER run `generate_keys` again or import a new key into this account, and │
# │ NEVER change SUPublicEDKey. Doing so makes every already-installed app     │
# │ reject all future auto-updates. A backup of the private key lives in       │
# │ .sparkle-tools-backup/eddsa-private-key-backup.txt (gitignored) — move it  │
# │ somewhere durable (password manager) and never commit it.                  │
# └──────────────────────────────────────────────────────────────────────────┘
#
# Usage:   ./Scripts/release.sh <version>
# Example: ./Scripts/release.sh 1.0.0
#
# Reuses Vincent's shared Apple credentials (same account for all Mac apps):
#   - Developer ID Application: Vincent LAURIAT (KFLACS69T9)
#   - notary keychain profile "AppliMacVincentGithub" (apple-id vincent@lauriat.fr)
# If you ever need to recreate the profile:
#   xcrun notarytool store-credentials "AppliMacVincentGithub" \
#     --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
#
# Overridable via env: APP_NAME, SCHEME, PROJECT, SIGNING_IDENTITY, NOTARY_PROFILE
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: $0 <version>   (e.g. $0 1.0.0)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ── Project identity (bootstrap.sh rewrites these when you clone the template) ──
APP_NAME="${APP_NAME:-StarlinkInfos}"      # PRODUCT_NAME / .app bundle name
SCHEME="${SCHEME:-StarlinkInfos}"           # macOS scheme (see project.yml)
PROJECT="${PROJECT:-StarlinkInfos.xcodeproj}"

DMG_SLUG="$(echo "$APP_NAME" | tr -d ' ')"
DMG_VOLNAME="$APP_NAME $VERSION"
RELEASE_DIR="$ROOT/release"
mkdir -p "$RELEASE_DIR"
DMG="$RELEASE_DIR/$DMG_SLUG-$VERSION.dmg"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Vincent LAURIAT (KFLACS69T9)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AppliMacVincentGithub}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

echo "▶︎ Releasing $APP_NAME $VERSION (build $BUILD_NUMBER)"

# 1. Regenerate the Xcode project from project.yml
echo "▶︎ xcodegen generate"
xcodegen generate >/dev/null

# 2. Build Release. CODE_SIGNING_ALLOWED=NO avoids the macOS Sequoia
#    com.apple.provenance xattr that breaks CLI codesign; we sign manually below.
echo "▶︎ xcodebuild Release"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath build \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null
APP="$ROOT/build/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "✗ App not found: $APP" >&2; exit 1; }

# 3. Stage to a clean dir, stripping extended attributes
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
STAGING="$STAGING_DIR/$APP_NAME.app"
ditto --norsrc --noextattr --noacl "$APP" "$STAGING"

# 4. Codesign the app with Hardened Runtime + secure timestamp (retry: Apple TS is flaky)
codesign_ts() {
  local target="$1" i
  for i in 1 2 3 4 5; do
    if codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$target"; then
      return 0
    fi
    echo "  …codesign retry $i/5 (timestamp server) in 5s" >&2
    sleep 5
  done
  echo "✗ codesign failed for $target" >&2
  return 1
}
echo "▶︎ codesign Sparkle.framework nested binaries (deepest first)"
SPARKLE_FW="$STAGING/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
  SPARKLE_VER="$SPARKLE_FW/Versions/B"
  codesign_ts "$SPARKLE_VER/Autoupdate"
  codesign_ts "$SPARKLE_VER/XPCServices/Downloader.xpc"
  codesign_ts "$SPARKLE_VER/XPCServices/Installer.xpc"
  codesign_ts "$SPARKLE_VER/Updater.app"
  codesign_ts "$SPARKLE_FW"
fi

echo "▶︎ codesign (Developer ID, Hardened Runtime)"
codesign_ts "$STAGING"
codesign --verify --strict --deep --verbose=1 "$STAGING"

# 5. Build the DMG with a custom Finder layout.
#    dmgbuild writes the .DS_Store itself, so no Finder AppleScript (it needs
#    Apple Events, which some shells cannot send, and then silently ships a DMG
#    without a layout).
echo "▶︎ build DMG"
DMG_BG="$STAGING_DIR/background.png"
"$ROOT/Scripts/make-dmg-background.swift" "$DMG_BG" >/dev/null

# dmgbuild and its two dependencies, installed once per requirements file into a
# private venv, every wheel checked against its pinned hash.
DMGBUILD_REQS="$ROOT/Scripts/dmgbuild-requirements.txt"
DMGBUILD_VENV="$ROOT/.dmgbuild-venv/$(shasum -a 256 "$DMGBUILD_REQS" | cut -c1-12)"
if [ ! -x "$DMGBUILD_VENV/bin/dmgbuild" ]; then
  echo "▶︎ installing dmgbuild (one-time)"
  rm -rf "$DMGBUILD_VENV"
  python3 -m venv "$DMGBUILD_VENV"
  "$DMGBUILD_VENV/bin/pip" install --quiet --disable-pip-version-check \
    --only-binary=:all: --require-hashes -r "$DMGBUILD_REQS"
fi

# hdiutil detach can fail with "resource busy". Retry, then force.
detach_retry() {
  local mnt="$1" i
  for i in 1 2 3 4 5; do
    if hdiutil detach "$mnt" -quiet; then
      return 0
    fi
    echo "  …hdiutil detach retry $i/5 ($mnt busy) in 2s" >&2
    sleep 2
  done
  hdiutil detach "$mnt" -force -quiet
}
# Detach any volume left mounted by an aborted previous run of this version.
for STALE in "/Volumes/$DMG_VOLNAME" "/Volumes/$DMG_VOLNAME "[0-9]*; do
  if [ -d "$STALE" ]; then
    echo "  …detaching stale volume $STALE" >&2
    detach_retry "$STALE"
  fi
done

rm -f "$DMG"
"$DMGBUILD_VENV/bin/dmgbuild" -s "$ROOT/Scripts/dmg-settings.py" \
  -D app="$STAGING" -D background="$DMG_BG" \
  "$DMG_VOLNAME" "$DMG" 2> >(grep -v "is deprecated" >&2) >/dev/null

# The layout is deterministic now, so its absence is a bug, not a Finder mood.
CHECK_MOUNT="$(hdiutil attach -nobrowse -readonly -noverify -noautoopen "$DMG" | awk -F '\t' 'END {print $NF}')"
LAYOUT_OK=1
for ITEM in .DS_Store .background.png Applications "$APP_NAME.app"; do
  [ -e "$CHECK_MOUNT/$ITEM" ] || { echo "✗ DMG is missing $ITEM" >&2; LAYOUT_OK=0; }
done
codesign --verify --strict --deep "$CHECK_MOUNT/$APP_NAME.app" || LAYOUT_OK=0
detach_retry "$CHECK_MOUNT"
[ "$LAYOUT_OK" = 1 ] || exit 1

# 6. Notarize + staple
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  cat >&2 <<EOF
✗ Notary profile "$NOTARY_PROFILE" not found.
  Create it once (interactive):
    xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
      --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
  The DMG was built and signed at: $DMG (NOT yet notarized).
EOF
  exit 1
fi
echo "▶︎ notarize (this takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
echo "▶︎ staple"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 7. Sign the DMG with the Sparkle EdDSA key and (re)write appcast.xml so the
#    in-app updater (Sparkle 2) can serve this version.
SPARKLE_TOOLS_VERSION="2.9.1"
SPARKLE_TOOLS="$ROOT/.sparkle-tools"
if [ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]; then
  echo "▶︎ fetching Sparkle $SPARKLE_TOOLS_VERSION tools (one-time setup)"
  mkdir -p "$SPARKLE_TOOLS"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_TOOLS_VERSION/Sparkle-$SPARKLE_TOOLS_VERSION.tar.xz" \
    | tar -xJ -C "$SPARKLE_TOOLS"
fi

echo "▶︎ signing $DMG with the Sparkle EdDSA key"
SPARKLE_SIG_LINE="$("$SPARKLE_TOOLS/bin/sign_update" --account "$APP_NAME" "$DMG")"

# Sparkle compares <sparkle:version> against the running app's CFBundleVersion,
# not the marketing version — read the real build number baked into the .app.
APP_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")"

echo "▶︎ writing $ROOT/appcast.xml (sparkle:version=$APP_BUILD_NUMBER)"
PUB_DATE="$(date -R)"
cat > "$ROOT/appcast.xml" <<APPCAST
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$APP_NAME</title>
    <link>https://raw.githubusercontent.com/vincentlauriat/$APP_NAME/master/appcast.xml</link>
    <description>$APP_NAME release feed</description>
    <language>en</language>
    <item>
      <title>v$VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$APP_BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/vincentlauriat/$APP_NAME/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure
        url="https://github.com/vincentlauriat/$APP_NAME/releases/download/v$VERSION/$DMG_SLUG-$VERSION.dmg"
        type="application/octet-stream"
        $SPARKLE_SIG_LINE />
    </item>
  </channel>
</rss>
APPCAST

SIZE="$(du -h "$DMG" | cut -f1 | tr -d ' ')"
echo
echo "✅ Built, signed, notarized, stapled & Sparkle-signed: $(basename "$DMG") ($SIZE)"
echo "✅ appcast.xml written for v$VERSION"
echo
echo "Next steps to publish on GitHub:"
echo "  1. gh release create v$VERSION \"$DMG\" --title \"v$VERSION\" --generate-notes"
echo "  2. git add appcast.xml && git commit -m 'docs: appcast for v$VERSION' && git push"
