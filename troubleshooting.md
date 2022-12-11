# Remplacer un disque défectueux

- https://www.systutorials.com/docs/linux/man/7-lvmraid/

## Vérifications

Pour voir si un disque manque :
```bash
pvdisplay
```

Pour voir l'état du LVM raid :
```bash
lvs -o lv_health_status
```

Réactiver les partitions RAID5 en mode dégradé (si besoin) :
```bash
lvchange -ay --activationmode degraded lv_root
lvchange -ay --activationmode degraded lv_data
```

## Ajout du nouveau disque
1. Connecter le nouveau disque
2. Partitionner le disque avec fdisk
3. Créer 1 partition type LVM Linux
4. Créer le PV :
```bash
pvcreate /dev/sdX1
```
5. Ajouter le PV au VG
```bash
vgextend vg_system /dev/sdX1
```

## Réparation

Réparer les partitions dégradées :
```bash
lvconvert --repair /dev/vg_system/lv_root /dev/sdX1
lvconvert --repair /dev/vg_system/lv_data /dev/sdX1
```

Supprimer le disque manquant du VG :
```bash
vgreduce --removemissing vg_system
```

Puis vérifier l'état des stripes :
```bash
lvs -o+lv_layout,stripes
```
Vérifier l'état du VG :
```bash
vgdisplay
```

# Réduire la taille d'un disque logique

Vérifier le volume à réduire :
```bash
e2fsck -fy /dev/vg_system/lv_data
```

Réduire le système de fichier :
```bash
resize2fs /dev/vg_system/lv_data 4G
```

# Renommer une partition

## Partition Swap
SWAP nommer en "swap" :
```bash
swapoff /dev/vg_system/lv_swap
swaplabel -L swap
swapon
```

## Partition ext4
Partition ext4 nommer en "root" :
```bash
e2label /dev/vg_system/lv_root root
```

# Reinstaller grub après transfert d'une partition classique sur LVM

- https://www.debian-fr.org/t/lvm-sur-raid5-grub2-et-boot/56311/4
- https://unix.stackexchange.com/questions/390219/does-grub2-support-boot-on-lvm-on-md-raid

Redémarrer sur un live CD

```bash
mount /dev/vg_system/lv_root /mnt
mount --bind /dev /mnt/dev
mount --bind /run /mnt/run
mount -t proc /proc /mnt/proc
mount -t sysfs /sys /mnt/sys

chroot /mnt

grub-install --modules='lvm' /dev/sda
```

Faire de même sur les autes disques en cas d'échec
```bash
update-grub
```

Modifier le fstab après réintégration du disque.