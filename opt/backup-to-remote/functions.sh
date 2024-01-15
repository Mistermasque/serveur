#!/bin/bash
########### CONFIGURATION ##########
# Send mail to admins group
declare -r MAIL="admins"
# Fichier de log
declare -r LOGFILE="/var/log/backup-to-remote.log"

######## VARIABLES GLOBALES ########
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
        echo $MESSAGES | mail -s "$subject" $MAIL
    fi
}
