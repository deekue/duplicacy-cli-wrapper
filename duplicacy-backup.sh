#!/bin/sh
#

CONFIG=/etc/default/duplicacy
[ -r "$CONFIG" ] || exit 1
. "$CONFIG"

DATE=$(date +%Y%m%d)
LOG="$LOGDIR/${SNAPSHOT_ID}-${DATE}.log"
ERROR_LOG="$LOGDIR/${SNAPSHOT_ID}-${DATE}.error.log"
HOUR=$(date +%H)

duplicacy_backup () {
	local STORAGE="$1"
	[ -n "$STORAGE" ] || return

	cd "$REPO_ROOT" || exit 1
	"$CMD" -log backup -stats -storage "$STORAGE" >> "$LOG" 2>> "$ERROR_LOG"
}

duplicacy_copy_latest () {
	local STORAGE="$1"
	[ -n "$STORAGE" ] || return

	# hacky BS to get the latest revision
	LATEST_REVISION=$("$CMD" list -id $SNAPSHOT_ID 2>> "$ERROR_LOG" | sed -n -e '$s#^.*revision \([0-9]*\) created at.*$#\1#p')
	if [ -n "$LATEST_REVISION" ] ; then
		"$CMD" -log copy -id $SNAPSHOT_ID -r "$LATEST_REVISION" -to $STORAGE -threads $OFFSITE_UPLOAD_THREADS >> "$LOG" 2>> "$ERROR_LOG"
	else
		echo $(date "+%Y-%m-%d %T") duplicacy_copy: latest revision not found >> "$ERROR_LOG"
	fi
}

duplicacy_prune () {
	local STORAGE="$1"
	[ -n "$STORAGE" ] || return

	# only run once per day during $PRUNE_HOUR
	if [ -n "$HOUR" -a "$HOUR" -eq "$PRUNE_HOUR" ] ; then
	  "$CMD" -log prune $PRUNE_DRY_RUN \
	    -storage "$STORAGE"  \
	    $PRUNE_POLICY >> "$LOG" 2>> "$ERROR_LOG"
	fi
}

### Local backup
duplicacy_backup default
duplicacy_prune default

### copy offsite
if [ -n "$OFFSITE_STORAGE" ] ; then
  duplicacy_copy_latest "$OFFSITE_STORAGE"
  duplicacy_prune "$OFFSITE_STORAGE"
fi
