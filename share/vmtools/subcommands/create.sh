#!/bin/bash

usage() {
    cat <<EOF
NAME
    vm create - create a virtual machine from an image

SYNOPSIS
    vm create [options] name

OPTIONS
    --disk<x>-size=<size>       size of disk <x>
    --memory=<size>,-m <size>   memory size of domain
    --vcpus=<count>,-c <count>  number of virtual cpus
    --image=<name>,-i <name>    name of image to use
    --(no-)attach,-a            attach to console after startup
    --(no-)dry-run,-n           just print summary, do not create anything
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
            --disk?-size=*)
                tmp="${1#--disk*}"
                i="${tmp%-size=*}"
                DISKSIZE[$i]="${1##*=}"
                ;;
            --memory=*)
                MEMSIZE="${1##*=}"
                ;;
            --vcpus=*)
                VCPUS="${1##*=}"
                ;;
            --image=*)
                IMAGE="${1##*=}"
                ;;
            --attach|-a)
                ATTACH=y
                ;;
            --no-attach)
                ATTACH=n
                ;;
            --dry-run|-n)
                DRY_RUN=y
                ;;
            --no-dry-run)
                DRY_RUN=n
                ;;
            -m)
                MEMSIZE="${2}"
                shift
                ;;
            -c)
                VCPUS="${2}"
                shift
                ;;
            -i)
                IMAGE="${2}"
                shift
                ;;
            -c)
                VCPUS="${2}"
                shift
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

check_disks() {
    source ./info

    local i
    local minsize

    NUMDISKS=${#DISK[*]}
    for ((i=0; i<NUMDISKS; i++)) ; do
        virsh vol-info --pool "$IMAGEPOOL" "$IMAGE-disk$i" >/dev/null 2>&1 || die "missing image for disk$i"
        minsize=$(virsh vol-dumpxml --pool "$IMAGEPOOL" "$IMAGE-disk$i" | sed -e '/ *<capacity /!d' -e "s# *<capacity unit='bytes'>##" -e 's#</capacity>.*##')

        if [ -z "${DISKSIZE[$i]}" ] ; then
            DISKSIZE[$i]="${minsize}b"
            DISKSIZE_BYTES[$i]="${minsize}"
        else
            DISKSIZE_BYTES[$i]="$(to_bytes "${DISKSIZE[$i]}")"
            if [ "$minsize" -gt "${DISKSIZE_BYTES[$i]}" ] ; then
                die "disk$i must be at least $minsize bytes"
            fi
        fi

        i=$((i+1))
        NUMDISKS=$i
    done
}

create_iso() {
    local iso="$1"
    local src="$2"

    if which hdiutil >/dev/null 2>&1 ; then
        hdiutil makehybrid -default-volume-name "config-2" -o "$iso" "$src" -iso -joliet
    elif which mkisofs >/dev/null 2>&1 ; then
        mkisofs -V "config-2" -J -o "$iso" "$src"
    else
        die "no iso disk creator found (tried hdiutil and mkisofs)"
    fi
}

create_configdrive() {
    local CONFIGDRIVE="$1"

    mkdir -p "$CONFIGDRIVE/openstack/latest"

    NAME="$NAME" render "user-data" >"$CONFIGDRIVE/openstack/latest/user_data"

    local ssh_keys=""
    local pos=0
    for key in "${SSHKEY[@]}" ; do
        if [ $pos != 0 ] ; then
            ssh_keys="$ssh_keys"$',\n        '
        fi
        ssh_keys="$ssh_keys\"key$pos\": \"$key\""
        pos=$((pos+1))
    done

    cat >"$CONFIGDRIVE/openstack/latest/meta_data.json" <<EOF
{
    "availability_zone": "zone-1",
    "hostname": "$NAME",
    "name": "$NAME",
    "meta": {},
    "uuid": "$(uuidgen)",
    "public_keys": {
        $ssh_keys
    }
}
EOF
}

create_nodexml() {
    cat >"$WORKDIR/node.xml" <<EOF
<domain type='kvm'>
  <name>$NAME</name>
  <memory unit="b">$MEMSIZE_BYTES</memory>
  <vcpu>$VCPUS</vcpu>
  <os>
    <type arch='x86_64' machine='pc-1.0'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <cpu mode='host-passthrough'/>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <mac address='$(random_mac)'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <input type='mouse' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' passwd="vnc" listen='::' />
    <video>
      <model type='cirrus' vram='9216' heads='1'/>
    </video>
    <memballoon model='virtio'/>
    <rng model='virtio'>
      <backend model='random'>/dev/random</backend>
    </rng>
    <channel type='unix'>
      <source mode='bind' />
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
  </devices>
</domain>
EOF
}

random_mac() {
    echo -n "02:"
    hexdump -n 5 -e '4/1 "%02X:" 1/1 "%02X" 1 "\n"' /dev/urandom
}

main() {
    # parse arguments
    parseargs "$@"

    # calculate sizes in bytes
    MEMSIZE_BYTES="$(to_bytes "$MEMSIZE")"

    ### sanity checks
    [ -z "$IMAGE" ] && die "no --image provided"
    IMAGEDIR="$(find_imagedir "$IMAGE")" || die "image $IMAGE not found"

    [ $MEMSIZE_BYTES -ge 536870912 ] || die "memory size must be at least 512 mb"
    [ $VCPUS -ge 1 ] || die "need at least one cpu"

    virsh dominfo "$NAME" >/dev/null 2>&1 && die "vm $NAME already exists"

    cd "$IMAGEDIR"
    check_disks

    for ((i=0; i < $NUMDISKS; i++)) ; do
        virsh vol-info --pool="$POOL" "$NAME-disk$i" >/dev/null 2<&1 && die "disk$i for vm $NAME already exists"
    done

    virsh vol-info --pool="$POOL" "$NAME-config" >/dev/null 2<&1 && die "config-drive for vm $NAME already exists"

    ### summary
    echo "creating vm $NAME:"
    echo "  memory: $MEMSIZE ($MEMSIZE_BYTES bytes)"
    echo "  cpus:   $VCPUS"
    echo "  image:  $IMAGE ($DESCRIPTION)"
    for ((i=0; i < $NUMDISKS; i++)) ; do
        echo "  disk$i:  ${DISKSIZE[$i]} (${DISKSIZE_BYTES[$i]} bytes)"
    done

    if [ "$DRY_RUN" = "y" ] ; then
        exit 0
    fi

    ### work dir
    WORKDIR=$(mktemp -d /tmp/vmcreateXXXXXX)
    trap "rm -rf -- '$WORKDIR'" EXIT

    ### main
    log_action "creating config-drive image"
    create_configdrive "$WORKDIR/config-drive"
    create_iso "$WORKDIR/config.iso" "$WORKDIR/config-drive"

    log_action "creating config-drive"
    virsh vol-create-as --pool "$POOL" --name "$NAME-config" --capacity $(get_size "$WORKDIR/config.iso") || die "failed to create volume"

    log_action "uploading config-drive"
    virsh vol-upload --pool "$POOL" --vol "$NAME-config" --file "$WORKDIR/config.iso" || die "failed to upload image"

    for ((i=0; i < $NUMDISKS; i++)) ; do
        echo "creating disk$i..."
        cat >"$WORKDIR/disk$i.xml" <<EOF
<volume type='block'>
  <name>$NAME-disk$i</name>
  <capacity unit='b'>${DISKSIZE_BYTES[$i]}</capacity>
</volume>
EOF

        virsh vol-create-from --pool "$POOL" --inputpool "$IMAGEPOOL" --vol "$IMAGE-disk$i" --file "$WORKDIR/disk$i.xml" || die "failed to copy image"
    done

    log_action "creating domain"
    create_nodexml >"$WORKDIR/node.xml"
    virsh define "$WORKDIR/node.xml"

    log_action "attaching config-drive to domain"
    path=$(virsh vol-path --pool="$POOL" --vol "$NAME-config")
    virsh attach-disk --domain "$NAME" --source "$path" --target hdc --persistent --mode readonly --type cdrom || die "failed to attach disk"

    for ((i=0; i < $NUMDISKS; i++)) ; do
        log_action "attaching disk$i to domain"
        diskname="$NAME-disk$i"
        path=$(virsh vol-path --pool="$POOL" --vol "$diskname")
        virsh attach-disk --domain "$NAME" --source "$path" --target $(get_device $i) --persistent || die "failed to attach disk"
    done

    log_action "starting domain"
    virsh start "$NAME"
    virsh autostart "$NAME"

    if [ "$ATTACH" = y ] ; then
        log_action "attaching to console"
        virsh console "$NAME"
    fi
}
