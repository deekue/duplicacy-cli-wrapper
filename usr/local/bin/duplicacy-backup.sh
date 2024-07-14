#!/bin/bash
#

set -eu
trap 'catch $?' EXIT
catch() {
  if [ "$1" != "0" ]; then
    echo "A command failed with exit code $1"
  fi
}

CONFIG=/etc/default/duplicacy
[[ -r "$CONFIG" ]] || exit 1
# shellcheck source=/etc/default/duplicacy
. "$CONFIG"

# use dbus session of first user to avoid duplicacy spawning one and not cleaning it up
# h/t: https://forum.duplicacy.com/t/user-cronjob-cant-access-keyring-credentials/2455
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
export DBUS_SESSION_BUS_ADDRESS

# only run prune once per week during $PRUNE_HOUR
if [[ "$(date +%u)" -eq "${PRUNE_DOW:-7}" ]] && [[ "$(date +%H)" -eq "${PRUNE_HOUR:-0}" ]] ; then
	RUN_PRUNE=true
else
	RUN_PRUNE=false
fi

# run a check once a month during $CHECK_HOUR
if [[ "$(date +%d)" -eq "${CHECK_DOM:-1}" ]] && [[ "$(date +%H)" -eq "${CHECK_HOUR:-1}" ]] ; then
  RUN_CHECK=true
else
  RUN_CHECK=false
fi

ERROR () {
	echo "$(date "+%Y-%m-%d %T") $*" >> "$ERROR_LOG"
}

duplicacy_backup () {
	local STORAGE="$1"
	[[ -n "$STORAGE" ]] || return

	cd "$REPO_ROOT" || exit 1
	"$CMD" -log backup -stats -storage "$STORAGE" >> "$LOG" 2>> "$ERROR_LOG"
}

duplicacy_copy_latest () {
	local STORAGE="$1"
	[[ -n "$STORAGE" ]] || return

  LATEST_REVISION="$(duplicacy_latest_revision)"
	if [ -n "$LATEST_REVISION" ] ; then
		"$CMD" -log copy -id "$SNAPSHOT_ID" -r "$LATEST_REVISION" -to "$STORAGE" -threads "$OFFSITE_UPLOAD_THREADS" >> "$LOG" 2>> "$ERROR_LOG"
	else
		ERROR "duplicacy_copy: latest revision not found"
	fi
}

duplicacy_prune () {
	local STORAGE="$1"
	[[ -n "$STORAGE" ]] || return

	if [[ "$RUN_PRUNE" == "true" ]] ; then
	  "$CMD" -log prune ${PRUNE_DRY_RUN:+-dry-run} ${PRUNE_THREADS:+-threads "$PRUNE_THREADS"} \
	    -storage "$STORAGE"  \
	    "${PRUNE_POLICY[@]}" >> "$LOG" 2>> "$ERROR_LOG"
	fi
}

duplicacy_latest_revision () {
	# hacky BS to get the latest revision
	"$CMD" list -id "$SNAPSHOT_ID" 2>> "$ERROR_LOG" \
    | sed -n -e '$s#^.*revision \([0-9]*\) created at.*$#\1#p'
}

duplicacy_check () {
  local -r STORAGE="${1:?arg1 is storage to check}"

  if [[ "$RUN_CHECK" == "true" ]] ; then
     "$CMD" -log check -stats \
       ${CHECK_THREADS:+-threads "$CHECK_THREADS"} \
       ${RUN_CHUNK_CHECK:+-chunks} \
       -r "$(duplicacy_latest_revision)" \
       -storage "$STORAGE" \
       >> "$LOG" \
       2>> "$ERROR_LOG"
  fi
}

is_ext_drive_mounted () {
  local MOUNT_POINT="$1"
  local DISK_UUID="$2"

  # can we see the repo config file?
  if [[ ! -r "${MOUNT_POINT}/duplicacy/config" ]] ; then
    ERROR "repo config not found"

    if findmnt -n --mountpoint "$MOUNT_POINT" --source UUID="$DISK_UUID" >> "$ERROR_LOG" 2>&1 ; then
      ERROR "drive is mounted in the right place but repo not found"
      exit 1
    fi

    if findmnt -n --source UUID="$DISK_UUID" >> "$ERROR_LOG" 2>&1 ; then
      ERROR "backup drive mounted in the wrong spot, unmounting"
      umount "/dev/disk/by-uuid/$DISK_UUID" 2>> "$ERROR_LOG"
    fi

    if [[ ! -d "$MOUNT_POINT" ]] ; then
      ERROR "$MOUNT_POINT not found, creating"
      mkdir "$MOUNT_POINT" 2>> "$ERROR_LOG" || exit 2
    fi

    ERROR "attempting to mount drive in correct location, $MOUNT_POINT"
    mount "/dev/disk/by-uuid/$DISK_UUID" "$MOUNT_POINT" 2>> "$ERROR_LOG" || exit 3

    if [[ ! -r "${MOUNT_POINT}/duplicacy/config" ]] ; then
      ERROR "remounted disk and still can't see duplicacy repo. PANIC!"
      exit 4
    fi
  fi
}

function singleton {
  local -r jobName="${1:?arg1 is command to run}"
  (
    flock -n 9 || exit 9
    "$@"
  ) 9> "${LOCKDIR:-/var/lock}/$jobName"
}

mkdir -p "$LOGDIR"

if [[ -n "$MOUNT_POINT" && -n "$DISK_UUID" ]] ; then
  is_ext_drive_mounted "$MOUNT_POINT" "$DISK_UUID"
else
  ERROR "MOUNT_POINT or DISK_UUID not set"
  exit 5
fi

### Local backup
duplicacy_backup default
duplicacy_prune default
duplicacy_check default

### copy offsite
if [ -n "$OFFSITE_STORAGE" ] ; then
  # only allow one offsite job to run at a time, avoid saturating uplink
  singleton duplicacy_copy_latest "$OFFSITE_STORAGE"
  singleton duplicacy_prune "$OFFSITE_STORAGE"
  if [[ "${CHECK_OFFSITE:-false}" == "true" ]] ; then
    singleton duplicacy_check "$OFFSITE_STORAGE"
  fi
fi

