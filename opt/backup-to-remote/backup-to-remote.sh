#!/bin/bash
set -e
# Script d'envoi des sauvegardes sur les différents supports cible


########### CONFIGURATION ##########
# Répertoire source contenant les fichiers à transférer
declare -r YNH_BACKUP_DIR="/home/yunohost.backup/archives"
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

        if [[ $(type -t listRemoteBackups) != function ]]; then
            msg "Le fichier de méthode '${method}_method.sh' ne contient pas la fonction 'listRemoteBackups'" 'error'
            exit 2
        fi

        if [[ $(type -t getRemoteInfo) != function ]]; then
            msg "Le fichier de méthode '${method}_method.sh' ne contient pas la fonction 'getRemoteInfo'" 'error'
            exit 2
        fi
        
        if [[ $(type -t backupToDest) != function ]]; then
            msg "Le fichier de méthode '${method}_method.sh' ne contient pas la fonction 'backupToDest'" 'error'
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

    MESSAGES="$MESSAGES\n$logMsg"
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
        echo -e "$MESSAGES" | mail -s "$subject" $MAIL
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

# Vérifie si l'archive Yunohost est valide
# $1 string : le nom de l'archive
checkBackup() {
    local backupName="$1"
    local infoFile="${YNH_BACKUP_DIR}/${backupName}.info.json"
    local tarFile="${YNH_BACKUP_DIR}/${backupName}.tar"

}

# Récupère la date au format timestamp à partir du contenu du fichier info de l'archive
# le résultat est affiché sur la sortie standard
# @param $1 string le contenu du fichier info.json
getDateFromInfo() {
    echo "$1" | sed s/'.*"created_at": \([0-9]*\).*'/'\1'/g
}

# Vérifie si le backup 1 est plus récent que le backup 2
# @param $1 string infoBackup1 le contenu json du backup 1
# @param $2 string infoBackup2 le contenu json du backup 2
# @return 0 si plus récent 1 sinon
function isBackupYounger() {
    local infoBackup1="$1"
    local infoBackup2="$2"

    if echo "$infoBackup1" | grep -qv "created_at"; then
        abort "isBackupYounger : infoBackup1 ne contient pas 'created_at'"
    fi

    if echo "$infoBackup2" | grep -qv "created_at"; then
        abort "isBackupYounger : infoBackup2 ne contient pas 'created_at'"
    fi

    local timestamp1=$(getDateFromInfo "$infoBackup1")
    local timestamp2=$(getDateFromInfo "$infoBackup2")

    if [[ ${timestamp1} -gt ${timestamp2} ]]; then
        return 0
    fi

    return 1
}

# Vérifie si le backup 1 est plus récent que le timestamp
# @param $1 string infoBackup le contenu json du backup
# @param $2 integer la date heure au format timestamp à comparer
# @return 0 si plus récent backup est plus récent que le timestamp 1 sinon
function isBackupYoungerThanTimestamp() {
    local infoBackup="$1"
    local timestamp="$2"

    if echo "$infoBackup" | grep -qv "created_at"; then
        abort "isBackupYoungerThanTimestamp : infoBackup ne contient pas 'created_at'"
    fi

    if echo "$timestamp" | grep -qv "^[0-9]+$"; then
        abort "isBackupYoungerThanTimestamp : timestamp n'est pas un entier"
    fi

    local backupTimestamp=$(getDateFromInfo "$infoBackup")

    if [[ ${backupTimestamp} -gt ${timestamp} ]]; then
        return 0
    fi

    return 1
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
    shift
done

loadMethod "$1" 
shift

msg "Démarrage backup to ${METHOD}..."

prepare $*
err=$?

if [[ $err -eq 1 ]]; then
    abord "Erreur au démarrage du script !"
elif [[ $err -ge 2 ]]; then
    cleanup
    abord "Erreur au démarrage du script !"
fi

# Liste des backups locaux disponibles triés par ordre du plus récents au plus ancien
localBackups=$(ls -t "$YNH_BACKUP_DIR" | grep ".info.json" | sed s/'.info.json'//g)
# Liste des backups sur le remote au même format que le backup local
remoteBackups=$(listRemoteBackups)
# Liste des backups à sauvegarder
declare -a backupsToSave=()

msg "Liste des backups locaux : ${localBackups}" "verbose"
msg "Liste des backups distants : ${remoteBackups}" "verbose"

for localBackup in ${localBackups}; do
    addBackupToList=true
    localInfo=$(cat "${YNH_BACKUP_DIR}/${localBackup}.info.json")
    for remoteBackup in ${remoteBackups}; do
        remoteInfo=$(getRemoteInfo "$remoteBackup")
        if [ "${localBackup}" = "${remoteBackup}" ] || isBackupYounger "$remoteInfo" "$localInfo"; then
            addBackupToList=false 
            break
        fi
    done
    if [[ $addBackupToList = true ]]; then
        backupsToSave+=("$localBackup")
    fi
done

nbFiles=0
nbFilesError=0

if [[ ${#backupsToSave[@]} -eq 0 ]]; then
    msg "Aucun élément à transférer."
else
    msg "Liste des backups à transférer : ${backupsToSave[@]}"

    for backup in ${backupsToSave[@]}; do

        infoFilePath="${YNH_BACKUP_DIR}/${backup}.info.json"
        backupFilePath=$(find /home/yunohost.backup/archives -mindepth 1 -name "${backup}.tar*" ! -type l | head -1)
        size=$(du -sb "${backupFilePath}" | awk "{ print \$1 }")
        timestamp=$(getDateFromInfo "$(cat "$infoFilePath")")

        if backupToDest "$backup" "$infoFilePath" "$backupFilePath" "$size" "$timestamp"; then
            msg "Backup '$backup' size=$(hrb $size) transféré !" 'success'
        else
            msg "Backup '$backup' size=$(hrb $size) ne peut pas être transféré !" 'warning'
            nbFilesError=$(( nbFilesError + 1 ))
        fi
    done
fi

cleanup

msg "Fin du backup ${METHOD}. Nombre de fichiers traités = ${nbFiles}. Nombre de fichiers en erreur = ${nbFilesError}"

if [[ $nbFilesError -eq 0 ]]; then
    sendMail "Sauvegarde ${METHOD} - OK"
else
    sendMail "Sauvegarde ${METHOD} - ERREUR"
fi
