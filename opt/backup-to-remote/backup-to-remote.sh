#!/bin/bash
set -eo pipefail
# Script d'envoi des sauvegardes sur les différents supports cible


########### CONFIGURATION ##########
# Répertoire source contenant les fichiers à transférer
declare -r SRC_DIR="/home/yunohost.backup/archives"
# Patern de recherche des fichiers d'archive
declare -r SRC_FILES_PATERN='^[0-9]{8}-[0-9]{6}\.(tar|info\.json|tar\.gz)$'
# Send mail to admins group
declare -r MAIL="admins"
# Fichier de log
declare -r LOGFILE="/var/log/backup-to-remote.log"

######## VARIABLES GLOBALES ########
# Le répertoire du script
declare -r ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Liste des méthodes disponibles
declare -ra METHODS=$(ls "$ROOT_DIR" | grep "_method.sh*" | sed s/'_method.sh'//g )
# set verbosity (true|false)
declare VERBOSE=false
# N'affiche pas les traces sur la sortie standard
declare QUIET=false
# Les messages
declare MESSAGES=''
# La méthode utilisée
declare METHOD=''

############ FONCTIONS ###########

loadMethod() {

    if [[ -z $1 ]]; then
        msg "Le nom de la méthode est absent !" 'error'
        exit 2
    fi

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

    METHOD="$method"
}

# Message function
# $1 : message to print
# $2 : message type success|error|warning|verbose|info|<null>
msg() {
    local message="$1"
    local type="${2-info}"
    local prefix=''
    
    case "${type}" in
        'success')
            prefix="[OK] "
        ;;
        'error')
            prefix="[ERREUR] "
            dest=">&2"
        ;;
        'warning')
            prefix="[ALERTE] "
        ;;
        'verbose')
            if [[ $VERBOSE = false ]]; then
                return
            fi
        ;;
    esac

    local now="$(date "+%Y-%m-%d %H:%M:%S") "
    local logMsg=$(printf '%s%s%s\n' "$now" "$prefix" "$message")

    MESSAGES="$MESSAGES
$logMsg"
    echo "$logMsg" >> "$LOGFILE"

    
    if [[ $QUIET = false ]]; then
        if [[ $type = 'error' ]]; then
            printf '%s%s\n' "$prefix" "$message" >&2
        else
            printf '%s%s\n' "$prefix" "$message"
        fi
    fi
}

# Function to tell to abord script
# Allows to send a message to mail before exit
# $1 : abording message
abord() {
    msg "$1" "error"
    sendMail "Backup to ${METHOD} - ERREUR"
    
    exit 1
}

# Fonction utilisée pour convertir une taille en octets vers une valeur en KiO, MiO, GiO...
# $1 : la valeur en octets
# Résultat est affiché en echo
hrb() {
    local bytes="$1"
    numfmt --to=iec-i --suffix=O --format="%9.2f" $bytes | sed s/' '//g
}

# Fonction utilisée pour convertir une taille écrite en valeur humaine vers une taille en octets (inverse de hrb)
# $1 string la valeur en octets kilos octets ....
# Résultat est affiché en echo
bhr() {
    local humanBytes=echo "$1" | sed s/'\.'/','/g
    humanBytes="${humanBytes}i"

    numfmt --from=iec-i $humanBytes
}

# Fonction permettant d'envoyer le mail
# $1 objet
sendMail() {
    local subject="$1"
    if [[ -n $MAIL ]]; then
        echo $MESSAGES | mail -s "$subject" $MAIL
    fi
}

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

for file in $( ls -t "$SRC_DIR" | egrep "$SRC_FILES_PATERN" ); do

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
        nbFilesError=$(( nbFilesError + 1 ))
    fi

    nbFiles=$(( nbFiles + 1 ))
done

cleanup

msg "Fin du backup to ${METHOD}. Nombre de fichiers traités = ${nbFiles}. Nombre de fichiers en erreur = ${nbFilesError}"

sendMail "Sauvegarde ${METHOD} - OK"
