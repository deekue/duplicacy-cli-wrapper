#!/bin/sh
#
# /etc/default/duplicacy

SNAPSHOT_ID=host-volume		# snapshot-id to back up, in .duplicacy/preferences
REPO_ROOT=/volume1		# duplicacy root dir, contains .duplicacy
LOGDIR=/volume2/duplicacy/logs	# base path for logging
CMD=/usr/local/bin/duplicacy	# path to duplicacy binary
OFFSITE_STORAGE=b2  		# storage name in .duplicacy/preferences
OFFSITE_UPLOAD_THREADS=10	# ~1MB/s per thread
PRUNE_HOUR=0			# hour of the day to prune, assuming script
				# runs once per day
PRUNE_DRY_RUN="-d"		# set to "" to actually prune
PRUNE_POLICY="-keep 1:3 \
	      -keep 7:30 \
	      -keep 30:180 \
	      -keep 0:360"


