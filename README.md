# Duplicacy Headless Wrapper

simple wrapper for [Duplicacy](https://github.com/gilbertchen/duplicacy) to backup an Ubuntu Linux box to a local USB drive and an offsite storage.

* runs a backup every hour, optionally copies offsite too
* runs a prune once per day
* updates Duplicacy once per month

## Setup

1. copy files to host
2. edit `/etc/default/duplicacy`
   * set `MOUNT_POINT`, `DISK_UUID`, and `SNAPSHOT_ID`
   * optionally, set `OFFSITE_STORAGE` and `OFFSITE_UPLOAD_THREADS`
3. edit `/etc/default/cronitor`
   * add your API key from [cronitor.io](https://cronitor.io)
4. run `/usr/local/bin/update-duplicacy.sh` to install latest CLI binary

## TODO

* add monthly storage maintenance
* add timeouts on remote commands
