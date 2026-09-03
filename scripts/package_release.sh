#!/bin/zsh
set -euo pipefail

project_root=${0:A:h:h}
tag_name=${1:-}
source_bundle=${2:-$project_root/build/MetasequoiaIME.app}
output_dir=${3:-$project_root/dist}

if [[ ! "$tag_name" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "Tag must use the vMAJOR.MINOR.PATCH format."
    exit 1
fi

source_bundle=${source_bundle:A}
output_dir=${output_dir:A}
version=${tag_name#v}
require_release_signing=${METASEQUOIA_REQUIRE_RELEASE_SIGNING:-false}
application_identity=${METASEQUOIA_DEVELOPER_ID_APPLICATION:-}
installer_identity=${METASEQUOIA_DEVELOPER_ID_INSTALLER:-}
notary_profile=${METASEQUOIA_NOTARY_PROFILE:-}

if [[ "$require_release_signing" == true ]]; then
    if [[ -z "$application_identity" || -z "$installer_identity" || -z "$notary_profile" ]]; then
        print -u2 "Commercial release signing requires METASEQUOIA_DEVELOPER_ID_APPLICATION, METASEQUOIA_DEVELOPER_ID_INSTALLER, and METASEQUOIA_NOTARY_PROFILE."
        exit 1
    fi
fi

if [[ ! -d "$source_bundle" ]]; then
    print -u2 "Input method bundle not found at $source_bundle"
    exit 1
fi

bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_bundle/Contents/Info.plist")
if [[ "$bundle_version" != "$version" ]]; then
    print -u2 "Bundle version $bundle_version does not match tag $tag_name."
    exit 1
fi

if [[ -n "$application_identity" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$application_identity" "$source_bundle"
fi
codesign --verify --deep --strict --verbose=2 "$source_bundle"
mkdir -p "$output_dir"
staging_root=$(mktemp -d "$output_dir/.package.XXXXXX")
trap 'rm -rf "$staging_root"' EXIT
package_root="$staging_root/MetasequoiaIME-$tag_name"
archive_path="$output_dir/MetasequoiaIME-$tag_name-macos-universal.zip"
checksum_path="$archive_path.sha256"
installer_path="$output_dir/MetasequoiaIME-$tag_name-macos-universal.pkg"
installer_checksum_path="$installer_path.sha256"
component_package="$staging_root/MetasequoiaIME.pkg"
distribution_file="$staging_root/Distribution.xml"
installer_resources="$staging_root/InstallerResources"

mkdir -p "$package_root"
ditto "$source_bundle" "$package_root/MetasequoiaIME.app"
ditto "$project_root/scripts/install-release.sh" "$package_root/Install.command"
ditto "$project_root/LICENSE" "$package_root/LICENSE"
ditto "$project_root/THIRD_PARTY_NOTICES.txt" "$package_root/THIRD_PARTY_NOTICES.txt"
chmod +x "$package_root/Install.command"
rm -f "$archive_path" "$checksum_path" "$installer_path" "$installer_checksum_path"
if [[ -n "$notary_profile" ]]; then
    notary_input="$staging_root/MetasequoiaIME-notary.zip"
    ditto -c -k --keepParent "$package_root/MetasequoiaIME.app" "$notary_input"
    xcrun notarytool submit "$notary_input" --keychain-profile "$notary_profile" --wait
    xcrun stapler staple "$package_root/MetasequoiaIME.app"
    xcrun stapler validate "$package_root/MetasequoiaIME.app"
fi
ditto -c -k --keepParent "$package_root" "$archive_path"
(cd "$output_dir" && shasum -a 256 "${archive_path:t}") > "$checksum_path"
pkgbuild --component "$package_root/MetasequoiaIME.app" --identifier com.houko.inputmethod.MetasequoiaIME.pkg --version "$version" --install-location "Library/Input Methods" "$component_package"
sed "s/@VERSION@/$version/g" "$project_root/resources/InstallerDistribution.xml.in" > "$distribution_file"
mkdir -p "$installer_resources"
ditto "$project_root/LICENSE" "$installer_resources/LICENSE"
ditto "$project_root/THIRD_PARTY_NOTICES.txt" "$installer_resources/THIRD_PARTY_NOTICES.txt"
productbuild --distribution "$distribution_file" --package-path "$staging_root" --resources "$installer_resources" "$installer_path"
if [[ -n "$installer_identity" ]]; then
    signed_installer="$staging_root/MetasequoiaIME-signed.pkg"
    productsign --sign "$installer_identity" "$installer_path" "$signed_installer"
    mv "$signed_installer" "$installer_path"
fi
if [[ -n "$notary_profile" ]]; then
    xcrun notarytool submit "$installer_path" --keychain-profile "$notary_profile" --wait
    xcrun stapler staple "$installer_path"
    xcrun stapler validate "$installer_path"
fi
(cd "$output_dir" && shasum -a 256 "${installer_path:t}") > "$installer_checksum_path"
print "$archive_path"
print "$checksum_path"
print "$installer_path"
print "$installer_checksum_path"
