#!/bin/bash
set -eo pipefail
# Script d'envoi des sauvegardes sur les différents supports cible


########### CONFIGURATION ##########
# Répertoire source contenant les fichiers à transférer
declare -r SRC_DIR="/home/yunohost.backup/archives"
# Patern de recherche des fichiers d'archive
declare -r SRC_FILES_PATERN='^[0-9]{8}-[0-9]{6}\.(tar|info\.json|tar\.gz)$'


######## VARIABLES GLOBALES ########
# Le répertoire du script
declare -r ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Liste des méthodes disponibles
declare -ra METHODS=$(ls "$ROOT_DIR" | grep "_method.sh*" | sed s/'_method.sh'//g )


source "$ROOT_DIR/functions.sh"

############ FONCTIONS ###########


# Aide à l'usage du script
usage() {
    cat << USAGE
Script d'envoi des sauvegardes sur une destination.
Usage : $0 [OPTIONS] <method> <args>

<method> : la méthode de sauvegarde. les valeurs possibles :
$(echo ${METHODS[@]} )

Options :
    -h : affiche cette aide
    -q : N'affiche pas sur la sortie standard
    -v : mode verbeux

<args> : arguments variables suivant la méthode :
Méthode usb :
    - <disque cible (dans dev)> : exemple /dev/front_usb
USAGE


}



####### MAIN ########

while getopts "hqv" arg; do
    case $arg in
        h)
            usage
            exit 0
        ;;
        q)
            QUIET=true
        ;;
        v)
            VERBOSE=true
        ;;
        *)
            echo "Argument $arg inconnu !" >&2
            exit 1
        ;;
    esac
done

loadMethod "$1" 
shift

msg "Démarrage backup to ${METHOD}..."
nbFiles=0
nbFilesError=0

prepare $*

ls -t "$SRC_DIR" | egrep "$SRC_FILES_PATERN" | while read file; do

    path="${SRC_DIR}/${file}"

    if [[ ! -f $path || -L $path ]]; then
        continue
    fi
    
    filesize=$(du -sb "${path}" | awk "{ print \$1 }")
    
    msg "Sauvegarde fichier '$file'...."
    if backupFileToDest "$path" "$filesize"; then
        msg "Fichier '$file' size=$(hrb $filesize) transféré !" 'success'
    else
        msg "Fichier '$file' size=$(hrb $filesize) ne peut pas être transféré !" 'warning'
        nbFilesError=$(( nbFilesError++ ))
    fi

    nbFiles=$(( nbFiles++ ))
done

cleanup

msg "Fin du backup to ${METHOD}. Nombre de fichiers traités = ${nbFiles}. Nombre de fichiers en erreur = ${nbFilesError}"

sendMail "Sauvegarde ${METHOD} - OK"
