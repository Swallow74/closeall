#!/bin/bash
# Builds, signs (Developer ID), notarizes and staples CloseAll, then writes build/CloseAll.zip and build/CloseAll.dmg.
#
# One-time setup: store notarization credentials in the keychain
#   xcrun notarytool store-credentials winexp-notary --apple-id <id> --team-id <TEAMID>
# (the profile already exists on this Mac; override with NOTARY_PROFILE=<name>)
#
# Then:  ./Tools/release.sh        (bump MARKETING_VERSION in project.yml first)
# Publish afterwards (see AGENTS.md): git tag, gh release create, upload build/CloseAll.dmg and build/CloseAll.zip
set -e
cd "$(dirname "$0")/.."

PROFILE="${NOTARY_PROFILE:-winexp-notary}"
OUT="build/release"
APP="$OUT/CloseAll.app"

IDENTITY=$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
[ -n "$IDENTITY" ] || { echo "No Developer ID Application certificate in the keychain."; exit 1; }
echo "==> Signing as: $IDENTITY"

rm -rf "$OUT" && mkdir -p "$OUT"
xcodegen generate --spec project.yml >/dev/null
# Release config: the post-build "copy to /Applications" runs only for Debug.
xcodebuild -project CloseAll.xcodeproj -scheme CloseAll -configuration Release \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/dd clean build >/dev/null
cp -R build/dd/Build/Products/Release/CloseAll.app "$APP"
VERSION=$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleShortVersionString)
echo "==> Version $VERSION"

# No nested code (single binary, no frameworks): --deep not needed.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Notarizing (a few minutes)"
ditto -c -k --keepParent "$APP" "$OUT/submit.zip"
xcrun notarytool submit "$OUT/submit.zip" --keychain-profile "$PROFILE" --wait | tee "$OUT/notary.log"
grep -q "status: Accepted" "$OUT/notary.log" || { echo "Notarization failed"; exit 1; }
rm "$OUT/submit.zip"

echo "==> Stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

# zip is what the in-app updater downloads (first .app inside); dmg is for manual installs.
ditto -c -k --keepParent "$APP" build/CloseAll.zip
mkdir "$OUT/dmg" && cp -R "$APP" "$OUT/dmg/" && ln -s /Applications "$OUT/dmg/Applications"
rm -f build/CloseAll.dmg
hdiutil create -volname CloseAll -srcfolder "$OUT/dmg" -ov -format UDZO build/CloseAll.dmg >/dev/null
codesign --sign "$IDENTITY" --timestamp build/CloseAll.dmg

echo "==> Ready: build/CloseAll.zip build/CloseAll.dmg (v$VERSION)"
