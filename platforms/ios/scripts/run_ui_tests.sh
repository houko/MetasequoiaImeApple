#!/usr/bin/env bash
set -euo pipefail

project_path="${1:-build/ios/MetasequoiaImeIOS.xcodeproj}"
derived_data_path="${2:-build/ios-ui-test-derived}"

if [[ ! -d "${project_path}" ]]; then
  echo "Generated Xcode project not found: ${project_path}" >&2
  exit 1
fi

if [[ -n "${IOS_SIMULATOR_UDID:-}" ]]; then
  test_device_id="${IOS_SIMULATOR_UDID}"
else
  test_device_id="$(xcrun simctl list devices available --json | python3 -c '
import json
import re
import sys

devices_by_runtime = json.load(sys.stdin)["devices"]

def version_key(runtime):
    return tuple(int(part) for part in re.findall(r"\d+", runtime))

for runtime in sorted(devices_by_runtime, key=version_key, reverse=True):
    if ".iOS-" not in runtime:
        continue
    devices = sorted(
        devices_by_runtime[runtime],
        key=lambda device: device.get("state") != "Booted",
    )
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            print(device["udid"])
            raise SystemExit(0)

raise SystemExit("No available iPhone Simulator runtime was found")
')"
fi

# simctl bootstatus polls the real boot state; it avoids a timing guess before XCTest starts.
xcrun simctl bootstatus "${test_device_id}" -b

xcodebuild \
  -project "${project_path}" \
  -scheme MetasequoiaImeIOS \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${test_device_id}" \
  -derivedDataPath "${derived_data_path}" \
  test
