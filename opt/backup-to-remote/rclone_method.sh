#!/bin/bash
# Methode de sauvegarde vers RCLONE

########### CONFIGURATION ##########
# Le remote uniquement le nom (avec les ":"")
RCLONE_REMOTE='pcloud-crypt:'
# Le répertoire de destination sans / à la fin
RCLONE_DEST="${RCLONE_REMOTE}/yunohost_archives"
# (boolean) indique si le remote est crypté ou non
RCLONE_REMOTE_CRYPTED=true

############ FONCTIONS ###########

# Vérifie si rclone est installé
checkDependencies() {
    if ! command -v "rclone" &> /dev/null
   then
      abord "Command rclone non trouvée. merci de l'installer avant d'utiliser ce script.
Voir https://rclone.org/install/ pour les instruction d'installation."
   fi
}

# Récupère la place disponible sur le remote
# @param $1 string le remote à tester
function getAvalaibleDiskSpaceOnRemote() {
    local remote="$1"
    rclone about --json ${remote} | grep "free" | sed 's/.*"free": *\([^,}]*\).*/\1/'
}

execute() { 
   local conf_name="$1"
   local name=$(stoml "$CONFIG_FILE" remotes.$conf_name.name)
   local local_path=$(stoml "$CONFIG_FILE" remotes.$conf_name.local_path)
   local remote_path=$(stoml "$CONFIG_FILE" remotes.$conf_name.remote_path)
   local sync_younger_than=$(stoml "$CONFIG_FILE" remotes.$conf_name.sync_younger_than)

   msg "Execute sync for remote '$name'..."

   local cmd="rclone sync \"$local_path\" \"${name}:${remote_path}\""

   if [[ $VERBOSE = true ]]; then
      cmd="$cmd -v"
   fi

   if [[ -n $sync_younger_than ]]; then
      cmd="$cmd --max-age"
   fi
   
   msg "$cmd" 'verbose'
}

function prepare() {
    checkDependencies
    return 0
}

# Fonction permetant de déterminer si le remote est crypté ou non
# $1 string le nom du remote
# return 0 si crypté 1 si non
function isRemoteCrypted() {
    local remote="$1"

    rclone listremotes --long | grep "$remote" | grep -q crypt
    return $?
}

# Fonction de vérification du fichier local et distant sur le remote
# $1 string fichier source (chemin complet)
# $2 string le répertoire contenant le fichier distant
function checkFile() {
    local srcFile="$1"
    local destFile="$2"
    local cmd="check"

    if isRemoteCrypted "$RCLONE_REMOTE"; then
        cmd="cryptcheck"
    fi

    rclone $cmd "$srcFile" "$destFile" >> "$LOGFILE" 2>&1

    return $?
}

# Fonction de sauvegarde du fichier local vers distant
# $1 le fichier local à sauvegarder (chemin complet)
# $2 la taille du fichier à sauvegarder
function backupFileToDest() {
    local srcFile="$1"
    local srcFileSize="$2"
    local filename=$( basename "$srcFile" )
    local destFile="${RCLONE_DEST}/${filename}"

    # Vérification qu'il y a assez de place pour sauvegarder le fichier
    local remoteAvailableSpace=$(getAvalaibleDiskSpaceOnRemote "${RCLONE_REMOTE}")

    if [[ $remoteAvailableSpace -lt $srcFileSize ]]; then
        msg "Place insuffisante sur le remote (espace restant = $(hrb ${remoteAvailableSpace}). On tente de faire de la place..." "warning"
        
        if [[ $VERBOSE = true ]]; then
            msg "Liste des fichiers à supprimer supérieurs à 3 mois:" "verbose"
            msg $(rclone --min-age "3M" lsl "${RCLONE_DEST}") "verbose"
        fi
        rclone --min-age "3M" delete "${RCLONE_DEST}"

        remoteAvailableSpace=$(getAvalaibleDiskSpaceOnRemote "${RCLONE_REMOTE}")
        msg "Espace après suppression anciens fichiers = $(hrb ${remoteAvailableSpace})" "verbose"

        if [[ $remoteAvailableSpace -lt $srcFileSize ]]; then
            msg "Impossible de faire suffisamment de place sur le remote" 'warning'
            return 1
        fi
    fi

    if ! rclone copy "${srcFile}" "${RCLONE_DEST}"; then
        msg "Le fichier '${srcFile}' ne peut pas être transféré sur le remote '${RCLONE_DEST}'" 'error'
        return 2
    fi

    msg "Vérification du fichier ${filename}..."
    if ! checkFile "${srcFile}" "${RCLONE_DEST}/"; then
        msg "Le fichier local et le distant sont différents. Un problème est survenu pendant la copie" 'error'
        rclone deletefile "${destFile}"
        return 2
    fi

    return 0
}

function cleanup() {
    return 0
}
