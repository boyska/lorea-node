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

## Utilities
. "$LIB/lorea_utils"

# Set $REPLY to user input
_ask_user() {
    local opts="$1"
    read $opts -p '     => '
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

fail() {
    say "lorea: $@"
    exit 1
}

log() {
    local TMP=${TMP:-/tmp}
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
    . "$LIB/lorea_help"

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
    . "$LIB/lorea_node"

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
    exit $?
}

lorea_setup() {
    . "$LIB/lorea_setup"

    if [ "help" = "$1" ]; then
        lorea_help setup
        return 0
    fi

    test -d "$HOME/.config/lorea" || _installer_run_user_setup
    . $HOME/.config/lorea/rc
    test -d "$LOREA_DIR"          || _installer_clone_lorea_node_git
    test -d "$ELGG"               || _installer_init_elgg_git 

    lorea_setup_status
}

lorea_status() {
    . "$LIB/lorea_status"

    local command="lorea_status_$1"
    if ! -z "$1" -a type "$command" 2>/dev/null >&2; then
        shift
        $command "$@"
    else
        test -d "$ELGG" -a -$(lorea help &>/dev/null && true || false) \
            && echo "installed" || echo "not-installed"
    fi
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
