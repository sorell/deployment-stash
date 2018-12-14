#!/bin/sh

LOGFILE=/tmp/sync_remote_last_run.log
SUBJECT=
REPORT=

if [ ! -f $LOGFILE ]; then
	SUBJECT="Remote backup not run after last boot"
	REPORT="There is no log file for remote backup process."
elif ! test $(find $LOGFILE -mmin -960); then
	SUBJECT="Remote backup not run"
	REPORT="Log file for remote backup process is too old."
elif ! grep -q "with exit code 0" $LOGFILE; then
	SUBJECT="Remote backup failed"
	REPORT=$(cat $LOGFILE)
fi

if [ "$SUBJECT" != "" ]; then
	echo "Sending $SUBJECT"
	echo "From: \"Remote Backup\" <rbackup@HOSTNAME.org>
To: \"<SET_ME:NAME>\" <SET_ME:EMAIL>
Date: $(date +'%a, %d %B %Y %T %z')
Subject: $SUBJECT

$REPORT
" | ssmtp <SET_ME:EMAIL>
fi

