#!/bin/sh

###########################
# Remote backup raspberry #
###########################

# FIRST: for convenience run 'sudo systemctl start ssh'

# Remote site backup device's hostname
HOSTNAME=<SET_ME>

# Local site backup device's URL for ssh
LOCALBKUPHOST=<SET_ME>
# Local site backup device's port for ssh
LOCALBKUPPORT=<SET_ME>

# Admin account's name. For security reasons 'pi' will be removed
ADMINNAME=<SET_ME>

# External encrypted drive's mount point
DISK_MNT_POINT=<SET_ME>


BACKUP_DATA_PATH=${DISK_MNT_POINT}/backup
SSH_KEY=${HOSTNAME}-rbackup.key

if [ "$(whoami)" != "root" ]; then
	echo Run me as root
	exit 1
fi


# Install default raspberry.
# Then run this script as root on the device.

systemctl enable ssh

echo ${HOSTNAME} > /etc/hostname
sed -i -e 's/raspberrypi/'${HOSTNAME}'/g' /etc/hosts

apt-get update
apt-get install -y cryptsetup hdparm

mkdir ${DISK_MNT_POINT}
echo "/dev/mapper/sda_crypt  ${DISK_MNT_POINT}  ext4  defaults,noauto  0  2" >> /etc/fstab

cat <<'EOF' > /etc/init.d/hdpark
#!/bin/sh
# /etc/init.d/hdpark
### BEGIN INIT INFO
# Provides:          hdpark
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Set park time for USB hard disk.
# Description:       Set park time of 2 minutes for USB hard disk.
### END INIT INFO

hdparm -S 24 /dev/sda
EOF
chmod +x /etc/init.d/hdpark
update-rc.d hdpark defaults


adduser --disabled-password --gecos "" rbackup
sudo -u rbackup ssh-keygen -t rsa -b 4096 -C ${SSH_KEY} -N "" -f /home/rbackup/.ssh/${SSH_KEY}

echo '#!/bin/sh
SSH_TUN_PORT=44444
BACKUP_DATA_PATH='${BACKUP_DATA_PATH}'
SSH_KEY=~/.ssh/'${SSH_KEY}'

ssh -t -i ${SSH_KEY} -R ${SSH_TUN_PORT}:localhost:22 -p '${LOCALBKUPPORT}' rbackup@'${LOCALBKUPHOST}' "./sync_remote.sh ${SSH_TUN_PORT} ${BACKUP_DATA_PATH} ${SSH_KEY}"
' > /home/rbackup/rbackup_trigger.sh

chmod 700 /home/rbackup/rbackup_trigger.sh
chown rbackup:rbackup /home/rbackup/rbackup_trigger.sh

echo "28 9 * * * rbackup /bin/sh /home/rbackup/rbackup_trigger.sh 2>&1 >/tmp/rbackup_trigger.log" > /etc/cron.d/rbackup_trigger
chmod 755 /etc/cron.d/rbackup_trigger
/etc/init.d/cron reload


echo "Enter password for ${ADMINNAME}"
adduser --gecos "" ${ADMINNAME}

echo "${ADMINNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_${ADMINNAME}-nopasswd
chmod 440 /etc/sudoers.d/010_${ADMINNAME}-nopasswd


# TODO:
# set up cron

passwd -l pi
echo "User pi is now locked out"
echo ""
echo "TODO:"
echo "- Append /home/rbackup/.ssh/${SSH_KEY}.pub to local backup device /home/rbackup/.ssh/authorized-keys2"
echo "- Run rbackup_push_data.sh in rbackup home once manually to test connectivity and insert ${LOCALBKUPHOST}:${LOCALBKUPPORT} to ssh known_hosts"
echo ""

exit 0
