#!/bin/zsh
set -euo pipefail

package_root=${0:A:h}
source_bundle="$package_root/MetasequoiaIME.app"
unsigned_marker="$package_root/UNSIGNED_BUILD.txt"
destination_root="$HOME/Library/Input Methods"
destination_bundle="$destination_root/MetasequoiaIME.app"

if [[ ! -d "$source_bundle" ]]; then
    print -u2 "MetasequoiaIME.app is missing from the release package."
    exit 1
fi

unsigned_release=false
if [[ -f "$unsigned_marker" ]]; then
    unsigned_release=true
    print -u2 "WARNING: This build is not Developer ID signed or notarized. macOS may block it until you explicitly allow it in Privacy & Security settings."
    printf '%s' "Type I UNDERSTAND to install this unsigned build: "
    confirmation=""
    IFS= read -r confirmation || true
    if [[ "$confirmation" != "I UNDERSTAND" ]]; then
        print -u2 "Unsigned installation cancelled."
        exit 1
    fi
fi

verify_bundle() {
    local bundle=$1
    codesign --verify --deep --strict --verbose=2 "$bundle"
    if [[ "$unsigned_release" != true ]]; then
        spctl --assess --type execute --verbose=2 "$bundle"
    fi
}

verify_bundle "$source_bundle"
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
verify_bundle "$staging_bundle"
pkill -x MetasequoiaIME 2>/dev/null || true
if [[ -e "$destination_bundle" ]]; then
    mv "$destination_bundle" "$backup_bundle"
    had_previous=true
fi
mv "$staging_bundle" "$destination_bundle"
moved_new=true
verify_bundle "$destination_bundle"
install_complete=true
print "Installed $destination_bundle"
if [[ "$unsigned_release" == true ]]; then
    print "If macOS blocks the input method, approve it in System Settings > Privacy & Security before enabling it."
fi
print "Log out and back in, then enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit."
