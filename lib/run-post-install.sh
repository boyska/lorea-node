#!/bin/sh
#
# Elgg Post-Install Script
#
# Perform some permissions changes for increased security.
# Especially useful on shared hosts.
#

if [ -z "$ELGG" -a -z "$HUB" ]; then
    echo "This script is called from the lorea command"
    exit 0
fi

user=${2:-$(whoami)}    # not web user!
group=${3:-www-data}    # web user native group
host=${1:-$user.lorea.local}  # VirtualHost

CFG="$HUB/$host"

echo "Running Post-installation Hook for $host"
echo " - user \t$user"
echo " - group\t$group"
echo 
echo "Press Enter to continue or C-c (^C) to abort."
read dummy

sudo chown $user:$group $ELGG $ELGG/engine
sudo chmod 0755 $ELGG
sudo chmod 0750 $ELGG/engine

sudo chown $user:$group $CFG $CFG/data
sudo chmod 0750 $CFG
sudo chmod 2770 $CFG/data

test -f $CFG/settings.php && {
    sudo chown $user:$group $CFG/settings.php
    sudo chmod 0640         $CFG/settings.php
}

sudo chmod g-s $ELGG $ELGG/engine $CFG
