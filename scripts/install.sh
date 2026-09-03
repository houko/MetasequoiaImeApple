#!/bin/zsh
set -euo pipefail

project_root=${0:A:h:h}
source_bundle="$project_root/build/MetasequoiaIME.app"
destination_root="$HOME/Library/Input Methods"
destination_bundle="$destination_root/MetasequoiaIME.app"

if [[ ! -d "$source_bundle" ]]; then
    print -u2 "Build output is missing. Run scripts/build.sh first."
    exit 1
fi

mkdir -p "$destination_root"
staging_root=$(mktemp -d "$destination_root/.MetasequoiaIME.installing.XXXXXX")
backup_root=$(mktemp -d "$destination_root/.MetasequoiaIME.backup.XXXXXX")
staging_bundle="$staging_root/MetasequoiaIME.app"
backup_bundle="$backup_root/MetasequoiaIME.app"
had_previous=false
moved_new=false
install_complete=false

cleanup() {
    if [[ "$install_complete" != true ]]; then
        if [[ "$moved_new" == true && -e "$destination_bundle" ]]; then
            rm -rf "$destination_bundle"
        fi
        if [[ "$had_previous" == true && -e "$backup_bundle" ]]; then
            mv "$backup_bundle" "$destination_bundle"
        fi
    fi
    rm -rf "$staging_root" "$backup_root"
}

trap cleanup EXIT
ditto "$source_bundle" "$staging_bundle"
codesign --verify --deep --strict --verbose=2 "$staging_bundle"
pkill -x MetasequoiaIME 2>/dev/null || true
if [[ -e "$destination_bundle" ]]; then
    mv "$destination_bundle" "$backup_bundle"
    had_previous=true
fi
mv "$staging_bundle" "$destination_bundle"
moved_new=true
codesign --verify --deep --strict --verbose=2 "$destination_bundle"
xcrun swift "$project_root/scripts/register_input_source.swift" "$destination_bundle"
install_complete=true
print "Installed $destination_bundle"
print "Enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit."
