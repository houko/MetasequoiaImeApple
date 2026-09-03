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
pkill -x MetasequoiaIME 2>/dev/null || true
ditto "$source_bundle" "$destination_bundle"
codesign --verify --deep --strict --verbose=2 "$destination_bundle"
xcrun swift "$project_root/scripts/register_input_source.swift" "$destination_bundle"
print "Installed $destination_bundle"
print "Enable 水杉输入法 in System Settings > Keyboard > Text Input > Edit."
