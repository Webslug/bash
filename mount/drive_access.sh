#!/bin/bashsudo ntfsfix /dev/sdb1
sudo ntfsfix /dev/sdc2
sudo ntfsfix /dev/sdd2

sudo mkdir -p /media/kim/TV
sudo mkdir -p /media/kim/F
sudo mkdir -p /media/kim/G

sudo nano /etc/fstab

#add these to grub
UUID=32DC18A8DC1867FD /media/kim/TV ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,windows_names 0 0
UUID=4E6857BA6857A00F /media/kim/F ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,windows_names 0 0
UUID=322A07462A070697 /media/kim/G ntfs-3g uid=1000,gid=1000,dmask=022,fmask=133,windows_names 0 0
