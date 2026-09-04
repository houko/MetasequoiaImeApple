#!/bin/zsh
set -euo pipefail

project_root=${0:A:h:h:h:h}
python3 "$project_root/platforms/macos/scripts/build_dictionary.py"
cmake -S "$project_root" -B "$project_root/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$(brew --prefix)"
cmake --build "$project_root/build" --parallel
ctest --test-dir "$project_root/build" --output-on-failure --timeout 20
codesign --verify --deep --strict --verbose=2 "$project_root/build/MetasequoiaIME.app"
