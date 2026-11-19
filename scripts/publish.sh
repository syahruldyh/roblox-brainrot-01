#!/bin/sh
# SNACK ATTACK: publish the built place over an existing Roblox experience via
# the Roblox Open Cloud API (no Studio needed for the upload itself).
# Usage: scripts/publish.sh <universe_id> <place_id>
#   universe_id / place_id are the real ids of the published experience — never 0.
#   The place must already exist on the account and be Public before submitting.
# Do NOT run this until PLAY.json holds the real ids.
set -eu
if [ "$#" -ne 2 ]; then
	echo "usage: scripts/publish.sh <universe_id> <place_id>" >&2
	exit 2
fi
UNIVERSE_ID="$1"
PLACE_ID="$2"
if [ "$UNIVERSE_ID" = "0" ] || [ "$PLACE_ID" = "0" ]; then
	echo "refusing placeholder ids: publish the experience in Studio first, then fill in PLAY.json." >&2
	exit 2
fi
cd "$(dirname "$0")/.."
python3 ~/workspace/custom-connectors/custom.roblox/bin/roblox.py publish-place "$UNIVERSE_ID" "$PLACE_ID" game.rbxl
