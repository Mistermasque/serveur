#!/bin/bash


# CONFIG
# Liste des répertoires à sauvegarder séparés par des ,
# Ajouter le / à la fin des répertoires
# C'est un tableau en bash
DIRS=('/backup/mariadb/data/' '/srv/dev-disk-by-label-data/Souvenirs/' '/backup/owncloud/' '/srv/dev-disk-by-label-data/Partages/' '/srv/dev-disk-by-label-data/Homes/')


for i in ${!DIRS[@]}
do
	echo "Sauvegarde du répertoire ${DIRS[$i]}"
	rclone sync -v "${DIRS[$i]}" "remote:${DIRS[$i]}"
done

