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

remove_user_data=false
if (( $# > 1 )); then
    print -u2 "Usage: ${0:t} [--remove-user-data]"
    exit 64
fi
if (( $# == 1 )); then
    if [[ "$1" != "--remove-user-data" ]]; then
        print -u2 "Usage: ${0:t} [--remove-user-data]"
        exit 64
    fi
    remove_user_data=true
fi

installed_bundle="$home_directory/Library/Input Methods/MetasequoiaIME.app"
user_data="$home_directory/Library/Application Support/metasequoiaime"
preferences_domain="com.houko.inputmethod.MetasequoiaIME"
preferences_file="$home_directory/Library/Preferences/$preferences_domain.plist"
defaults_command=${METASEQUOIA_DEFAULTS_COMMAND:-/usr/bin/defaults}

path_exists() {
    [[ -e "$1" || -L "$1" ]]
}

if [[ "$remove_user_data" == true ]]; then
    if [[ ! -x "$defaults_command" ]]; then
        print -u2 "The macOS defaults command is unavailable."
        exit 1
    fi
fi

if [[ "$remove_user_data" != true ]] && ! path_exists "$installed_bundle"; then
    print "MetasequoiaIME is not installed for the current user."
    if path_exists "$user_data"; then
        print "User data was preserved at $user_data"
    fi
    exit 0
fi

print "This will move the current user's MetasequoiaIME installation to Trash."
if [[ "$remove_user_data" == true ]]; then
    print "Preferences and learned data will also be moved to Trash."
else
    print "Preferences and learned data will be preserved."
fi
printf '%s' "Type REMOVE METASEQUOIAIME to continue: "
confirmation=""
IFS= read -r confirmation || true
if [[ "$confirmation" != "REMOVE METASEQUOIAIME" ]]; then
    print -u2 "Uninstallation cancelled."
    exit 1
fi

pkill -TERM -x -u "$EUID" MetasequoiaIME 2>/dev/null || true
process_stopped=false
for attempt in {1..50}; do
    if ! pgrep -x -u "$EUID" MetasequoiaIME >/dev/null 2>&1; then
        process_stopped=true
        break
    fi
    sleep 0.1
done
if [[ "$process_stopped" != true ]]; then
    print -u2 "MetasequoiaIME did not stop in time; no files were changed."
    exit 1
fi

preferences_present=false
if [[ "$remove_user_data" == true ]]; then
    domains=""
    if ! domains=$("$defaults_command" domains); then
        print -u2 "Could not inspect MetasequoiaIME preferences; no files were changed."
        exit 1
    fi
    normalized_domains=${domains//[[:space:]]/}
    if [[ ",$normalized_domains," == *",$preferences_domain,"* ]]; then
        preferences_present=true
    elif path_exists "$preferences_file"; then
        print -u2 "MetasequoiaIME preferences exist but could not be read; no files were changed."
        exit 1
    fi
fi

if ! path_exists "$installed_bundle" &&
    { [[ "$remove_user_data" != true ]] || { ! path_exists "$user_data" && [[ "$preferences_present" != true ]]; }; }; then
    print "MetasequoiaIME is not installed for the current user."
    exit 0
fi

trash_root="$home_directory/.Trash"
mkdir -p "$trash_root"
recovery_root=$(mktemp -d "$trash_root/MetasequoiaIME-uninstall.XXXXXX")
trashed_bundle="$recovery_root/MetasequoiaIME.app"
trashed_user_data="$recovery_root/UserData"
trashed_preferences="$recovery_root/Preferences.plist"
bundle_move_started=false
data_move_started=false
preferences_backup_created=false
preferences_delete_started=false
uninstall_complete=false

cleanup() {
    local exit_status=$?
    trap - EXIT HUP INT TERM
    local rollback_failed=false
    if [[ "$uninstall_complete" != true ]]; then
        if [[ "$preferences_delete_started" == true && -f "$trashed_preferences" ]]; then
            print -u2 "Uninstallation failed; restoring preferences."
            if "$defaults_command" import "$preferences_domain" "$trashed_preferences"; then
                if ! rm -f -- "$trashed_preferences"; then
                    rollback_failed=true
                fi
            else
                rollback_failed=true
            fi
        elif [[ "$preferences_backup_created" == true && -f "$trashed_preferences" ]] &&
            ! rm -f -- "$trashed_preferences"; then
            rollback_failed=true
        fi
        if [[ "$data_move_started" == true ]] && path_exists "$trashed_user_data"; then
            print -u2 "Uninstallation failed; restoring user data."
            if path_exists "$user_data" || ! mv "$trashed_user_data" "$user_data"; then
                rollback_failed=true
            fi
        fi
        if [[ "$bundle_move_started" == true ]] && path_exists "$trashed_bundle"; then
            print -u2 "Uninstallation failed; restoring the installed application."
            if path_exists "$installed_bundle" || ! mv "$trashed_bundle" "$installed_bundle"; then
                rollback_failed=true
            fi
        fi
        if [[ "$rollback_failed" == true ]]; then
            print -u2 "Uninstallation rollback was incomplete. Recovery files are preserved at: $recovery_root"
            exit 1
        fi
        if ! rmdir "$recovery_root"; then
            print -u2 "Uninstallation cleanup was incomplete. Recovery files are preserved at: $recovery_root"
            exit 1
        fi
    fi
    exit "$exit_status"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM
if path_exists "$installed_bundle"; then
    bundle_move_started=true
    if ! mv "$installed_bundle" "$trashed_bundle"; then
        print -u2 "Could not move the installed application to Trash."
        exit 1
    fi
fi
if [[ "$remove_user_data" == true ]] && path_exists "$user_data"; then
    data_move_started=true
    if ! mv "$user_data" "$trashed_user_data"; then
        print -u2 "Could not move user data to Trash; restoring the installed application."
        exit 1
    fi
fi
if [[ "$remove_user_data" == true && "$preferences_present" == true ]]; then
    if ! "$defaults_command" export "$preferences_domain" "$trashed_preferences"; then
        print -u2 "Could not back up preferences; restoring other files."
        exit 1
    fi
    preferences_backup_created=true
    preferences_delete_started=true
    if ! "$defaults_command" delete "$preferences_domain"; then
        print -u2 "Could not remove preferences; restoring all files."
        exit 1
    fi
fi
uninstall_complete=true

print "MetasequoiaIME was moved to Trash: $recovery_root"
if [[ "$remove_user_data" == true ]]; then
    print "User data was moved to Trash."
else
    print "User data was preserved at $user_data"
fi
print "Log out and back in so macOS refreshes its input source cache."
