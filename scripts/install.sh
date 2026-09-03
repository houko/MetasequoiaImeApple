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

project_root=${0:A:h:h}
source_bundle="$project_root/build/MetasequoiaIME.app"
destination_root="$home_directory/Library/Input Methods"
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
codesign --verify --deep --strict --verbose=2 "$staging_bundle"
pkill -x MetasequoiaIME 2>/dev/null || true
if [[ -e "$destination_bundle" ]]; then
    had_previous=true
    mv "$destination_bundle" "$backup_bundle"
fi
moved_new=true
mv "$staging_bundle" "$destination_bundle"
codesign --verify --deep --strict --verbose=2 "$destination_bundle"
xcrun swift "$project_root/scripts/register_input_source.swift" "$destination_bundle"
install_complete=true
print "Installed $destination_bundle"
print "Enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit."
