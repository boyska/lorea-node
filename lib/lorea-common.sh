#!/bin/bash
#
# Common functions for Lorea scripts
#

test -z "$LOREA_DIR" -o ! -d "$LOREA_DIR" && exit 0
test -f "$HOME/.config/lorea/rc" && . $HOME/.config/lorea/rc

_TOP()  { echo "$LOREA_DIR";   }
_BIN()  { echo "$(_TOP)/bin";  }
_ELGG() { echo "$(_TOP)/elgg"; }
_ETC()  { echo "$(_TOP)/etc";  }
_HUB()  { echo "$(_TOP)/hub";  }
_LIB()  { echo "$(_TOP)/lib";  }
_LOG()  { echo "$(_TOP)/log";  }
_TMP()  { echo "$(_TOP)/tmp";  }

_current_user() {
    if [ "$(id -un)" != "$LOREA_USER" ]; then
        command="sudo su - $LOREA_USER -c %s"
    else
        command="%s"
    fi
    $(printf $command "$@")
}

_lorea_env() {
    test -n "$LOREA_ENV" && return 0
    cat <<EOF

lorea: LOREA_ENV is not set.

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

_lorea_log() {
    _current_user "mkdir -m 0710 -p $(_LOG)" || true
}

_lorea_tmp() {
   _current_user "mkdir -m 0710 -p $(_TMP)" || true
}

## Utilities
. "$(_LIB)/lorea_utils"

# Set $REPLY to user input
_ask_user() {
    local opts="$1"
    read $opts -p '     => '
}

_ask_update() {
    local var="$1"
    local silent=

    if [ "DB_PASS" = "$var" -o "DB_ROOT" = "$var" ]; then
        silent=true
    fi
    if [ -z "$silent" ]; then
        local val="$(eval echo \$$var)"
        if [ -z "$val" ]; then
            echo "  $var is not set"
        else
            echo "  $var is set to $val"
        fi
        _ask_user
    else
        echo "  $var (not shown)"
        _ask_user -s
    fi
    if [ -z "$REPLY" ]; then
        echo "  Value unchanged"
    else
        eval "$var=\"$REPLY\""
        test -z "$silent" && echo "  Value set to '$REPLY'" || echo -e "\n  Value changed"
    fi
}

fail() {
    say "lorea: $@"
    exit 1
}

log() {
    local TMP=$(test -d "$(_TMP)" && echo $(_TMP) || echo /tmp)
    echo "$@" >> $TMP/lorea.log
}

say() {
    test -z "$BATCH_MODE" && echo "$@"
    log "$@"
}

## Lorea commands

_not_implemented() {
    fail "command not implemented."
}

lorea_help() {
    . "$(_LIB)/lorea_help"

    local help_command="lorea_help_$1"
    if type "$help_command" 2>/dev/null >&2; then
        $help_command "$@"
        exit $?
    fi
    _lorea_usage
}

lorea_hub() {
    _not_implemented
}

lorea_node() {
    . "$(_LIB)/lorea_node"

    local command="$1"
    case "$command" in
        id)
            shift; lorea_node_id "${1:-$LOREA_HOST}" "${2:-$LOREA_USER}";;
        new)  
            shift; lorea_node_new "$@";;
        reset)
            shift; lorea_node_reset "$1" "$2" "$3" "$4";;
        *)
            lorea_help node;;
    esac
    exit $?
}

lorea_setup() {
    . "$(_LIB)/lorea_setup"

    lorea_setup_dirs

    if [ "help" = "$1" ]; then
        lorea_help setup
        return 0
    fi

    test -d "$HOME/.config/lorea" || _installer_run_user_setup
    test -f $HOME/.config/lorea/rc && . $HOME/.config/lorea/rc
    test -d "$LOREA_DIR"          || _installer_clone_lorea_node_git
    test -d $(_ELGG)              || _installer_init_elgg_git 

    lorea_setup_status
}

lorea_status() {
    . "$(_LIB)/lorea_status"

    local command="lorea_status_$1"
    type "$command" 2>/dev/null >&2
    if [ 0 -eq $? -a ! -z "$1" ]; then
        shift
        $command "$@"
    else
        test -d "$(_ELGG)" -a -$(lorea help &>/dev/null && true || false) \
            && echo "installed" || echo "not-installed"
    fi
}

lorea_trigger() {
    local hook="$(_LIB)/run-$1.sh"
    if [ ! -x "$hook" ]; then
        echo "Unknown hook: $hook."
	return 1
    fi
    shift
    ELGG=$(_ELGG) HUB=$(_HUB) $hook "$@"
}
