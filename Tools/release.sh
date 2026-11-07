#!/bin/bash
# One command release: build, sign (Developer ID), notarize, staple, zip + dmg, git tag and GitHub release.
#
# Usage:  ./Tools/release.sh ["release title"]     (bump MARKETING_VERSION in project.yml first)
#   - version comes from project.yml; stops if tag v<version> already exists
#   - release notes = commit subjects since the previous tag
#   - DRY=1 ./Tools/release.sh   builds, signs and notarizes but does not tag or publish
#
# One-time setup: store notarization credentials in the keychain
#   xcrun notarytool store-credentials dev-notary --apple-id <id> --team-id RBU754TFR9
# (profile is per developer account, not per app; override with NOTARY_PROFILE=<name>)
#
set -e
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
TAG="v$VERSION"
TITLE="${1:-$TAG}"
[ -n "$VERSION" ] || { echo "MARKETING_VERSION not found in project.yml"; exit 1; }
if [ -z "$DRY" ]; then
    git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "Tag $TAG already exists: bump MARKETING_VERSION."; exit 1; }
    [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Uncommitted changes: commit them first."; exit 1; }
    git push -q   # the tag must point at a pushed commit
fi

# Shared by all apps of this developer: prefer "dev-notary", fall back to the legacy "winexp-notary".
if [ -z "$NOTARY_PROFILE" ]; then
    if xcrun notarytool history --keychain-profile dev-notary >/dev/null 2>&1; then NOTARY_PROFILE=dev-notary
    else NOTARY_PROFILE=winexp-notary; fi
fi
PROFILE="$NOTARY_PROFILE"
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
[ "$(defaults read "$PWD/$APP/Contents/Info.plist" CFBundleShortVersionString)" = "$VERSION" ] || { echo "Built version differs from project.yml"; exit 1; }
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

[ -z "$DRY" ] || { echo "DRY run: not tagged, not published."; exit 0; }

echo "==> Publishing $TAG"
PREV=$(git describe --tags --abbrev=0 2>/dev/null || true)
NOTES=$(git log ${PREV:+$PREV..}HEAD --no-merges --pretty='- %s' | grep -v '^- Tools/release' || true)
git tag "$TAG"
git push -q origin "$TAG"
gh release create "$TAG" --title "$TITLE" --notes "${NOTES:-Release $VERSION}
- Developer ID signed and notarized" build/CloseAll.dmg build/CloseAll.zip
