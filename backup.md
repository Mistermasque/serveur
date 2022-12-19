# Rclone

Rclone est un utilitaire de synchronisation permettant de se connecter à de nombreux services via la ligne de commande. Nous utiliserons le service pclone.

## Installation

https://rclone.org/install/

Installer rclone avec la commande suivante :
```bash
sudo -i
curl https://rclone.org/install.sh | bash
```

## Configurer rclone avec pCloud

On va créer un echainement de config pour avoir le chemin suivant :

remote -> pcloud-crypt -> pcloud

- **remote** est un alias pour pcloud-crypt (permet de facilement changer une configuration)
- **pcloud-crypt** permet de chiffrer les données avant d'envoyer vers pcloud
- **pcloud** est le lien vers pcloud (accès à l'arborescence distante)

### Création du lien pCloud

- https://rclone.org/pcloud/
- https://rclone.org/remote_setup/

Avant de configurer pcloud, récupérer l'IP de la machine avec :
```bash
ip a
```

Sur une machine linux avec un navigateur web, on créé un tunnel SSH :
```bash
ssh -L localhost:53682:localhost:53682 <user>@<ip du serveur avec rclone>
```

Sur le serveur :
```bash
sudo rclone config
```
Aux différentes questions :
- **n** : New remote
- **pcloud** : pour le nom
- **35** : Storage Pcloud
- **&lt;vide&gt;** : laisser blanc client_id
- **&lt;vide&gt;** : laisser blanc client_secret
- **n** : pas de configuration avancée
- **y** : auto config
- Sur le PC avec le navigateur (celui sur lequel on a lancé le tunnel SSH), aller sur l'URL http://127.0.0.1:53682/auth?state=xxxxxxxxxxxxxxxxxxxx
- **y** : On valide toute la configuration


### Création du chiffrement

https://rclone.org/crypt/

La sauvegarde chiffrée sera faite dans un sous dossier sur pCloud : **/nas**.

Sur le serveur :
```bash
sudo rclone config
```

Aux différentes questions :
- **n** : New remote
- **pcloud-crypt** : pour le nom
- **14** : Encrypt/Decrypt a remote
- **pcloud:nas** : remote pcloud, sous dossier nas
- **3** : ne pas chiffrer les noms des fichiers
- **2** : ne pas chiffrer les noms des dossiers
- **g** : Générer un random password
- **1024** : Maximum
- <span style="color:red">**Enregistrer le mot de passe généré dans un endroit sécurisé !**</span>
- **y** : Valider le mot de passe
- **g** : Générer un salt (password 2)
- **128** : Secure
- <span style="color:red">**Enregistrer le salt généré dans un endroit sécurisé !**</span>
- **y** : Valider le salt
- **n** : Pas de configuration avancée
- **y** : On valide toute la configuration

### Création de l'alias

Sur le serveur :
```bash
sudo rclone config
```

Aux différentes questions :
- **n** : New remote
- **remote** : pour le nom
- **3** : Alias for an existing remote
- **pcloud-crypt:** : remote pcloud-crypt
- **y** : On valide toute la configuration

## Créer l'envoi de la sauvegarde avec Yunohost

- https://yunohost.org/fr/backup/custom_backup_methods
- https://www.blackcreeper.com/linux/supprimer-des-fichiers-selon-leur-anciennete-sous-linux/
- https://stackoverflow.com/questions/45838304/bash-delete-files-older-than-3-months
- https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
- https://forum.rclone.org/t/delete-old-files-remotely/4471
- https://rclone.org/docs/#time-option

Installer le fichier [05-rclone](./etc/yunohost/hooks.d/backup_method/05-rclone) dans **/etc/yunohost/hooks.d/backup_method/**

Ajouter la sauvegarde automatique dans le crontab :
```bash
sudo crontab -e
```

```conf
# Lancement de la sauvegarde tous les 5 du mois à 3 heures du matin
0 3 5 * * yunohost backup create --method=rclone --quiet
```

## Restaurer rclone

Pour récupérer la configuration rclone, il faut [réinstaller rclone](#installation). Mais au moment de la [création du chiffrement](#création-du-chiffrement), suivre les étapes suivantes :
- **n** : New remote
- **pcloud-crypt** : pour le nom
- **14** : Encrypt/Decrypt a remote
- **pcloud:nas** : remote pcloud, sous dossier nas
- **3** : ne pas chiffrer les noms des fichiers
- **2** : ne pas chiffrer les noms des dossiers
- **y** : Ecrire son propre mot de passe
- <span style="color:orange">Récupérer le mot de passe et le coller, il faut le valider 2 fois.</span>
- **y** : Ecrire son propre salt (passowrd2)
- <span style="color:orange">Récupérer le salt et le coller, il faut le valider 2 fois.</span>
- **n** : Pas de configuration avancée
- **y** : On valide toute la configuration


# Base de données MariaDB

## Création de l'utilisateur

On va créer un utilisateur spécifique appelé backupuser qui sera autorisé à réaliser les dumps.
<span style="color:orange">Cette opération est inutile avec Yunohost car l'utilisateur root se connecte à la base de données sans mot de passe.</span>

- https://www.linuxbabe.com/mariadb/mysqldump-backup-mariadb-databases
- http://www.tux-planet.fr/generer-des-mots-de-passe-aleatoires-sous-linux/

Générer un mot de passe aléatoire pour mariadb :
```bash
echo `< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c20`
```

Se connecter à mariadb
```bash
sudo mysql -h localhost
```

```sql
CREATE USER 'backupuser'@'localhost' IDENTIFIED BY 'secret-password';
GRANT LOCK TABLES, SELECT, PROCESS ON *.* TO 'backupuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

## Installation mysqlbackup

Pour sauvegarder uniquement les bases de données MariaDB, on peut utiliser le script mysqlbackup. On part du principe que les sauvegardes sont faites dans **/home/yunohost.backup/mariadb**.

- https://github.com/padosoft/mysqlbackup.sh
- https://doc.ubuntu-fr.org/logrotate
- https://doc.ubuntu-fr.org/anacron

Installer tous les fichiers du dossier [mysqlbackup](./opt/mysqlbackup/) dans **/opt/mysqlbackup**.

Créer le fichier de configuration
```bash
cd /opt/mysqlbackup
sudo cp mysqlbackup.config.template mysqlbackup.config
```

Modifier les variables :
```bash
DBUSER=""
DBPASS=""
DEFPATH="/home/yunohost.backup/mariadb/"
```

## Activer la sauvegarde auto et le log

Activer la sauvegarde avec anacron :
```bash
cd /etc/cron.weekly
sudo ln -sfn /opt/mysqlbackup/mysqlbackup.cron mysqlbackup
```

Activer la rotation des logs :
```bash
cd /etc/logrotate.d
sudo ln -sfn /opt/mysqlbackup/mysqlbackup.logrotate mysqlbackup
```

## Envoi de la sauvegarde avec rclone

Prerequis : avoir déja installé [rclone](#installation).

Installer tous les fichiers du dossier [rclonebackup](./opt/rclonebackup/) dans **/opt/rclonebackup**.

Créer le fichier de configuration
```bash
cd /opt/rclonebackup
sudo cp rclonebackup.config.template rclonebackup.config
```

Modifier les variables :
```bash
DIRS=('/home/yunohost.backup/mariadb/')
```

Activer l'envoi auto avec anacron :
```bash
cd /etc/cron.weekly
sudo ln -sfn /opt/rclonebackup/rclonebackup.cron rclonebackup
```

Activer la rotation des logs :
```bash
cd /etc/logrotate.d
sudo ln -sfn /opt/rclonebackup/rclonebackup.logrotate rclonebackup
```
