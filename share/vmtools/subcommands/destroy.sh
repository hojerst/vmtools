#!/bin/bash

usage() {
    cat <<EOF
NAME
    vm destroy - destroy a virtual machine

SYNOPSIS
    vm destroy [options] name

OPTIONS
    --domain=<x>              dns domain of the vm
    --(no-)remove-storage,-d  remove storage
    --(no-)force,-f           do not ask
EOF
    exit 1
}

# parse positional parameter
parsepositional() {
    local pos="$1"
    local arg="$2"

    case "$pos" in
        x)
            NAME="$arg"
            ;;
        *)
            echo 1>&2 "unknown argument: '$arg'"
            exit 1
            ;;
    esac
}

# parse arguments
parseargs() {
    local pos="x"
    local i
    local tmp

    while [ $# -ge 1 ] ; do
        case "$1" in
            --help)
                usage
                ;;
            --force|-f)
                FORCE=y
                ;;
            --no-force)
                FORCE=n
                ;;
            --remove-storage|-d)
                REMOVESTORAGE=y
                ;;
            --no-remove-storage)
                REMOVESTORAGE=n
                ;;
            --)
                shift
                break
                ;;
            --*)
                echo 1>&2 "unknown option '$1' - ignored."
                ;;
            *)
                parsepositional "$pos" "$1"
                pos="x$pos"
                ;;
        esac
        shift
    done

    # parse remaining positional arguments
    while [ $# -ge 1 ] ; do
        parsepositional "$pos" "$1"
        pos="x$pos"
        shift
    done

    # check if all positional arguments where provided
    if [ "$pos" != "xx" ] ; then
        echo 1>&2 "missing/insufficient arguments."
        echo
        usage
    fi
}

main() {
    # parse arguments
    parseargs "$@"

    ### sanity checks
    if ! virsh dominfo "$NAME" >/dev/null 2>&1 ; then
        echo "vm does not exist - nothing to do"
        exit 0
    fi

    ### summary
    if [ "$FORCE" != "y" ] ; then
        if [ "$REMOVESTORAGE" = "y" ] ; then
            echo "remove vm $NAME and all of its data"
        else
            echo "remove vm $NAME (disks are kept)"
        fi
        echo
        echo "continue [y/N]? "
        read answer
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ] ; then
            exit 0
        fi
    fi

    ### main
    case "$(virsh domstate "$NAME")"
        in paused|running)
            log_action "destroying vm"
            virsh destroy "$NAME"
            ;;
    esac

    if [ "$REMOVESTORAGE" = "y" ] ; then
        log_action "removing vm and storage"
        virsh undefine --remove-all-storage "$NAME"
    else
        log_action "removing vm"
        virsh undefine "$NAME"
    fi

    if [ ! -z "$DOMAIN" ] ; then
        log_action "removing key from known hosts"
        ssh-keygen -R "$NAME.$DOMAIN"
    fi
}