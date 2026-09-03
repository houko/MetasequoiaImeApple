#!/usr/bin/env bash
set -euo pipefail

: "${GH_REPO:?GH_REPO is required}"
: "${TAG_NAME:?TAG_NAME is required}"
: "${SIGNING_ENABLED:?SIGNING_ENABLED is required}"
if [[ ${ASSET_SUFFIX+x} != x ]]; then
    printf '%s\n' "ASSET_SUFFIX is required." >&2
    exit 1
fi

dist_dir=${DIST_DIR:-dist}
case "$SIGNING_ENABLED:$ASSET_SUFFIX" in
    true:)
        release_mode=signed
        opposite_mode=unsigned
        ;;
    false:-unsigned)
        release_mode=unsigned
        opposite_mode=signed
        ;;
    *)
        printf '%s\n' "Release signing mode and asset suffix do not agree." >&2
        exit 1
        ;;
esac

if [[ ! "$TAG_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s\n' "Tag must use the vMAJOR.MINOR.PATCH format." >&2
    exit 1
fi

mode_marker="<!-- metasequoia-release-mode:$release_mode -->"
opposite_marker="<!-- metasequoia-release-mode:$opposite_mode -->"
current_notes=$(gh release view "$TAG_NAME" --repo "$GH_REPO" --json body --jq '.body // ""')
if [[ "$current_notes" == *"$opposite_marker"* ]]; then
    printf '%s\n' "Release $TAG_NAME is already locked to $opposite_mode artifacts; refusing to switch it to $release_mode." >&2
    exit 1
fi

if [[ "$current_notes" != *"$mode_marker"* ]]; then
    release_notes=${RUNNER_TEMP:-${TMPDIR:-/tmp}}/metasequoia-release-notes.md
    {
        if [[ -n "$current_notes" ]]; then
            printf '%s\n\n' "$current_notes"
        fi
        printf '%s\n' "$mode_marker"
        if [[ "$release_mode" == unsigned ]]; then
            printf '%s\n' '> [!WARNING] These macOS artifacts are not Developer ID signed or notarized because release signing credentials were not configured. The asset filenames are marked unsigned.'
        fi
    } > "$release_notes"
    gh release edit "$TAG_NAME" --repo "$GH_REPO" --notes-file "$release_notes"
fi

archive="$dist_dir/MetasequoiaIME-$TAG_NAME-macos-universal$ASSET_SUFFIX.zip"
installer="$dist_dir/MetasequoiaIME-$TAG_NAME-macos-universal$ASSET_SUFFIX.pkg"
for artifact in "$installer" "$installer.sha256" "$archive" "$archive.sha256"; do
    if [[ ! -f "$artifact" ]]; then
        printf 'Release artifact is missing: %s\n' "$artifact" >&2
        exit 1
    fi
done

gh release upload "$TAG_NAME" --repo "$GH_REPO" "$installer" "$installer.sha256" "$archive" "$archive.sha256" --clobber
gh release edit "$TAG_NAME" --repo "$GH_REPO" --draft=false
