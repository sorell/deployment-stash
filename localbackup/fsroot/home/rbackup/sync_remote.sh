#!/bin/sh

######################################################
# Make changes below according to your configuration #
######################################################

# The file containing key for opening the luks encrypted disk in the remote site.
DISK_KEY=<SET_ME>
# The file containing key to access local device's root (for rsync). Key to root.. In user home dir.. I know.
LOCAL_ROOT_SSH_KEY=<SET_ME>

# URL to the local backup device.
LBACKUP_HOSTNAME=<SET_ME>
# SSH port to the local backup device.
LBACKUP_SSHPORT=<SET_ME>

# Path to the local copy of backup data
LOCAL_DATA_PATH=<SET_ME>

# Private key of the local rbackup user. Used to contact the remote site device.
RBACKUP_SSH_KEY=${HOME}/.ssh/<SET_ME>

############################
# Don't change these below #
############################

HOSTNAME=$(hostname)

#SSH_OPTS="-i ${RBACKUP_SSH_KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_OPTS="-i ${RBACKUP_SSH_KEY}"

set -f
set -- $SSH_ORIGINAL_COMMAND
case "$1" in
	"./sync_remote.sh")
	echo "$HOSTNAME: Start sync"
	;;
	"./pls_send_disk_key.sh")
	echo "$HOSTNAME: Provide disk key"
	scp $SSH_OPTS -P $2 ${DISK_KEY} root@localhost:$3 >/dev/null
	exit 0
	;;
	"./pls_send_ssh_key.sh")
	echo "$HOSTNAME: Provide ssh key"
	scp $SSH_OPTS -P $2 ${LOCAL_ROOT_SSH_KEY} root@localhost:$3 >/dev/null
	exit 0
	;;
	*)
	echo "$HOSTNAME: Are you Hackerman?"
	exit 1
esac

shift

# 1st param: The remote creates an ssh tunnel for us to contact itself. This is the tunnel's port in local device end.
SSH_TUN_PORT=$1
# 2nd param: Path to the backup data in remote device.
REMOTE_DATA_PATH=$2
# 3rd param: The ssh private key the remote device uses to dial rbackup on the local device.
LBACKUP_SSH_KEY=$3


error() {
	echo "$HOSTNAME: ERROR: $1"; exit 1
}

fifo=$(mktemp -u)

ssh $SSH_OPTS -p ${SSH_TUN_PORT} -t root@localhost '
	cleanup() {
		echo "$HOSTNAME: Cleanup from $1"
		rm -fr '${fifo}'
		echo "$HOSTNAME: Umount"
		umount /mnt/localbackup
		echo "$HOSTNAME: Close disk"
		cryptsetup luksClose sda_crypt
		exit $1
	}
	error() {
		echo "$HOSTNAME:ERROR: $1"; cleanup 1
	}
	trap "cleanup 1" INT HUP TERM EXIT
	rm -fr '${fifo}'
	mkfifo -m 600 '${fifo}'
	echo "$HOSTNAME: Open disk"
	cryptsetup luksOpen /dev/sda sda_crypt --key-file='${fifo}' &
	crpid=$!
	sleep 1
	ps -p $crpid >/dev/null  ||  error luksOpen
	echo "$HOSTNAME: Request disk key"
	ssh -t -i '${LBACKUP_SSH_KEY}' -p '${LBACKUP_SSHPORT}' rbackup@'${LBACKUP_HOSTNAME}' "./pls_send_disk_key.sh '${SSH_TUN_PORT}' '${fifo}'" 2>/dev/null || error lukskey
	wait $crpid
	echo "$HOSTNAME: Mount disk"
	mount /dev/mapper/sda_crypt || error mount
	echo "$HOSTNAME: Launch rsync from '${HOSTNAME}':'${LOCAL_DATA_PATH}'/ to $HOSTNAME:'${REMOTE_DATA_PATH}'/ **"
	rsync -avxz --delete -e "ssh -i '${fifo}' -p '${LBACKUP_SSHPORT}'" root@'${LBACKUP_HOSTNAME}':'${LOCAL_DATA_PATH}'/ '${REMOTE_DATA_PATH}'/ &
	rspid=$!
	sleep 1
	ps -p $rspid >/dev/null  ||  error rsync
	echo "$HOSTNAME: Request 1st ssh key"
	ssh -t -i '${LBACKUP_SSH_KEY}' -p '${LBACKUP_SSHPORT}' rbackup@'${LBACKUP_HOSTNAME}' "./pls_send_ssh_key.sh '${SSH_TUN_PORT}' '${fifo}'" 2>/dev/null || error sshkey1
	echo "$HOSTNAME: Request 2nd ssh key"
	ssh -t -i '${LBACKUP_SSH_KEY}' -p '${LBACKUP_SSHPORT}' rbackup@'${LBACKUP_HOSTNAME}' "./pls_send_ssh_key.sh '${SSH_TUN_PORT}' '${fifo}'" 2>/dev/null || error sshkey2
	trap "kill $rspid; echo \"$HOSTNAME Rsync killed\"; cleanup 2" INT HUP TERM EXIT
	echo "$HOSTNAME: Waiting for rsync"
	wait $rspid
	trap "" INT HUP TERM EXIT
	cleanup 0
'
