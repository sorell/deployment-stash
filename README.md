# deployment-stash

A set of installation scripts to quickly deploy some Linux stations I use.

localbackup
-----------
A raspberry I have for preserving my on-site backups of multiple other computers and mobile devices. Critical files are in place, but the deployment script awaits for the next installation :)

remotebackup
------------
Install a raspberry for pulling backups from localbackup.

The ssh/rsync connection is initialized in timed manner from remote site for eliminating the need to worry about its network topology.
The remote site's raspberry executes a script provided by the local site's raspberry, enabling encrypted volume unlocking and separate ssh key provision for the actual rsync mirroring. No critical keys are stored in the remote site's device. The only key stored in the device is only good for obtaining the script from the local site.
