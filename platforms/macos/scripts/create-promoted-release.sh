#!/usr/bin/env bash
set -euo pipefail

: "${GH_REPO:?GH_REPO is required}"
: "${TARGET_SHA:?TARGET_SHA is required}"
: "${TAG_NAME:?TAG_NAME is required}"

write_output() {
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        printf '%s\n' "$1" >> "$GITHUB_OUTPUT"
    fi
}

if [[ ! "$TARGET_SHA" =~ ^[0-9a-f]{40}$ ]]; then
    printf 'Invalid promoted release commit: %s\n' "$TARGET_SHA" >&2
    exit 1
fi
if [[ ! "$TAG_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Tag must use the vMAJOR.MINOR.PATCH format.\n' >&2
    exit 1
fi

main_sha=$(gh api "repos/$GH_REPO/git/ref/heads/main" --jq .object.sha)
if [[ "$main_sha" != "$TARGET_SHA" ]]; then
    printf 'main advanced before release creation; refusing to tag %s.\n' "$TARGET_SHA" >&2
    exit 1
fi

encoded_version=$(gh api "repos/$GH_REPO/contents/version.txt?ref=$TARGET_SHA" --jq .content)
version=$(printf '%s' "$encoded_version" | base64 --decode)
if [[ "$TAG_NAME" != "v$version" ]]; then
    printf 'Release tag %s does not match version.txt (%s).\n' "$TAG_NAME" "$version" >&2
    exit 1
fi

if ! release_json=$(gh release view "$TAG_NAME" --repo "$GH_REPO" --json isDraft,tagName,targetCommitish 2>&1); then
    gh release create "$TAG_NAME" --repo "$GH_REPO" --target "$TARGET_SHA" --title "$TAG_NAME" \
        --generate-notes --draft
    release_json=$(gh release view "$TAG_NAME" --repo "$GH_REPO" --json isDraft,tagName,targetCommitish)
fi

release_tag=$(jq -er .tagName <<< "$release_json")
release_target=$(jq -er .targetCommitish <<< "$release_json")
is_draft=$(jq -er .isDraft <<< "$release_json")
if [[ "$release_tag" != "$TAG_NAME" || "$release_target" != "$TARGET_SHA" ]]; then
    printf 'Release %s targets %s instead of %s.\n' "$release_tag" "$release_target" "$TARGET_SHA" >&2
    exit 1
fi

write_output "release_created=$is_draft"
write_output "tag_name=$TAG_NAME"
