#
# This is a shell fragment.
# 
# It should be called by issuing the following command:
#
#  lorea node new
#
## Installation Permissions
#
# == LOREA_USER
#
# The installation owner.
# If you install a node for yourself, that would be you.
# For a public node, you would create a specific user, e.g. lorea.
#
# Default: LOREA_USER="$(id -un)"
#
LOREA_USER="$(id -un)"
#
# == WWW_GROUP
#
# The Web user doesn't need full access to the Lorea installation.
# This setting defaults to the Apache2 user's group.  If you're using
# TKI, you want to change this setting to match Apache's configuration
# for that host.
#
# Default: WWW_GROUP="www-data"
# WWW_GROUP="$(grep APACHE_RUN_GROUP /etc/apache2/envvars | awk -F= '{ print $2; }')"
#
WWW_GROUP="$(grep APACHE_RUN_GROUP /etc/apache2/envvars | awk -F= '{ print $2; }')"
#
## VirtualHost Settings
#
# == LOREA_IP
#
# The IP of your Apache2 VirtualHost configuration.
# Tip: it can be * to listen an all interfaces.
#
# Default: LOREA_IP="127.0.0.1"
#
LOREA_IP="127.0.0.1"
#
# == LOREA_HOST
#
# Enter the fully qualified domain name for your Lorea node.
#
# Default: LOREA_HOST="lorea.local"
#
LOREA_HOST="$LOREA_USER.lorea.local"
#
## Database Settings
#
# The lorea command can take care of creating and interacting with the
# Elgg databases.  Each node can and should use a different user with
# full access to its own database.
#
# == DB_HOST
#
# Where MySQL is running.  On a single node, that would be localhost.
#
# Default: DB_HOST="localhost"
#
DB_HOST="localhost"
#
# == DB_NAME
#
# The node's own database.  Each node must have its own.
#
# Default: DB_NAME="lorea_node_$(lorea_node_id $LOREA_HOST $LOREA_USER)"
#
DB_NAME="lorea_node_$(lorea_node_id $LOREA_HOST $LOREA_USER)"
#
# == DB_USER
#
# The node's own database user.  Each node should have its own.
#
# Default: DB_USER="lorea"
DB_USER="lorea"
#
# == DB_PASS
#
# MySQL password for DB_USER.  If unset, lorea will ask the user.
#
# Default: DB_PASS=
DB_PASS=
#
# == DB_ROOT
#
# MySQL administrator password.  If unset, lorea will ask the user.
#
# Default: DB_ROOT=
DB_ROOT=
#
## End
