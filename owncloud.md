Cette page présente l'installation d'owncloud sans le support de Yunohost mais manuellement sur un serveur Debian.

# Installation Owncloud


- https://www.linuxbabe.com/linux-server/setup-owncloud-9-server-nginx-mariadb-php7-debian
https://doc.owncloud.org/server/9.0/admin_manual/installation/nginx_examples.html
- https://www.reddit.com/r/OpenMediaVault/comments/czdmm4/is_it_possible_to_host_another_site_with_nginx_on/


## Configuration de la base de données 

- https://www.linuxbabe.com/linux-server/how-to-install-lemp-stack-on-debian-8-jessie-nginx-mariadb-php-fpm

```bash
apt install mariadb-server mariadb-client
mysql_secure_installation
```

Créer l'utilisateur owncloud avec sa propre base de données
```bash
mysql -u root -p
```
```sql
create database owncloud;
create user owncloud@localhost identified by 'password';
grant all privileges on owncloud.* to owncloud@localhost;
flush privileges;
exit;
```

## Installation des paquets

Dépendances requises :
```bash
apt install php7.3-zip php7.3-intl php7.3-gd php7.3-curl gnupg php7.3-mysql
```

Owncloud :
```bash
wget -O- "https://download.owncloud.org/download/repositories/production/Debian_10/Release.key" | sudo apt-key add -

echo 'deb http://download.owncloud.org/download/repositories/stable/Debian_10/ /' >> /etc/apt/sources.list.d/owncloud.list

apt update;apt install owncloud-files
```

## Création utilisateur

Créer l'utilisateur owncloud et le rendre propriétaire du dossier /var/www/owncloud
```bash
groupadd -g 800 owncloud
useradd -g owncloud -s /usr/sbin/nologin -r -u 800 owncloud
chown -R owncloud:owncloud /var/www/owncloud
```

## Configuration NGINX PHP-FPM et démarrage du serveur

Envoyer les fichiers de conf :
owncloud -> /etc/nginx/sites-available/
owncloud.conf /etc/php/7.3/fpm/pool.d/

```bash
cd /etc/nginx/sites-enable/
ln -sfn ../sites-available/owncloud

systemctl restart nginx
systemctl restart php7.3-fpm
```

Tester l'adresse https://ip-serveur:10443

Sinon vérifier les logs /var/log/nginx/owncloud.log

# Optimisations

- https://doc.owncloud.org/server/10.5/admin_manual/configuration/server/caching_configuration.html


Installer un moteur de cache mémoire
```bash
apt install php-apcu php-redis redis-server
```

Ajouter dans **/var/www/owncloud/config/config.php** :
```php
'memcache.local' => '\OC\Memcache\APCu',
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => [
    'host' => 'localhost',
    'port' => 6379,
],
```

Ajouter une tâche de cron :
```bash
crontab -u owncloud -e
```
```crontab
*/15  *  *  *  * php -f /var/www/owncloud/cron.php
```

# Réinitialiser owncloud

Supprimer les fichiers suivants dans /var/www/owncloud/config :
- config.php
- config.app.php

Supprimer le contenu du répertoire /var/www/owncloud/data

# Configuration de owncloud pour utiliser les utilisateurs locaux et les partages locaux

- https://doc.owncloud.org/server/10.3/admin_manual/configuration/user/user_auth_ftp_smb_imap.html#smb

Ajouter le support SAMBA sur OMV avec répertoire utilisateurs
```bash
apt install smclient php-smbclient
```

Ajouter le support du backend SMB dans /var/www/owncloud/config/config.php
```php
"user_backends" => [
    [
        "class"     => "OC_User_SMB",
        "arguments" => [
            'localhost'
        ],
    ],
],
```

## Monter un lecteur SMB

- https://doc.owncloud.org/server/9.1/admin_manual/configuration_files/external_storage/smb.html

