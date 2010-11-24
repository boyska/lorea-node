#!/bin/sh
#
# Elgg Pre-Install Script
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

echo "Running Pre-installation Hook for $host"
echo " - user \t$user"
echo " - group\t$group"
echo 
echo "Press Enter to continue or C-c (^C) to abort."
read dummy

sudo chown $user:$group $ELGG $ELGG/engine
sudo chmod 2775 $ELGG $ELGG/engine

test -d $CFG || {
    mkdir -m 2770 $CFG
    mkdir -m 2770 $CFG/data
}
sudo chown $user:$group $CFG $CFG/data
sudo chmod 2770 $CFG $CFG/data
test -f $CFG/settings.php && {
    sudo chown $user:$group $CFG/settings.php
    sudo chmod 0660         $CFG/settings.php
}
