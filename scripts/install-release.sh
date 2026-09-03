#!/bin/zsh
set -euo pipefail

if [[ -z ${HOME:-} || "$HOME" != /* ]]; then
    print -u2 "HOME must be an absolute current-user directory."
    exit 1
fi
home_directory=${HOME:A}
if [[ "$home_directory" == / ]]; then
    print -u2 "HOME must be an absolute current-user directory."
    exit 1
fi

package_root=${0:A:h}
source_bundle="$package_root/MetasequoiaIME.app"
unsigned_marker="$package_root/UNSIGNED_BUILD.txt"
destination_root="$home_directory/Library/Input Methods"
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
    codesign --verify --deep --strict --verbose=2 "$bundle" || return 1
    if [[ "$unsigned_release" != true ]]; then
        spctl --assess --type execute --verbose=2 "$bundle" || return 1
    fi
}

if ! verify_bundle "$source_bundle"; then
    print -u2 "Release bundle verification failed before installation."
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
    local exit_status=$?
    trap - EXIT HUP INT TERM
    local rollback_failed=false
    if [[ "$install_complete" != true ]]; then
        if [[ "$moved_new" == true && -e "$destination_bundle" ]] &&
            ! rm -rf -- "$destination_bundle"; then
            rollback_failed=true
        fi
        if [[ "$had_previous" == true && -e "$backup_bundle" ]]; then
            if [[ -e "$destination_bundle" ]] || ! mv "$backup_bundle" "$destination_bundle"; then
                rollback_failed=true
            fi
        fi
    fi
    if [[ "$rollback_failed" == true ]]; then
        if [[ -e "$backup_bundle" ]]; then
            print -u2 "Installation rollback was incomplete. Previous installation is preserved at: $backup_bundle"
        else
            print -u2 "Installation rollback was incomplete. Recovery files are preserved at: $staging_root"
        fi
        exit 1
    fi
    if ! rm -rf -- "$staging_root" "$backup_root"; then
        print -u2 "Installation cleanup was incomplete. Recovery files may remain at: $staging_root or $backup_root"
        exit 1
    fi
    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM
ditto "$source_bundle" "$staging_bundle"
if ! verify_bundle "$staging_bundle"; then
    print -u2 "Staged release bundle verification failed."
    exit 1
fi
pkill -x MetasequoiaIME 2>/dev/null || true
if [[ -e "$destination_bundle" ]]; then
    had_previous=true
    mv "$destination_bundle" "$backup_bundle"
fi
moved_new=true
mv "$staging_bundle" "$destination_bundle"
if ! verify_bundle "$destination_bundle"; then
    print -u2 "Installed release bundle verification failed; restoring the previous installation."
    exit 1
fi
install_complete=true
print "Installed $destination_bundle"
if [[ "$unsigned_release" == true ]]; then
    print "If macOS blocks the input method, approve it in System Settings > Privacy & Security before enabling it."
fi
print "Log out and back in, then enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit."
