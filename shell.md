# liquidprompt

Liquidprompt permet de changer le Prompt Bash ou Zsh pour ajouter plein d'infos sympas.

- https://github.com/nojhan/liquidprompt
- https://github.com/pyenv/pyenv/wiki/Unix-shell-initialization

Installer liguidprompt :

```bash
apt install liquidprompt
cd /usr/share/liquidprompt
```

copier **liquidpromptrc-dist** dans **/etc/liquidpromptrc**

créer le fichier **/etc/profile.d/liquidprompt.sh** :

```bash
# Chargement de liquidprompt pour tous les utilisateurs bash
. /usr/share/liquidprompt/liquidprompt
```

Ajouter le fichier aliases.sh dans /etc/profile.d/ contenant tous les alias utiles

Ajouter le fichier dircolors.sh dans /etc/profile.d/


# Oh My ZSH

Oh my Zsh est une extension à Zsh permettant d'ajouter beaucoup de fonctionnalités interressantes comme des prompt sympa, des alias et des fonctions très utiles.



## Installation Zsh et configuration des users

On installe zsh :
```bash
apt install zsh
```

On l'active pour le user et pour root :

```bash
chsh -s $(which zsh) # Pour le user courant
sudo chsh -s $(which zsh) # pour root
sudo chsh -s $(which zsh) <user> # pour le user <user>
```

## Installation Antigen

Antigen est un gestionnaire de paquets pour zsh.

- https://phuctm97.com/blog/zsh-antigen-ohmyzsh

On install git (nécessaire pour antigen) :
```bash
apt install git
```

On install Antigen dans **/opt/antigen** :
```bash
mkdir -p /opt/antigen
cd /opt/antigen
curl -L git.io/antigen > antigen.zsh
```

Création du fichier de configuration Antigen [/opt/antigen/antigenrc](./opt/antigen/antigenrc)

Création du script de chargement antigen [/opt/antigen/load-antigen.zsh](./opt/antigen/load-antigen.zsh)

Chargement de antigen dans le fichier **/etc/zsh/zshrc**. Ajouter les lignes suivantes à la fin :
```bash
# Chargement de antigen
source /opt/antigen/load-antigen.zsh
```

Installation de command-not-found utile pour le bundle command-not-found :
```bash
apt install command-not-found
```

# MOTD

Permet d'afficher l'état des partitions et du système à la connexion.

- https://wordpress.entropy.nu/index.php/2020/05/13/activate-debian-10-buster-dynamic-motd/


Voir les fichiers [etc/update-motd.d](./etc/update-motd.d/)