# Fichier permettant de charger Antigen, le gestionnaire de paquets zsh
# https://github.com/zsh-users/antigen
# Ce fichier permet de créer le fichier de chargement de antigen pour l'utilisateur
# On créé un lien symbolique vers la config par défaut si le fichier n'existe pas
source /opt/antigen/antigen.zsh


if [ ! -f "$HOME/.antigenrc" ]; then
   echo "Fichier $HOME/.antigenrc absent. Création du lien symbolique vers /opt/antigen/antigenrc"
   ln -sfn /opt/antigen/antigenrc "$HOME/.antigenrc"
fi

antigen init "$HOME/.antigenrc"
