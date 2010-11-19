#!/bin/bash
#
# Common functions for Lorea scripts
#

test -z "$LOREA_DIR" -o ! -d "$LOREA_DIR" && exit 0
test -f "$HOME/.config/lorea/rc" && . $HOME/.config/lorea/rc
#TOP=$(cd $(dirname $(dirname $0)) && pwd)
TOP="$LOREA_DIR"
BIN="$TOP/bin"
LIB="$TOP/lib"
LOG="$TOP/log"
ETC="$TOP/etc"
TMP="$TOP/tmp"

ELGG="$TOP/elgg"
HUB="$TOP/hub"

# Utilities

_ask_user() {
    local opts="$1"
    read $opts -p '     => '
}

as_lorea_user() {
    test -z "$LOREA_USER" && return 1
    sudo -u $LOREA_USER "$@"
}

fail() {
    say "lorea: $@"
    exit 1
}

log() {
    echo "$@" >> /tmp/lorea.log
}

say() {
    test -z "$BATCH_MODE" && echo "$@"
    log "$@"
}

# Lorea Help

_lorea_help() {
    test -z "$LOREA['HELP']" -a -f "$LIB/lorea_help.sh" && . "$LIB/lorea_help"
}

lorea_help() {
    _lorea_help

    local help_command="lorea_help_$1"
    if type "$help_command" 2>/dev/null >&2; then
        $help_command "$@"
        exit $?
    fi
    _lorea_usage
}

# Lorea commands

lorea_hub() {
    cat <<EOF

    lorea hub

    List local nodes

EOF
}

lorea_node() {
    local command="$1"
    case "$command" in
        id)
            shift; lorea_node_id "${1:-$LOREA_HOST}" "${2:-$LOREA_USER}";;
        new)  
            shift; lorea_node_new "$@";;
        reset)
            shift; lorea_node_reset "$1" "$2" "$3" "$4";;
        *)
            lorea_help_node;;
    esac
}

lorea_node_id() {
    test -z "$LOREA_HOST" -o -z "$LOREA_USER" && return 1

    _hub_for_node

    local etc_node_id="$HUB/$LOREA_HOST/node_id"
    if [ ! -f $etc_node_id ]; then
        local node_id=`echo "$LOREA_USER@$LOREA_HOST\n$(lorea_etc_secret $LOREA_HOST)" | sha1sum | (read a b; echo $a)`
        touch $etc_node_id && chmod 0640 $etc_node_id && echo "$node_id" > $etc_node_id
    fi
    test -r $etc_node_id && echo "$node_id" #cat "$etc_node_id"
}

lorea_node_new() {
    test -z "$LOREA_HOST" && . $ETC/templates/personal-node.sh
    test -n "$LOREA_HOST" -a -f $ETC/nodes/config-$LOREA_HOST && . $ETC/nodes/config-$LOREA_HOST

    while getopts "g:h:H:i:N:P:R:u:U:" OPTION
    do
        case OPTION in
            g) WWW_GROUP=$OPTARG;;
            h) LOREA_HOST=$OPTARG;;
            H) DB_HOST=$OPTARG;;
            i) LOREA_IP=$OPTARG;;
            N) DB_NAME=$OPTARG;;
            P) DB_PASS=$OPTARG;;
            R) DB_ROOT=$OPTARG;;
            u) LOREA_USER=$OPTARG;;
            U) DB_USER=$OPTARG;;
            *) 
                echo "lorea: unknown argument -$OPTION" >2
                ;;
        esac
    done

    lorea_status_node
    read -e -p " *  Press Enter to continue, or a number to change the corresponding field: " 
    case "$REPLY" in
        1) # -g -u
            say "  Permissions Settings: LOREA_USER and WWW_GROUP"
            say
            say "       Unless you're using apache2-mpm-tki, you should keep these "
            say "       settings untouched. ($LOREA_USER:$WWW_GROUP)"
            say
            say "    LOREA_USER owns the installation."
            say "    WWW_GROUP runs the web service.  It needs to access some files"
            say "        and write to others.  It is set to the defaut Apache group."
            _ask_update "LOREA_USER"
            _ask_update "WWW_GROUP"
            ;;
        2) # -h -i
            say "  VirtualHost Settings: LOREA_HOST and LOREA_IP"
            say
            say "  LOREA_HOST is the fully qualified host name of your node."
            say "  If LOREA_IP is 127.0.0.1, LOREA_HOST will be added in /etc/hosts."
            say "  LOREA_IP can also be *, and the Elgg/Lorea node will listen on all interfaces,"
            say "  in which case /etc/hosts won't be updated."
            _ask_update "LOREA_HOST"
            _ask_update "LOREA_IP"
            ;;
        3) # LOREA_ENV
            _ask_update "LOREA_ENV"
            ;;
        4) # DB_HOST
            _ask_update "DB_HOST"
            ;;
        5) # DB_NAME
            _ask_update "DB_NAME"
            ;;
        6) # DB_USER
            _ask_update "DB_USER"
            ;;
        7) # DB_PASS
            _ask_update "DB_PASS"
            ;;
        8) # DB_ROOT
            _ask_update "DB_ROOT"
            ;;
        *)
            break
            ;;
    esac
    lorea_status_node
}

_ask_update() {
    local var="$1"
    echo "  $var is set to $(eval echo \$$var)"
    if "DB_PASS" = "$var" -o "DB_ROOT" = "$var"; then
        _ask_user -s
    else
        _ask_user
    fi
    if -z "$REPLY"; then
        echo "  Value unchanged"
    else
        "$var"="$REPLY"
        echo "  Value set to '$REPLY'"
    fi
}

lorea_node_reset() {
    local host="$1"
    local db_name="$2"
    local user="${3:-$(id -un)}"
    local group="${4:-www-data}"
    
    if [ ! -d $HUB/$host ]; then
        say "Cannot reset '${host}': unknown node."
	return 1;
    fi

    echo " -  Resetting Elgg installation for $host"
    sudo rm -f $ELGG/.htaccess $ELGG/engine/settings.php 
    sudo rm -rf $HUB/$host/settings.php $HUB/$host/data/*
    echo " -  MySQL operations on $db_name"
    read -e -s -p "    + Enter MySQL root password: " db_pass
    mysqladmin -u root -p$db_pass drop $db_name create $db_name &&\
    sudo restart mysql &&\
    echo " -  Apache operations" &&\
    sudo /etc/init.d/apache2 restart 2>&1 >/dev/null &&\
    echo " -  Running pre-install hook" &&\
    lorea_trigger pre-install "$host" "$user" "$group" &&\
    echo " *  Fresh Elgg at http://$host/" || echo "Reset failed."
}

# Setup

lorea_setup() {
    if [ "help" = "$1" ]; then
        lorea_help_setup
        return 0
    fi

    test -d "$HOME/.config/lorea" || _installer_run_user_setup
    . $HOME/.config/lorea/rc
    test -d "$LOREA_DIR"          || _installer_clone_lorea_node_git
    test -d "$ELGG"               || _installer_init_elgg_git 

    lorea_setup_status
}

lorea_setup_user() { _installer_run_user_setup; }

_lorea_env() {
    test -n "$LOREA_ENV" && return 0
    cat <<EOF

lorea: LOREA_UNV is not set.

    This variable tells lorea where to get the supporting code.
    If you contribute to lorea-node you may set it to 'development'.
    For most people, 'production' will provide a stable installation.

    [1] Set it to production (stable code)
    [2] Set it to development (unstable code)

EOF
    read -e -i 1 -p '     => '
    case "$REPLY" in
        1) declare -x LOREA_ENV="production";;
        2) declare -x LOREA_ENV="development";;
        *) declare -x LOREA_ENV="production";; # default to production
    esac
}

_installer_init_elgg_git() {
    test -d "$ELGG" && return 0

    _lorea_env

    cd $LOREA_DIR

    local gsa="git submodule add"
    local repo="https://github.com/lorea/Elgg.git"
    local branch="master"
    test "development" = "$LOREA_ENV" && branch="development" && gsa="$gsa -b $branch"
    $gsa $repo elgg && git submodule init elgg && git submodule update elgg
}

_installer_run_user_setup() {
    mkdir -m 0700 "$HOME/.config/lorea" || true
    local extra_config=""
    local o=
    for var in ${!LOREA_@}; do
        o=$(eval echo \$$var)
        test -z "$var" && echo "  $var is not set" || echo "  $var=\"$o\""
        echo " *  Change $var or press Enter to continue"
        read -e -i "$o" -p '    => ' val
        if [ -n "$val" -a "$val" != "$o" ]; then
            $var="$val"
            extra_config=$(echo -e "$var=\"$val\"\n$extra_config")
            echo "  $var set to $val"
        else
            echo "  $var unchanged ($o)"
        fi
    done
    cat > "$HOME/.config/lorea/rc" <<EOF
# -*- Mode: shell-script -*-
#
## User Configuration for lorea-node
#
# This is a shell fragment sourced by the lorea command.
# DO NOT EDIT THIS FILE: use the 'lorea setup' command instead.
#
## LOREA_DIR
#
# Path to your local copy of the lorea-node Git repository.
#
# You can override the default ~/lorea-node to point to your own repo.
# For a shared installation, you might use /usr/share/lorea/.
# 
LOREA_DIR="$LOREA_DIR"
#
# You can override any default configuration by setting a different
# value in this file.  All values are defined in etc/lorearc.
#
$extra_config
#
# File generated at $(date +%F_%T) by $0
#
EOF
    mkdir -m 0755 "$HOME/.local/share/lorea" || true
}

lorea_setup_status() {
    echo -e "\n  .:| Lorea Setup For $LOREA_USER |:.\n"
    echo "  Local repository:   $LOREA_DIR"
    if [ ! -d "$LOREA_DIR/.git" ]; then
        echo "  - The lorea-node repository is missing."
    fi
    if [ -x $(which lorea) ]; then
        echo "  + The lorea command is in PATH."
    else
        echo "  - The lorea command is not in PATH."
    fi
    if [ -d $ELGG ]; then
        echo "  + Elgg 1.8 sources are present."
    else
        echo "  - Elgg 1.8 sources are missing."
    fi
    if [ -d $HUB ]; then
        echo "  + $(lorea_status_node_count)"
    else
        echo "  - To create your first node, type lorea node new"
    fi
    if [ -d $ELGG/mod/lorea_framework ]; then
        echo " + Lorea Framework is present"
    else
        echo " - Lorea Framework is not installed."
    fi
}

lorea_setup_apache() {
    test -z "$LOREA_HOST" -o -z "$LOREA_IP" -o -z "$LOREA_DIR" && return 1
    _lorea_env

    local vhost_conf="/etc/apache2/sites-available/$LOREA_HOST"

    if [ -f "$vhost_conf" ]; then
        echo "    - Configuration already exists!  Backing up to $vhost_conf.old"
        sudo cp $vhost_conf $vhost_conf.old
    fi
    # Create or update Apache configuration
    sed -e \
        "s/LOREA_HOST/$LOREA_HOST/g; \
        s/LOREA_IP/$LOREA_IP/g; \
        s#LOREA_DIR#$LOREA_DIR#g; \
        s/LOREA_ENV/$LOREA_ENV/g" \
        $ETC/apache2/lorea.example.net > $TMP/$LOREA_HOST
    sudo mv $TMP/$LOREA_HOST $vhost_conf
    sudo chown root:root $vhost_conf
    sudo chmod 0644 $vhost_conf

    _etc_hosts
    
    sudo a2enmod rewrite &>/dev/null
    sudo a2ensite $LOREA_HOST &>/dev/null
    test -z $conf_changed && sudo /etc/init.d/apache2 restart
}

lorea_setup_dirs() {
    test -d $TMP || mkdir -p $TMP/{cache,pids,sockets}
}

# Update /etc/hosts if we're a local node
# @TODO check that IP is local and that DNS resolves before
#       changing /etc/hosts
# @TODO support custom names/local IPs
_etc_hosts() {
    if [ "$LOREA_USER.lorea.local" = "$LOREA_HOST" -a '*' != "$LOREA_IP" ]; then
        grep $LOREA_HOST /etc/hosts &>/dev/null
        if [ 1 -eq $? ]; then
            # New entry
            sudo su -c "cat < '$LOREA_IP    $LOREA_HOST' >>/etc/hosts"
        else
            # Existing entry
            sudo sed -ie "s/^.*$LOREA_HOST/$LOREA_IP\t$LOREA_HOST/" /etc/hosts
        fi
    fi
}

lorea_setup_tools() {
    # Setup Myamoto
    say " + Setting up Myamoto (noop)"
    # Setup Cryptobot
    say " + Setting up Cryptobot (noop)"
    if [ "127.0.0.1" = "$LOREA_IP" ]; then
        # Local node: setup Desktop tools
        say " + Setting up Desktop tools (noop)"
    fi
}

lorea_setup_config() {
    local var="$1"
    local val="$2"

    $LOREA["$var"]="$val"
}

#lorea_installer_install_framework() {
#    # Fetch all modules according to LOREA_ENV 
#    # Link them into the elgg/mod dir.
#    if [ -x git ]; then
#        as_lorea_user "cp etc/_gitmodules.$LOREA_ENV .gitmodules"
#        as_lorea_user "git submodules update --init"
#        for module in `/bin/ls plugins`; do
#            local d=$(basename $module)
#            test -x elgg/mod/$d || ln -s $(absolute_path $module) $(absolute_path elgg/mod/)
#        done
#    else
#        say "xxx Oops...  Not implemented: you need git."
#    fi
#    echo 0
#}

lorea_installer_elgg_prereqs() {

    say "=== Checking for Elgg 1.8 Dependencies ==="

    if [ "$(php5 -v | (read a b c; echo $b))" > "5.2" ]; then
        HAVE_PHP5="yes"
    else
        say "The installed version of PHP is too old. (Need >=5.2)"
        HAVE_PHP5="no"
    fi

}

lorea_installer_setup_user() {
    test -z "$LOREA_USER" -o -z "$WWW_GROUP" && return 1

    grep $WWW_GROUP /etc/group &>/dev/null
    if [ 1 -eq $? ]; then
        # Create custom group
        sudo addgroup $WWW_GROUP
    fi

    id -un $LOREA_USER &>/dev/null
    if [ 1 -eq $? ]; then 
        # Create user
        # The --gid expects Debian-like users with primary group the username
        sudo adduser --system \
            --home /home/$LOREA_USER \
            --gecos "Lorea User" \
            --gid $(id -g $WWW_GROUP) \
            --shell /bin/bash \
            $LOREA_USER
    fi

}

lorea_status() {
    local command="lorea_status_$1"
    if ! -z "$1" -a type "$command" 2>/dev/null >&2; then
        shift
        $command "$@"
    else
        test -d "$ELGG" -a -$(lorea help &>/dev/null && true || false) \
            && echo "installed" || echo "not-installed"
    fi
}

lorea_status_dump() {
cat <<EOF

 Lorea Directory: $TOP
 Lorea Nodes:     $HUB
$(for n in $(/bin/ls $HUB); do
    node=$(basename $n)
    echo -e "    $(lorea_node_id $node)\t$node"
done) Elgg Install:    $ELGG

 Lorea is $(lorea_status)

EOF
}

# _current_node [host]
#
# Get current or Switch to new host
#
_current_node() {
    # If we can't return anything interesting, bail out
    test -z "$1" -a -z "$LOREA_HOST" && return 1
    # Target host is already current host.  Reload settings?
    test -n "$LOREA_HOST" -a "$LOREA_HOST" = "$1" && return 0
    # Validate host context
    local host=${1:-$LOREA_HOST}
    test -f "$ETC/nodes/config-$host" && . "$ETC/nodes/config-$host"
}

lorea_status_node() {
    local host="${1:-$LOREA_HOST}"
    _current_host "$host"

cat <<EOF

  .:| Lorea Node Installer Configuration |:.

    Installation Directory: $LOREA_DIR
[1] User:Group:             $LOREA_USER:$WWW_GROUP
[2] VirtualHost:            $LOREA_HOST on $LOREA_IP
[3] |_ ELGG_ENVIRONMENT:    $LOREA_ENV
    |_ ELGG_SETTINGS:       $HUB/$LOREA_HOST/settings.php
    \__>> $(test -f $HUB/$LOREA_HOST/settings.php && echo INSTALLED || echo NOT INSTALLED).

    Database Setup:

[4]     DB Name:            $DB_NAME
[5]     DB Host:            $DB_HOST
[6]     DB User:            $DB_USER
[7]     DB Password:        $(test -z $DB_PASS && echo "Unset" || echo '(not shown)')
[8]     DB Pass for root:   $(test -z $DB_ROOT && echo "Unset" || echo '(not shown)')

EOF
}

lorea_status_node_count() {
    local count=0
    local comment="You hub counts %s node%s"

    test -d $HUB && count=$(find $HUB -type d -mindepth 1 -maxdepth 1 | wc -l)

    case "$count" in
        0) printf "$comment" "no" ".";;
        1) printf "$comment" "1" ".";;
        *) printf "$comment" "$count" "s.";;
    esac
}

lorea_setup_init() {
    test -d $ELGG || lorea_setup_elgg_repo
    test -d $TMP  || lorea_setup_dirs
}

_etc_nodes() {
    test -d $ETC/nodes || mkdir -m 0700 $ETC/nodes
}

_etc_safe() {
    test -d $ETC/safe || mkdir -m 0700 $ETC/safe
}

lorea_etc_secret() {
    _etc_safe

    local keyfile=$(_keyfile "$LOREA_HOST")

    test -r "$keyfile" && cat "$keyfile"
}

_keyfile() {
    local keyfile="$ETC/safe/key-$1"

    if [ ! -f "$keyfile" ]; then
        touch "$keyfile" && chmod 0600 "$keyfile" && \
            head -n 64 /dev/urandom | \
            tr -dc 'a-zA-Z0-9_! @#$%^&*()_+\./{}|:<>?=-' | \
            fold -w 64 | head -c 2048 > "$keyfile"
    fi
    echo "$keyfile"
}

lorea_hub_for_node() {
    local node="$HUB/$LOREA_HOST"
    test -d "$node" && return 0

    mkdir -p -m 0750 "$node"
    mkdir    -m 2770 "$node/data"
    mkdir    -m 0710 "$node/gpg"
    mkdir -p -m 0710 "$node/ssl/private"
    sudo chown -R "$LOREA_USER":"$WWW_GROUP" "$node"
}

lorea_trigger() {
    local hook="$LIB/run-$1.sh"
    if [ ! -x "$hook" ]; then
        echo "Unknown hook: $hook."
	return 1
    fi
    shift
    $hook "$@"
}
