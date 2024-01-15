#!/bin/bash

#### CONFIG ####
# Liste des fichiers et de leur destination
# <nom du fichier>,<destination>
declare -ra SYMLINK_FILES=(
    "backup-to-remote.cron,/etc/cron.d/backup-to-remote"
    "backup-to-remote.logrotate,/etc/logrotate.d/backup-to-remote"
    "backup-to-usb-@.service,/etc/systemd/system/backup-to-usb-@.service"
    "yunohost-backup,/etc/yunohost/hooks.d/backup/98-backup-to-remote"
)

declare -ra COPY_FILES=(
    "yunohost-restore,/etc/yunohost/hooks.d/restore/98-backup-to-remote"
)

REP_INSTALL='/opt/backup-to-remote'

usage() {
    echo "Script d'installation de l'outil backup-to-remote"
}

if [ $(id -u) -ne 0 ]
then
   echo "Ce script doit être lancé en tant que root !" >&2
   exit 1
fi

if [[ `pwd` != "$REP_INSTALL" ]]; then
    mkdir -p "$REP_INSTALL"
    cp * "$REP_INSTALL"
    cd "$REP_INSTALL"
fi


for conf in ${SYMLINK_FILES[@]}
do
   srcFile=$( echo "$conf" | cut -d "," -f1 )
   destFile=$( echo "$conf" | cut -d "," -f2 )
   destDir=$( dirname "$destFile" )

   mkdir -p "${destDir}"
   ln -sfn "$srcFile" "$destFile"
done

for conf in ${COPY_FILES[@]}
do
   srcFile=$( echo "$conf" | cut -d "," -f1 )
   destFile=$( echo "$conf" | cut -d "," -f2 )
   destDir=$( dirname "$destFile" )

   mkdir -p "${destDir}"
   cp "$srcFile" "$destFile"
done

chmod +x ./backup-to-remote.sh
