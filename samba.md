# Présentation

L'idée est de mettre en place le partage de fichier Windows en l'interconnectant avec le serveur LDAP configuré pour Yunohost et les répertoires utilisateurs de NextCloud.
On aura donc la configuration suivante :
- Un accès en lecture seule et de manière anonyme au répertoire /home/yunohost.multimedia
- Un accès avec login / mot de passe LDAP aux répertoires user /home/yunohost.app/nextcloud/&lt;user&gt;/data/files/

Il faudra donc mapper le user pour se connecter avec le user nextcloud pour l'accès au répertoire home

Il existe une application Yunohost Samba mais elle présente encore trop de problèmes et ne permet pas la configuration fine des partages. ON va toutefois l'utiliser partiellement pour la gestion.


# Installation

- https://forum.yunohost.org/t/how-to-turn-yunohost-into-a-nas-with-samba/18034
- https://github.com/YunoHost-Apps/samba_ynh
- https://yunohost.org/en/packaging_apps_hooks


Installer l'application Samba dans Yunohost.

Supprimer le répertoire **share** dans l'interface de configuration.

Supprimer le répertoire **/home/yunohost.app/samba/shared/**

Supprimer le fichier **/etc/samba/smb.conf.d/share.conf**


## Activer la découverte du serveur

Apparemment, la découverte Netbios n'est plus supportée depuis Windows 10.
Et activer le protocole smbv1 n'est pas une bonne idée.

Il est préférable d'implémenter la découverte via les webservices.

- https://github.com/christgau/wsdd

# Configuration

Créer les fichiers suivants :
- [/etc/samba/smb.conf.d/0-global.conf](./etc/samba/smb.conf.d/0-global.conf)
- [/etc/samba/smb.conf.d/multimedia.conf](./etc/samba/smb.conf.d/multimedia.conf)
- [/etc/samba/smb.conf.d/nextcloud.conf](./etc/samba/smb.conf.d/nextcloud.conf)


Mettre à jour le fichier de configuration :
```bash
echo '' > /etc/samba/smb.conf
cat /etc/samba/smb.conf.d/*.conf >> /etc/samba/smb.conf
```

Relancer samba :
```bash
sudo systemctl restart smbd
```

**Ne surtout pas utiliser l'interface de configuration de Yunohost pour mettre à jour la conf des partages.**

# Aide

Pour tester la configuration Samba, utiliser testparm :
```bash
testparm -v
```