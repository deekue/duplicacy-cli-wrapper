#!/bin/bash

set -euo pipefail

CONFIG=/etc/default/duplicacy
[[ -r "$CONFIG" ]] || exit 1
# shellcheck source=/etc/default/duplicacy
. "$CONFIG"

DL_URL="$(curl -sSL "$REPO" \
  | jq -r '.assets[] | select(.browser_download_url | contains("linux_x64")) | .browser_download_url')"
DL_FILE="$(basename -- "$DL_URL")"

if [[ ! -f "$BIN_PATH/$DL_FILE" ]] ; then
  curl -sSLo "$BIN_PATH/$DL_FILE" "$DL_URL" >> "$LOG" 2>> "$ERROR_LOG"
  chmod +x "$BIN_PATH/$DL_FILE" >> "$LOG" 2>> "$ERROR_LOG"
fi

currentVersion="$(basename -- "$(stat -c %N "$CMD" \
  | sed -En "/^'.*duplicacy' -> '(.*)'/ s//\1/p")")"
if [[ -n "$currentVersion" ]] && [[ "$DL_FILE" != "$currentVersion" ]] ; then
  ln -svf "$BIN_PATH/$DL_FILE" "$CMD" >> "$LOG" 2>> "$ERROR_LOG"
fi
