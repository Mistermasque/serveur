
# Installation

Installer la debian à partir du live USB.
https://wiki.debian.org/fr/DebianInstall


# Partitionnement en RAID 5

- https://doc.ubuntu-fr.org/raid_logiciel
- https://linuxfr.org/news/gestion-de-volumes-raid-avec-lvm
- https://wiki.archlinux.org/title/disk_quota
- https://www.theitblogg.com/2016/10/create-logical-volume-using-maximum-available-free-space/

On utilise LVM en utilisant la fonctionnalité RAID 5. Cete fonctionnalité n'est pas directement accessible via l'outil de partitionnement sous Debian.


Pendant installation via ssh, au moment du partitionnement :
- Créer un groupe de volumes vg_system
- Intégrer les 3 disques au volume groupe vg_system
- Revenir en arrière pour avoir avoir le menu et basculer sur une console

Créer les volumes logiques en raid dans la console :

```bash
lvcreate --size 10G --name lv_root --type raid5 --nosync vg_system
lvcreate --size 1G --name lv_swap vg_system
lvcreate --size 5G --name lv_backup --type raid5 vg_system
lvcreate -l 100%FREE --name lv_home --type raid5 vg_system

mkfs.ext4 -L root /dev/vg_system/lv_root
mkfs.ext4 -L home /dev/vg_system/lv_home
mkfs.ext4 -L backup /dev/vg_system/lv_backup
mkswap -L swap /dev/vg_system/lv_swap
```

Mettre dans le fstab :
```bash
# <file system>                 <mount point>   <type>  <options>               <dump>  <pass>
/dev/mapper/vg_system-lv_root   /               ext4    errors=remount-ro       0       1
/dev/mapper/vg_system-lv_swap   none            swap    sw                      0       0
/dev/mapper/vg_system-lv_backup /backup         ext4    defaults,nodev,noexec   0       2

# Partition data gère acl et quotas utilisateurs (srjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv1)
# https://wiki.archlinux.org/title/disk_quota
/dev/mapper/vg_system-lv_home   /home           ext4    defaults,nodev,noexec,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv1,acl    0       2

```


# Améliorer lisibilité des disques avec UDEV

Permet de définir des liens symboliques dans /dev basé sur le numéro de port SATA

- https://linux.die.net/man/8/udev
- https://wiki.debian.org/Persistent_disk_names

Vérification des disques après branchement et de leur path :
```bash
udevadm info --query=path --name=/dev/sdX
```
Exemple de retour
```bash
devices/pci0000:00/0000:00:1f.2/ata1/host0/target0:0:0/0:0:0:0/block/sdb
```

Créer le fichier [**20-disk-bays.rules**](./etc/udev/rules.d/20-disk-bays.rules).  Créer une règle :

```conf
KERNEL=="sd?", SUBSYSTEM=="block", \
DEVPATH=="/devices/pci0000:00/0000:00:1f.2/ata1/host0/target0:0:0/0:0:0:0*", \
SYMLINK+="hdd1", \
RUN+="/usr/bin/logger Disque connecté port SATA1 KERNEL=$kernel, DEVPATH=$devpath" \
GOTO="END_20_DISK_BAY"
```
**GOTO** permet d'aller à la fin du fichier pour ne pas perturber la création des liens symboliques des partitions

# Activer gestion SMART des disques

- https://wiki.debian-fr.xyz/Smartmontools


## Gestion des disques logiques


Créer les disques avec RAID :

lvcreate --size 10G --name lv_root --type raid5 vg_system
lvcreate --size 10G --name lv_swap --type raid5 vg_system
lvcreate -l 100%FREE --name lv_data --type raid5 vg_system


Commandes utiles :


# Sécurisation

## Certificats GANDI

https://nginx.org/en/docs/http/configuring_https_servers.html
https://jlecour.github.io/ssl-gandi-nginx-debian/


# Lignes de commande plus sympa

## Liquidprompt

## alias



