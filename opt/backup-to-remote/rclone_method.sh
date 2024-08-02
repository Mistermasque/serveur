#!/bin/bash
# Methode de sauvegarde vers RCLONE

########### CONFIGURATION ##########
# Le remote uniquement le nom (avec les ":"")
RCLONE_REMOTE='pcloud-crypt:'
# Le répertoire de destination sans / à la fin
RCLONE_DEST="${RCLONE_REMOTE}/yunohost_archives"
# (boolean) indique si le remote est crypté ou non
RCLONE_REMOTE_CRYPTED=true

############ FONCTIONS UTILISEES DANS LE SCRIPT PRINCIPAL ###########

# Liste les backups qui sont distants
# Le résultat est affiché sur la sortie standard
function listRemoteBackups() {
    rclone lsf "$RCLONE_DEST" | grep ".info.json" | sed s/'.info.json'//g
}


# Affiche sur la sortie standard le contenu du fichier info
# @param $1 string le nom du backup
function getRemoteInfo() {
    local name="$1"

    rclone cat "${RCLONE_DEST}/${name}.info.json"
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
    if ! rclone copy "${localInfoPath}" "${RCLONE_DEST}"; then
        msg "Le fichier '${localInfoPath}' ne peut pas être transféré sur le remote '${RCLONE_DEST}'" 'error'
        return 2
    fi

    msg "Vérification du fichier d'info ${infoFilename}..." "verbose"
    if ! _checkFile "${localInfoPath}" "${RCLONE_DEST}/"; then
        msg "Le fichier d'info local et le distant sont différents. Un problème est survenu pendant la copie" 'error'
        rclone deletefile "${RCLONE_DEST}/${infoFilename}"
        return 2
    fi

    msg "Fichier d'info '${infoFilename}' transféré" "success"

    local archiveFilename=$( basename "$localArchivePath" )
    
    msg "Transfert fichier d'archive '${archiveFilename}'..." "verbose"
    if ! rclone copy "${localArchivePath}" "${RCLONE_DEST}"; then
        msg "Le fichier '${localArchivePath}' ne peut pas être transféré sur le remote '${RCLONE_DEST}'" 'error'
        rclone deletefile "${RCLONE_DEST}/${infoFilename}"
        return 2
    fi

    msg "Vérification du fichier d'archive ${archiveFilename}..." "verbose"
    if ! _checkFile "${localArchivePath}" "${RCLONE_DEST}/"; then
        msg "Le fichier d'archive local et le distant sont différents. Un problème est survenu pendant la copie" 'error'
        rclone deletefile "${RCLONE_DEST}/${archiveFilename}"
        rclone deletefile "${RCLONE_DEST}/${infoFilename}"
        return 2
    fi

    msg "Fichier d'archive '${archiveFilename}' transféré" "success"

    return 0
}

function prepare() {
    _checkDependencies
    return 0
}

function cleanup() {
    return 0
}


#################### FONCTIONS LOCALES ###############""


# Vérifie si rclone est installé
function _checkDependencies() {
    if ! command -v "rclone" &> /dev/null
   then
      abord "Command rclone non trouvée. merci de l'installer avant d'utiliser ce script.
Voir https://rclone.org/install/ pour les instruction d'installation."
   fi
}

# Récupère la place disponible sur le remote
# @param $1 string le remote à tester
function _getAvalaibleDiskSpaceOnRemote() {
    local remote="$1"
    rclone about --json ${remote} | grep "free" | sed 's/.*"free": *\([^,}]*\).*/\1/'
}



# Fonction permetant de déterminer si le remote est crypté ou non
# $1 string le nom du remote
# return 0 si crypté 1 si non
function _isRemoteCrypted() {
    local remote="$1"

    rclone listremotes --long | grep "$remote" | grep -q crypt
    return $?
}

# Fonction de vérification du fichier local et distant sur le remote
# $1 string fichier source (chemin complet)
# $2 string le répertoire contenant le fichier distant
function _checkFile() {
    local srcFile="$1"
    local destFile="$2"
    local cmd="check"

    if _isRemoteCrypted "$RCLONE_REMOTE"; then
        cmd="cryptcheck"
    fi

    rclone $cmd "$srcFile" "$destFile" >> "$LOGFILE" 2>&1

    return $?
}

# Fonction permettant de faire de la place sur le distant
# @param $1 integer la taille demandée minimale pour faire de la place
# @param $2 integer timestamp indiquant qu'il faut supprimer avant cette date
# @return 0 si OK, 1 si impossible de faire assez de place
function _makeRoomOnRemote() {
    local neededSpace=$1
    local timestamp=$2

    local remoteAvailableSpace=$(_getAvalaibleDiskSpaceOnRemote "${RCLONE_REMOTE}")
    if [[ $remoteAvailableSpace -gt $neededSpace ]]; then
        return 0
    fi

    msg "Place insuffisante sur le remote (espace restant = $(hrb ${remoteAvailableSpace}). On tente de faire de la place..." "warning"

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

            remoteAvailableSpace=$(_getAvalaibleDiskSpaceOnRemote "${RCLONE_REMOTE}")
            if [[ $remoteAvailableSpace -gt $neededSpace ]]; then
                msg "Suffisamment de place a été libérée sur le remote (espace restant = $(hrb ${remoteAvailableSpace}))" "success"
                return 0
            fi

            msg "Pas assez de place libérée (espace restant = $(hrb ${remoteAvailableSpace}). On continue..."
        fi

    done


    msg "Impossible de trouver assez de backups distants à supprimer" "warning"
    return 1
}

# Supprime un backup distant
# @param $1 string le nom du backup à supprimer
# @return 0 si ok 1 sinon
function _deleteRemoteBackup() {
    local name="$1"
    local infoFile=$(rclone lsf "$RCLONE_DEST" | grep "$name" | grep ".info.json")
    local archiveFile=$(rclone lsf "$RCLONE_DEST" | grep "$name" | grep ".tar")

    if ! rclone deletefile "${RCLONE_DEST}/${infoFile}"; then
        return 1
    fi

    if ! rclone deletefile "${RCLONE_DEST}/${archiveFile}"; then
        return 1
    fi

    return 0
}
