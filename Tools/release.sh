#!/bin/bash
# Ship a version of MyWriter:
#   make release V=0.1.1
#
# 1. Sets the version in project.yml and commits it
# 2. Builds a Developer ID signed, notarized dmg (make dmg)
# 3. Tags vX.Y.Z and publishes a GitHub Release with the dmg attached
#    (notes are generated from the commits since the last release)
# 4. Signs the dmg with the update key and adds it to appcast.xml, so every
#    installed MyWriter offers the update (Sparkle)
# 5. Installs that same notarized app into /Applications
set -euo pipefail

version="${1:-}"
current=$(grep MARKETING_VERSION project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [[ -z "$version" ]]; then
    echo "Usage: make release V=<version>   (current version: $current)" >&2
    exit 2
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version should look like 1.2.3, got '$version'." >&2
    exit 2
fi
tag="v$version"

# Preflight: everything that could stop us halfway, checked up front.
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Commit or stash your changes first; a release is built from a clean tree." >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || git ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1; then
    echo "$tag already exists. Pick a new version (current: $current)." >&2
    exit 1
fi
gh auth status >/dev/null 2>&1 || { echo "Sign in to GitHub first: gh auth login" >&2; exit 1; }
sign_update=$(find build/SourcePackages/artifacts -path "*Sparkle/bin/sign_update" 2>/dev/null | head -1)
if [[ -z "$sign_update" ]]; then
    xcodebuild -resolvePackageDependencies -project MyWriter.xcodeproj -scheme MyWriter -derivedDataPath build >/dev/null
    sign_update=$(find build/SourcePackages/artifacts -path "*Sparkle/bin/sign_update" | head -1)
fi
[[ -n "$sign_update" ]] || { echo "Couldn't find Sparkle's sign_update tool." >&2; exit 1; }
xcrun notarytool history --keychain-profile MyWriter >/dev/null 2>&1 || {
    echo "Notarization credentials missing. Run: xcrun notarytool store-credentials MyWriter --apple-id <email> --team-id KFY97BH6J8" >&2
    exit 1
}

echo "==> Releasing MyWriter $version (was $current)"

previous_tag=$(git describe --tags --abbrev=0 2>/dev/null || true)

# 1. Version: the marketing version, plus a build number that always goes up.
if [[ "$version" != "$current" ]]; then
    build=$(grep CURRENT_PROJECT_VERSION project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    sed -i '' "s/MARKETING_VERSION: \"$current\"/MARKETING_VERSION: \"$version\"/" project.yml
    sed -i '' "s/CURRENT_PROJECT_VERSION: \"$build\"/CURRENT_PROJECT_VERSION: \"$((build + 1))\"/" project.yml
    git commit -qm "Release $version" project.yml
fi

# 2. Signed, notarized disk image.
make dmg
dmg="dist/MyWriter-$version.dmg"
[[ -f "$dmg" ]] || { echo "Expected $dmg after make dmg." >&2; exit 1; }

# 3. Publish.
git push -q
git tag -a "$tag" -m "MyWriter $version"
git push -q origin "$tag"
gh release create "$tag" "$dmg" --title "MyWriter $version" --generate-notes \
    --notes "Download \`MyWriter-$version.dmg\`, open it, and drag MyWriter to Applications. Signed with Developer ID and notarized by Apple."

# 4. Update feed: sign the dmg with the update key and add it to appcast.xml.
build=$(grep CURRENT_PROJECT_VERSION project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
signed=$("$sign_update" "$dmg")   # sparkle:edSignature="…" length="…"
signature=$(sed -E 's/.*edSignature="([^"]+)".*/\1/' <<<"$signed")
length=$(sed -E 's/.*length="([0-9]+)".*/\1/' <<<"$signed")
notes=$(mktemp)
if [[ -n "$previous_tag" ]]; then
    git log --format=%s "$previous_tag..HEAD" | grep -v '^Release ' > "$notes" || true
else
    echo "First release with automatic updates." > "$notes"
fi
url="https://github.com/brettsmith212/my_writer/releases/download/$tag/MyWriter-$version.dmg"
Tools/appcast.py "$version" "$build" "$url" "$length" "$signature" "$notes"
rm -f "$notes"
git commit -qm "Appcast: MyWriter $version" appcast.xml
git push -q

# 5. Install the official copy.
pkill -x MyWriter 2>/dev/null && sleep 1 || true
mount=$(hdiutil attach -nobrowse -readonly "$dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')
rm -rf /Applications/MyWriter.app
ditto "$mount/MyWriter.app" /Applications/MyWriter.app
hdiutil detach -quiet "$mount"
spctl -a /Applications/MyWriter.app
open /Applications/MyWriter.app

echo "==> MyWriter $version is published and installed."
gh release view "$tag" --json url -q .url
