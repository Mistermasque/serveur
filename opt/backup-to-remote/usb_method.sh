# Methode de sauvegarde sur USB

########### CONFIGURATION ##########
# Disque USB à monter
USB_DISK='/dev/hdd_usb_front_haut_1'
# Mounted dest dir (without ending /) can be modified if USB_DISK is already mounted
USB_MOUNTED_DIR="/mnt/usb_backup"
# Le répertoire de destination sans / à la fin
USB_DEST="${USB_MOUNTED_DIR}/yunohost_archives"

############ FONCTIONS UTILISEES DANS LE SCRIPT PRINCIPAL ###########

# Liste les backups qui sont distants
# Le résultat est affiché sur la sortie standard
function listRemoteBackups() {
    ls "$USB_DEST" | grep ".info.json" | sed s/'.info.json'//g
}

# Affiche sur la sortie standard le contenu du fichier info
# @param $1 string le nom du backup
function getRemoteInfo() {
    local name="$1"

    cat "${USB_DEST}/${name}.info.json"
}

# Function de transfert du backup vers le remote
# @param $1 string le nom du backup
# @param $2 string le chemin d'accès au fichier info
# @param $3 string le chemin d'accès au fichier d'archive
# @param $4 integer la taille du fichier d'archive
# @param $5 integer la date heure au format timestamp de l'archive
# @return 0 si OK, 1 si impossibilité de transférer, 2 si erreur pendant le transfert 
function backupToDest() {
    local name="$1"
    local localInfoPath="$2"
    local localArchivePath="$3"
    local archiveSize=$4
    local archiveTimestamp=$5

    if ! _makeRoomOnRemote $archiveSize $archiveTimestamp; then
        msg "Impossible de faire suffisamment de place sur le remote" 'warning'
        return 1
    fi

    local infoFilename=$( basename "$localInfoPath" )

    msg "Transfert fichier d'info '${infoFilename}'..." "verbose"
    if ! cp -a "${localInfoPath}" "${USB_DEST}"; then
        msg "Le fichier '${localInfoPath}' ne peut pas être transféré sur le disque '${USB_DEST}'" 'error'
        return 2
    fi

    msg "Vérification du fichier d'info ${infoFilename}..." "verbose"
    if ! _checkFile "${localInfoPath}" "${USB_DEST}/${infoFilename}"; then
        msg "Le fichier d'info local et le distant sont différents. Un problème est survenu pendant la copie" 'error'
        rm -f "${USB_DEST}/${infoFilename}"
        return 2
    fi
    msg "Fichier d'info '${infoFilename}' transféré" "success"

    local archiveFilename=$( basename "$localArchivePath" )
    
    msg "Transfert fichier d'archive '${archiveFilename}'..." "verbose"
    if ! cp -a "${localArchivePath}" "${USB_DEST}"; then
        msg "Le fichier '${localArchivePath}' ne peut pas être transféré sur le disque '${USB_DEST}'" 'error'
        rm -f "${USB_DEST}/${infoFilename}"
        return 2
    fi


    msg "Vérification du fichier d'archive ${archiveFilename}..." "verbose"
    if ! _checkFile "${localArchivePath}" "${USB_DEST}/${archiveFilename}"; then
        msg "Le fichier d'archive local et le distant sont différents. Un problème est survenu pendant la copie" 'error'
        rm -f "${USB_DEST}/${archiveFilename}"
        rm -f "${USB_DEST}/${infoFilename}"
        return 2
    fi

    msg "Fichier d'archive '${archiveFilename}' transféré" "success"

    return 0
}

# Prépare le script a séxécuter.
# Réalise le montage du disque USB
# @param string $1 le path du device correspondant au disque USB (facultatif)
# @return 0 si OK, 1 si erreur sans besoin de cleanup, 2 si erreur avec besoin de cleanup
function prepare() {

    local alreadyMounted=false

    if [[ -n "$1" ]]; then
        if [[ ! -b $1 ]]; then
            msg "L'argument '$1' ne correspond pas à un périphérique de disque !" 'error'
            return 1
        fi
        USB_DISK="$1"
    fi

    msg "Montage du disque USB '${USB_DISK}'..."

    if mount | grep -q "${USB_MOUNTED_DIR}"; then
        local _mountedDisk=$(mount | grep "${USB_MOUNTED_DIR}" | awk "{ print \$1 }")

        if [[ $_mountedDisk != $USB_DISK ]]; then
            msg "Répertoire '${USB_MOUNTED_DIR}' est déjà monté pour le disque'${_mountedDisk}' !" 'error'
            return 1
        fi

        alreadyMounted=true
    fi
    
    if mount | grep -q "${USB_DISK}"; then
        USB_MOUNTED_DIR=$(mount | grep "${USB_DISK}" | awk "{ print \$3 }")
        alreadyMounted=true
    fi

    if [[ alreadyMounted = true ]]; then
        msg "Disk '${USB_DISK}' déjà monté sur '${USB_MOUNTED_DIR}'." "info"
    
    
    else
        if ! mkdir -p "${USB_MOUNTED_DIR}"; then
            msg "Impossible de créer le répertoire '${USB_MOUNTED_DIR}'." 'error'
            return 1
        fi

        if ! mount "${USB_DISK}" "${USB_MOUNTED_DIR}" -t auto >> "$LOGFILE" 2>&1; then
            msg "Impossible de monter le disque '${USB_DISK}' sur '${USB_MOUNTED_DIR}'." 'error'
        fi

        msg "Disque '${USB_DISK}' monté sur '${USB_MOUNTED_DIR}'" "success"
    fi

    if ! mkdir -p "${USB_DEST}"; then
        msg "Impossible de créer le répertoire '${USB_DEST}'." 'error'
        return 2
    fi

    return 0
}

function cleanup() {
    # Try to unmount until device is not busy
    local _busy=true
    local _cpt=0
    cd "${ROOT_DIR}"
    msg "Démontage '${USB_MOUNTED_DIR}'..."
    while $_busy; do
        if mountpoint -q "${USB_MOUNTED_DIR}"; then
            if umount "${USB_MOUNTED_DIR}" 2> /dev/null; then
                _busy=false
            else
                msg "On attend 5 sec pour démonter '${USB_MOUNTED_DIR}'..."
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
        msg "Impossible de démonter '${USB_MOUNTED_DIR}', vous devrez le faire manuellement" "warning"
    else
        msg "'${USB_MOUNTED_DIR}' démonté" "success"
    fi

    return 0
}


####################### FONCTIONS LOCALES ####################""


# Récupère la place disponible sur un répertoire
# @param $1 string le répertoire à tester
function _getAvalaibleDiskSpaceOnDir() {
    local _path="$1"

    if [[ ! -e $_path ]]; then
        abord "_getAvalaibleDiskSpaceOnDir : répertoire '$_path' n'existe pas !"
    fi

    local _mountPoint=$(findmnt -T "$_path" -o SOURCE -n)
    df -B1 --output="source,avail" "$_mountPoint" | awk "{ if (\$1 == \"$_mountPoint\") { print \$2 } }"
}


# Fonction de vérification du fichier local et distant sur le remote
# $1 string fichier source (chemin complet)
# $2 string fichier destination (chemin complet)
function _checkFile() {
    local _srcFile="$1"
    local _destFile="$2"

    local _md5sumLocal=$( md5sum "${_srcFile}" | awk "{ print \$1 }" )
    local _md5sumDest=$( md5sum "${_destFile}" | awk "{ print \$1 }" )

    if [[ $_md5sumLocal != $_md5sumDest ]]; then
        return 1
    fi

    return 0
}

# Fonction permettant de faire de la place sur le distant
# @param $1 integer la taille demandée minimale pour faire de la place
# @param $2 integer timestamp indiquant qu'il faut supprimer avant cette date
# @return 0 si OK, 1 si impossible de faire assez de place
function _makeRoomOnRemote() {
    local neededSpace=$1
    local timestamp=$2

    local remoteAvailableSpace=$(_getAvalaibleDiskSpaceOnDir "${USB_MOUNTED_DIR}")
    if [[ $remoteAvailableSpace -gt $neededSpace ]]; then
        return 0
    fi

    msg "Place insuffisante sur le disque USB (espace restant = $(hrb ${remoteAvailableSpace}). On tente de faire de la place..." "warning"

    local remoteBackups=$(listRemoteBackups)

    for remoteBackup in $remoteBackups; do
        remoteInfo=$(getRemoteInfo "$remoteBackup")
        
        if ! isBackupYoungerThanTimestamp "$remoteInfo" "$timestamp"; then
            msg "Suppression backup distant ${remoteBackup}..."
            if ! _deleteRemoteBackup "${remoteBackup}"; then
                msg "Erreur à la suppression backup distant ${remoteBackup} !" "error"
                continue
            else
                msg "Backup distant ${remoteBackup} supprimé"
            fi

            remoteAvailableSpace=$(_getAvalaibleDiskSpaceOnDir "${USB_MOUNTED_DIR}")
            if [[ $remoteAvailableSpace -gt $neededSpace ]]; then
                msg "Suffisamment de place a été libérée sur le disque USB (espace restant = $(hrb ${remoteAvailableSpace}))" "success"
                return 0
            fi

            msg "Pas assez de place libérée (espace restant = $(hrb ${remoteAvailableSpace}). On continue..."
        fi

    done


    msg "Impossible de trouver assez de backups sur le disque USB à supprimer" "warning"
    return 1
}

# Supprime un backup distant
# @param $1 string le nom du backup à supprimer
# @return 0 si ok 1 sinon
function _deleteRemoteBackup() {
    local name="$1"
    local infoFile=$(ls "$USB_DEST" | grep "$name" | grep ".info.json" | head -n1)
    local archiveFile=$(ls "$USB_DEST" | grep "$name" | grep "$name" | grep ".tar" | head -n1)

    if ! rm -f "${USB_DEST}/${infoFile}"; then
        return 1
    fi

    if ! rm -f "${USB_DEST}/${archiveFile}"; then
        return 1
    fi

    return 0
}
