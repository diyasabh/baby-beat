#!/usr/bin/env bash
# Capture one screen per demo state, straight from the simulator.
# Screenshots land in presentation/shots/ and feed the web presentation.
#
#   ./capture.sh              every state
#   ./capture.sh parent_alert just that one
#
# States are driven by a launch argument (see App/DemoStates.swift). Writing the
# App Group plist from outside loses a race with cfprefsd's cache, and openurl
# puts a system dialog over every shot, so the app seeds itself at launch.
set -euo pipefail

DEVICE="${BB_DEVICE:-66B2D002-384A-48D2-ABF2-96F0DA976BAF}"
BUNDLE="com.diyasabh.babybeat"
HERE="$(cd "$(dirname "$0")" && pwd)"
SHOTS="$HERE/shots"
mkdir -p "$SHOTS"

STATES=("$@")
if [ ${#STATES[@]} -eq 0 ]; then
  STATES=(parent_calm parent_waiting parent_alert
          caregiver_asked caregiver_calm_sent caregiver_alert_sent fresh)
fi

shoot() { xcrun simctl io "$DEVICE" screenshot --type=png "$1" >/dev/null 2>&1; }

for state in "${STATES[@]}"; do
  xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl launch "$DEVICE" "$BUNDLE" --demo-state "$state" >/dev/null
  sleep 4
  shoot "$SHOTS/$state.png"

  # Home screen, so the widget for this same state gets captured too.
  xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 4
  shoot "$SHOTS/${state}__home.png"

  echo "  -> $state.png + ${state}__home.png"
done

# The simulator writes 1179x2556; the page shows them ~324pt wide, so full res
# is ~10x more pixels than any screen needs and would bloat the repo.
python3 "$HERE/optimize.py"

echo
echo "captured ${#STATES[@]} state(s) into presentation/shots/"
