
# Installation

- https://wiki.debian.org/fr/DebianInstall
- https://yunohost.org/fr/install/hardware:vps_debian


Installer la debian à partir du live USB. (Balena Etcher permet de créer un liveUSB à partir ISO debian netinstall)


Mettre un mot de passe root et ne pas créer d'utilisateur.

Ensuite installer Yunohost (en tant que root) :
```bash
apt install curl
curl https://install.yunohost.org | bash
```

Réaliser la post installation :
```bash
yunohost tools postinstall
```

# Partitionnement des disques

## Partitionnement en RAID 5 avec LVM

<span style="color:red;">L'usage de RAID 5 avec LVM semble avoir posé des problèmes et empêche de correctement redimensionner les partitions.
On utilisera donc une solution de partitionnement avec btrf sur RAID 5 logiciel.</span>

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

# Partitionnement avec btrfs et RAID

- https://linuxhint.com/btrfs-filesystem-mount-options/
- https://btrfs.readthedocs.io/en/latest/Administration.html
- https://debian-facile.org/doc:systeme:btrfs
- https://blog.flozz.fr/2022/05/22/btrfs-revolution-ou-catastrophe-ou-en-est-on-aujourdhui/


On installe le système comme suit :
- 1 disque SSD contenant les partitions :
   - /
   - swap
   - /var/lib/mysql
- 3 disques sur RAID 5 contentant les partitions :
   - /home

L'ensemble des partitions seront formatées en btrfs pour plus de performances.

Mettre les options supplémentaires :
- /var/lib/mysql : noatime nodev noexec

# Améliorer lisibilité des disques avec UDEV

Permet de définir des liens symboliques dans /dev basé sur le numéro de port SATA et sur le port USB utiltisé

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

Créer les fichiers suivants dans **/etc/udev/rules.d/** :
- [**20-disk-bays.rules**](./etc/udev/rules.d/20-disk-bays.rules).
- [**21-usb-disk.rules**](./etc/udev/rules.d/21-usb-disk.rules).

Exemple de règle :
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

```bash
sudo apt install smartmontools
```

# Sécurisation

## Certificats GANDI

https://nginx.org/en/docs/http/configuring_https_servers.html
https://jlecour.github.io/ssl-gandi-nginx-debian/


