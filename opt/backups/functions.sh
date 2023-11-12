#!/bin/bash
########### CONFIGURATION ##########
# Send mail to admins group
declare -r MAIL="admins"

######## VARIABLES GLOBALES ########
# set verbosity (true|false)
declare VERBOSE=false
# Les traces sont inscrites dans le fichier de log
declare LOG=false

############ FONCTIONS ###########

# Message function
# $1 : message to print
# $2 : message type success|error|warning|verbose|info|<null>
msg() {
    local msg="$1"
    local type="${2-info}"
    local prefix=''
    local now=''
    
    case "${type}" in
        'success')
            prefix="[OK] "
        ;;
        'error')
            prefix="[ERROR] "
            dest=">&2"
        ;;
        'warning')
            prefix="[WARN] "
        ;;
        'verbose')
            if [[ $VERBOSE = false ]]; then
                return
            fi
        ;;
    esac

    
    if [[ $LOG = true ]]; then
        now="$(date "+%Y-%m-%d %H:%M:%S") "
        printf '%s%s%s\n' "$now" "$prefix" "$msg"
    elif [[ $type = 'error' ]]; then
        printf '%s%s\n' "$prefix" "$msg" >&2
    else
        printf '%s%s\n' "$prefix" "$msg"
    fi
}

# Function to tell to abord script
# Allows to send a message to mail before exit
# $1 : abording message
abord() {
    local msg="$1"
    
    if [[ -n $MAIL ]]; then
        echo "$msg" | mail -s "Yunohost backup rclone - ERROR" $MAIL
    fi
    
    msg "$msg" "error"
    
    exit 1
}
