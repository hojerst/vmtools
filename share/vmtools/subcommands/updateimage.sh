#!/bin/bash

usage() {
    cat <<EOF
NAME
    updateimage - update disks for a image

SYNOPSIS
    updateimage image
EOF
    exit 1
}

# parse positional parameter
parsepositional() {
    local pos="$1"
    local arg="$2"

    case "$pos" in
        x)
            IMAGE="$arg"
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

    while [ $# -ge 1 ] ; do
        case "$1" in
            --help)
                usage
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

unpack() {
    local file="$1"
    local format

    format="$(file "$file")"
    case "$format" in
        *": bzip2 compressed"*)
            bzcat "$file" >"$WORKDIR/unpack"
            mv "$WORKDIR/unpack" "$file"
            ;;
        *": gzip compressed"*)
            zcat "$file" >"$WORKDIR/unpack"
            mv "$WORKDIR/unpack" "$file"
            ;;
    esac
}

get_size() {
    qemu-img info "$1" | sed -e '/^virtual size:/!d' -e 's/^.*(//' -e 's/ bytes.*//'
}

main() {
    parseargs "$@"

    ### sanity checks
    [ -r "$IMAGEDIR/$IMAGE/info" ] || die "$IMAGE info doesn't exist or is not readable"

    ### work dir
    WORKDIR=$(mktemp -d /tmp/updateimageXXXXXX)
    trap "rm -rf -- '$WORKDIR'" EXIT

    ### main
    source "$IMAGEDIR/$IMAGE/info"

    readonly NUMDISKS=${#DISK[*]}

    for ((i=0; i<NUMDISKS; i++)) ; do
        echo "downloading disk$i from ${DISK[i]}..."
        curl "${DISK[i]}" -Lo "$WORKDIR/image"

        echo "unpacking image (if compressed)..."
        unpack "$WORKDIR/image"
        SIZE=$(get_size "$WORKDIR/image")

        if virsh vol-info --pool "$IMAGEPOOL" "$IMAGE-disk$i" >/dev/null 2>&1 ; then
            echo "deleting old image..."
            virsh vol-delete --pool "$IMAGEPOOL" "$IMAGE-disk$i"
        fi

        echo "creating volume with $IMAGE-disk$i ($SIZE bytes)"
        virsh vol-create-as --pool "$IMAGEPOOL" --name "$IMAGE-disk$i" --capacity "$SIZE" --format qcow2

        echo "uploading image"
        virsh vol-upload --vol "$IMAGE-disk$i" --file "$WORKDIR/image" --pool "$IMAGEPOOL"
    done
}