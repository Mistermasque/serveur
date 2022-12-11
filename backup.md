# Base de données MariaDB

Pour sauvegarder uniquement les bases de données MariaDB, on peut utiliser le script mysqlbackup. On pert du principe que les sauvegardes sont faites dans **/backup/mariadb**.

- https://github.com/padosoft/mysqlbackup.sh
- https://doc.ubuntu-fr.org/logrotate
- https://doc.ubuntu-fr.org/anacron

Installer MysqlBackup.sh dans /opt/mysqlbackup

```bash
cd /opt/
git clone https://github.com/padosoft/mysqlbackup.sh.git mysqlbackup
cd mysqlbackup
chmod +x mysqlbackup.sh
```

Créer le fichier de configuration
```bash
cp mysqlbackup.config.template mysqlbackup.config.template
```

Modifier les variables :
```bash
DBUSER="<user mariadb avec droits mysqldump>"
DBPASS="<pass>"
DBOPTION="-f"
DEFPATH="/backup/mariadb/"
DATA=`/bin/date +"%a"`
MYSQLBIN="/usr/bin/mysql"
MYSQLDUMPBIN="/usr/bin/mysqldump"
```

## Activer la sauvegarde auto et le log

Créer les 2 fichiers suivants :
- [/opt/mysqlbackup/mysqlbackup.cron](./opt/mysqlbackup/mysqlbackup.cron)
- [/opt/mysqlbackup/mysqlbackup.logrotate](./opt/mysqlbackup/mysqlbackup.logrotate)


Activer la sauvegarde avec anacron :
```bash
cd /etc/cron.weekly
ln -sfn /opt/mysqlbackup/mysqlbackup.cron mysqlbackup
```

Activer la rotation des logs :
```bash
cd /etc/logrotate.d/mysqlbackup
ln -sfn /opt/mysqlbackup/mysqlbackup.logrotate mysqlbackup
```

# Rclone

Rclone est un utilitaire de synchronisation permettant de se connecter à de nombreux services via la ligne de commande. Nous utiliserons le service pclone.

