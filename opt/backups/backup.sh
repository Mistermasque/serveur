#!/bin/bash
set -euo pipefail
# Script d'envoi des sauvegardes sur les différents supports cible


########### CONFIGURATION ##########
# Répertoire source contenant les fichiers à transférer
declare -r SRC_DIR="/home/yunohost.backup/archive"
# Patern de recherche des fichiers d'archive
declare -r SRC_FILES_PATERN='^[0-9]{8}-[0-9]{6}\.(tar|info\.json|tar\.gz)$'


######## VARIABLES GLOBALES ########
# Le répertoire du script
declare -r ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Liste des méthodes disponibkes
declare -ra METHODS=$(ls "$ROOT_DIR" | grep "_method.sh*" | sed s/'_method.sh'//g )


source "$ROOT_DIR/functions.sh"

############ FONCTIONS ###########


# Aide à l'usage du script
usage() {
    cat << USAGE
Script d'envoi des sauvegardes sur une destination.
Usage : $0 [OPTIONS]

Options :
    -h : affiche cette aide
    -l : traces dans le fichier de log
    -m <method> : la méthode de sauvegarde.
    <method> : $(echo ${METHODS[@]} )
    -v : mode verbeux
USAGE
}

loadMethod() {
    local method="$1"
    
    msg "Chargement méthode '${method}'..." 'verbose'
    
    if [[ ${METHODS[@]} =~ $method ]]; then
        source "${ROOT_DIR}/${method}_method.sh"

        if [[ $(type -t backupFileToDest) != function ]]; then
            msg "Le fichier de méthode '${method}_method.sh' ne contient pas la fonction 'backupFileToDest'" 'error'
            exit 2
        fi

        if [[ $(type -t prepare) != function ]]; then
            msg "Le fichier de méthode '${method}_method.sh' ne contient pas la fonction 'prepare'" 'error'
            exit 2
        fi

        if [[ $(type -t cleanup) != function ]]; then
            msg "Le fichier de méthode '${method}_method.sh' ne contient pas la fonction 'cleanup'" 'error'
            exit 2
        fi
    else
        msg "Methode '${method}' inexistante" 'error'
        usage
        exit 1
    fi
}

####### MAIN ########

while getopts "hm:" arg; do
    case $arg in
        h)
            usage
            exit 0
        ;;
        l)
            LOG=true
        ;;
        m)
            loadMethod "$OPTARG"
        ;;
        v)
            VERBOSE=true
    esac
done

prepare

ls -t "$SRC_DIR" | egrep "$SRC_PATERN" | while read file; do
    local filesize=$(du -sb "${file}" | awk "{ print \$1 }")
    
    msg "Backup file '$file'...."
    if backupFileToDest "$file" "$size"; then
        msg "File '$file' size=$filesize saved !" 'success'
    else
        msg "File '$file' size=$filesize cannot be saved !" 'warning'
    fi

done

cleanup
