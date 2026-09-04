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

settings_executable="$home_directory/Library/Input Methods/MetasequoiaIME.app/Contents/MacOS/MetasequoiaIME"
if [[ ! -x "$settings_executable" ]]; then
    print -u2 "水杉输入法 is not installed for the current user. Run Install.command first."
    exit 1
fi

exec "$settings_executable" --show-settings
