#!/bin/bash

# CONFIG
# Array list of directory to sync with rclone
# DON'T FORGET TO ADD A / AT THE END OF EACH DIRECTORY
DIRS=()


_now=$(date +%Y-%m-%d.%H.%M.%S)
echo "--------------------------"
echo "$_now rclonebackup.sh starting"

#
# Load config file if exists
#
CONFIG_DIR=$( dirname "$(readlink -f "$0")" )
CONFIG_FILE="$CONFIG_DIR/rclonebackup.config"

if [[ -f $CONFIG_FILE ]]; then
   echo "Loading settings from $CONFIG_FILE."
   source $CONFIG_FILE
else
   echo "Could not load settings from $CONFIG_FILE (file does not exist), script use default settings."
fi


if [ ${#DIRS[@]} -eq 0 ]; then
   echo "Alert, directory list is empty. Abording" >&2
	exit 1
fi

for i in ${!DIRS[@]}
do
	echo "Syncing directory ${DIRS[$i]}..."
	rclone sync -v "${DIRS[$i]}" "remote:${DIRS[$i]}"
done

_now=$(date +%Y-%m-%d.%H.%M.%S)
echo "$_now rclonebackup.sh finished"
