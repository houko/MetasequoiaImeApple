#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is required}"

required_secrets=(
    MACOS_DEVELOPER_ID_CERTIFICATE_BASE64
    MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD
    MACOS_SIGNING_KEYCHAIN_PASSWORD
    MACOS_NOTARY_APPLE_ID
    MACOS_NOTARY_TEAM_ID
    MACOS_NOTARY_APP_SPECIFIC_PASSWORD
    MACOS_DEVELOPER_ID_APPLICATION
    MACOS_DEVELOPER_ID_INSTALLER
)

configured_count=0
missing_secrets=()
for required in "${required_secrets[@]}"; do
    if [[ -n "${!required:-}" ]]; then
        configured_count=$((configured_count + 1))
    else
        missing_secrets+=("$required")
    fi
done

if ((configured_count == 0)); then
    printf '%s\n' 'signing_enabled=false' 'asset_suffix=-unsigned' >> "$GITHUB_OUTPUT"
    printf '%s\n' '### Release signing' '' 'Apple signing credentials are not configured. Publishing clearly labeled **unsigned** artifacts.' >> "$GITHUB_STEP_SUMMARY"
    exit 0
fi

if ((configured_count != ${#required_secrets[@]})); then
    printf '%s\n' 'Release signing is partially configured; refusing to publish ambiguous artifacts.' >&2
    printf 'Missing GitHub Actions secret: %s\n' "${missing_secrets[@]}" >&2
    exit 1
fi

printf '%s\n' 'signing_enabled=true' 'asset_suffix=' >> "$GITHUB_OUTPUT"
printf '%s\n' '### Release signing' '' 'Publishing Developer ID signed and notarized artifacts.' >> "$GITHUB_STEP_SUMMARY"
