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

if [[ ! -d "$source_bundle" ]]; then
    print -u2 "Input method bundle not found at $source_bundle"
    exit 1
fi

bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_bundle/Contents/Info.plist")
if [[ "$bundle_version" != "$version" ]]; then
    print -u2 "Bundle version $bundle_version does not match tag $tag_name."
    exit 1
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

mkdir -p "$package_root"
ditto "$source_bundle" "$package_root/MetasequoiaIME.app"
ditto "$project_root/scripts/install-release.sh" "$package_root/Install.command"
chmod +x "$package_root/Install.command"
rm -f "$archive_path" "$checksum_path" "$installer_path" "$installer_checksum_path"
ditto -c -k --keepParent "$package_root" "$archive_path"
(cd "$output_dir" && shasum -a 256 "${archive_path:t}") > "$checksum_path"
pkgbuild --component "$source_bundle" --identifier com.houko.inputmethod.MetasequoiaIME.pkg --version "$version" --install-location "Library/Input Methods" "$component_package"
sed "s/@VERSION@/$version/g" "$project_root/resources/InstallerDistribution.xml.in" > "$distribution_file"
productbuild --distribution "$distribution_file" --package-path "$staging_root" "$installer_path"
(cd "$output_dir" && shasum -a 256 "${installer_path:t}") > "$installer_checksum_path"
print "$archive_path"
print "$checksum_path"
print "$installer_path"
print "$installer_checksum_path"
