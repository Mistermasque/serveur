# Installation avec Yunohost

Nextcloud est déjà packagé avec Yunohost et toutes les optimisations sont intégrées. Installer Nextcoud via l'interface.

Activer TOTP pour tous les utilisateurs.

# Activer les tâches de fond
- https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/background_jobs_configuration.html#systemd

Inutile avec Yunohost car une configuration de cron est automatiquement ajoutée dans **/etc/cron.d/nextcloud**.

Ajouter les fichiers suivants dans **/etc/systemd/system/** :
- [nextcloudcron.service](etc/systemd/system/nextcloudcron.service)
- [nextcloudcron.timer](etc/systemd/system/nextcloudcron.timer)

Activer le service :
```bash
systemctl enable --now nextcloudcron.timer

```

Changer la configuration dans l'interface d'admin de Nextcloud (Paramètres de base) en mettant Cron pour Tâches de fond.

# Optimisations

- https://github.com/YunoHost-Apps/nextcloud_ynh/issues/73
- https://docs.nextcloud.com/server/12/admin_manual/configuration_files/files_locking_transactional.html?highlight=redis
- https://help.nextcloud.com/t/nextcloud-having-lots-of-trouble-handling-large-amount-of-files/22364

Nextcloud suit déjà les optimisations recommandées (mise en cache avec REDIS, etc.)

# Customisations

Ajouter le script de lancement des commandes [occ](./usr/bin/occ) dans **/usr/bin/**. Ne pas oublier de le rendre exécutable.

# Résolution des problèmes

Si on a une désynchronisation entre ce qui est affiché dans l'interface web et les fichiers sur le disque dur, lancer la commande :
```bash
sudo occ files:scan &lt;user&gt;
```
