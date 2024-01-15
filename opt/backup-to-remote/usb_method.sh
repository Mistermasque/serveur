#!/bin/bash
# Methode de sauvegarde sur USB


########### CONFIGURATION ##########
# Disque USB à monter
declare -r USB_DISK='/dev/hdd_usb_front_haut_1'
# Sous répertoire contenant les sauvegardes
declare -r USB_REPO="yunohost_archives"

######## VARIABLES GLOBALES ########
# Mounted dest dir (without ending /) can be modified if USB_DISK is already mounted
USB_DEST_DIR="/mnt/usb_backup"

source "$ROOT_DIR/functions.sh"

############ FONCTIONS ###########

# Récupère la place disponible sur le répertoire local
# @param $1 string le répertoire à tester
function getAvalaibleDiskSpace() {
    local _path="$1"

    if [[ ! -e $_path ]]; then
        abord "getAvalaibleDiskSpace : répertoire '$_path' n'existe pas !"
    fi

    local _mountPoint=$(findmnt -T "$_path" -o SOURCE -n)
    df -B1 --output="source,avail" "$_mountPoint" | awk "{ if (\$1 == \"$_mountPoint\") { print \$2 } }"
}

function prepare() {
    msg "Montage du disque USB '${USB_DISK}'..."

    if mount | grep -q "${USB_DEST_DIR}"; then
        local _mountedDisk=$(mount | grep "${USB_DEST_DIR}" | awk "{ print \$1 }")

        if [[ $_mountedDisk != $USB_DISK ]]; then
            abord "Répertoire '${USB_DEST_DIR}' est déjà monté pour le disque'${_mountedDisk}'. Abandon."
        fi
        
        return 0
    fi
    
    if mount | grep -q "${USB_DISK}"; then
        USB_DEST_DIR=$(mount | grep "${USB_DISK}" | awk "{ print \$3 }")

        msg "Disk '${USB_DISK}' déjà monté sur '${USB_DEST_DIR}'." "warning"

        return 0
    fi

    mkdir -p "${USB_DEST_DIR}"

    if ! mount "${USB_DISK}" "${USB_DEST_DIR}" -t auto >> "$LOGFILE" 2>&1; then
        abord "Impossible de monter le disque '${USB_DISK}' sur '${USB_DEST_DIR}'. Abandon."
    fi

    msg "Disque '${USB_DISK}' monté sur '${USB_DEST_DIR}'" "success"
    return 0
}

function checkFile() {
    local _srcFile="$1"
    local _destFile="$2"

    local _md5sumLocal=$( md5sum "${_srcFile}" | awk "{ print \$1 }" )
    local _md5sumDest=$( md5sum "${_destFile}" | awk "{ print \$1 }" )

    if [[ $_md5sumLocal != $_md5sumDest ]]; then
        return 1
    fi

    return 0
}

function backupFileToDest() {
    local _destRepo="${USB_DEST_DIR}/${USB_REPO}"
    local _srcFile="$1"
    local _srcFileSize="$2"
    local _srcFilename=$( basename "$_srcFile" )

    mkdir -p "${_destRepo}"

    # Check if there is enough space on USB disk to create archive file
    local _usbAvailableSpace=$(getAvalaibleDiskSpace "${USB_DEST_DIR}")
    if [[ $_usbAvailableSpace -lt $_srcFileSize ]]; then
        msg "Place insuffisante sur le disque USB (space left = $(hrb ${_usbAvailableSpace}). On tente de faire de la place..." "warning"

        local _numberOfDays3MonthAgo=$(( ( $(date '+%s') - $(date -d '3 months ago' '+%s') ) / 86400 ))
        local _verboseArg=''
        if [[ $VERBOSE = true ]]; then
            _verboseArg='-print'
        fi
        find "$_destRepo" -mtime +$_numberOfDays3MonthAgo -type f -delete $_verboseArg >> "$LOGFILE"
        _usbAvailableSpace=$(getAvalaibleDiskSpace "${USB_DEST_DIR}")
        msg "Espace après suppression anciens fichiers = ${_usbAvailableSpace} octets" "verbose"

        if [[ $_usbAvailableSpace -lt $_srcFileSize ]]; then
            msg "Impossible de faire suffisamment de place sur le disque" 'warning'
            return 1
        fi
    fi

    if ! cp -a "${_srcFile}" "${_destRepo}"; then
        msg "Impossible de copier les fichiers sur le disque USB" 'error'
        return 2
    fi

    if ! checkFile "${_srcFile}" "${_destRepo}/${_srcFilename}"; then
        msg "Le fichier local et le distant sont différents. Un problème est survenu pendant la copie" 'error'
        rm -f "${_destRepo}/${_srcFilename}"

        return 2
    fi

    msg "Fichier local et distant identiques" "success"
    return 0
}



function cleanup() {
    # Try to unmount until device is not busy
    local _busy=true
    local _cpt=0
    cd "${ROOT_DIR}"
    msg "Démontage '${USB_DEST_DIR}'..."
    while $_busy; do
        if mountpoint -q "${USB_DEST_DIR}"; then
            if umount "${USB_DEST_DIR}" 2> /dev/null; then
                _busy=false
            else
                msg "On attend 5 sec pour démonter '${USB_DEST_DIR}'..."
                sleep 5
            fi
        else
            _busy=false
        fi
        _cpt=$(( _cpt + 1 ))
        if [[ $_cpt -gt 15 ]]; then
            break
        fi
    done

    if [[ $_busy = true ]]; then
        msg "Impossible de démonter '${USB_DEST_DIR}', vous devrez le faire manuellement" "warning"
    else
        msg "'${USB_DEST_DIR}' démonté" "success"
    fi

    return 0
}