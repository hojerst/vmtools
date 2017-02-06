# VMTools

This project contains some simple bash-based VM management tools for a libvirt hypervisor. It is opinionated regarding the infrastructure.

## Assumptions

 * Hypervisor is controlled by libvirt
 * Host disks are stored in a storage pool
 * Cloud images are stored in a storage pool (might be the same as the disk pool)
 * VMs can be configured using cloud-init

## Features

 * start a new VM using a cloud image and configure it according to a template (`vmcreate`)
 * destroy a VM and optionally its associated storages (`vmdestroy`)
 * upload cloud images to the hypervisor (`uploadimage`)

## What you need

 * a hypervisor with libvirtd
 * libvirt's virsh on the machine running the scripts (might be a remote host or the hypervisor itself)
 * QEMU installed if you want to upload qcow images

## Installation

 * create a `$HOME/.vmtools/images` folder and copy the wanted definitions from `images/` there
 * edit the images in `$HOME/.vmtools/images/*` as needed
 * copy scripts from `bin` to a location in your `$PATH` or run them from the project file

## Configuration

Configuration is optional as all options either have a default value or are specified in the command line. However, if you
want to change the storage pool's name or want to provide some defaults for the command arguments, a `$HOME/.vmtools/config`
file can be created.

### Configuration options and default values

```bash
# storage pool for disks
POOL=default

# storage pool for images
IMAGEPOOL=images

# default memory size for new vms
MEMSIZE=512M

# default size for disk0 for resizing (disks are not resized by default, example: 20G)
DISKSIZE[0]=

# default number of virtual cpus
VCPUS=1

# default image (example: ubuntu-14.04)
IMAGE=

# remove storage when destroying a vm (y or n)
REMOVESTORAGE=n

# attach to console after vm creation
ATTACH=n

# dns domain of vms. if you specify this, vmdestroy will also delete the hostkey from ~/.ssh/known_hosts
DOMAIN=
```

## Usage

Management of the hypervisor is done using `virsh` from libvirt. This means the scripts can be run on the hypervisor
itself or on a remote host. `LIBVIRT_DEFAULT_URI` must be set accordingly.

### Uploading an image (uploadimage)

After downloading a image (e.g. Ubuntu 14.04's cloud image: https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img),
the image can be uploaded using:

```bash
# upload image to hypervisor
uploadimage xenial-server-cloudimage-amd64-disk1.img
```

### Starting a VM (vmcreate)

A new VM with default parameters can be started by invoking:

```bash
vmcreate myvm --image=ubuntu-16.04
```

You can specify a different memory size (`--memory=`), resize the disks during provisioning (`--disk0-size=`) or change the number of
virtual cpus (`--vcpus=`). To see all arguments, invoke `vmcreate --help`.

Memory and disk size can be specified using raw values or with a unit:
 * `1b` = 1 byte
 * `1k` = 1.000 bytes
 * `1m` = 1.000.000 bytes
 * `1g` = 1.000.000.000 bytes
 * `1K` = 1.024 bytes
 * `1M` = 1.048.576 bytes (1.024 ^ 2)
 * `1G` = 1.073.741.824 bytes (1.024 ^ 3)

### Destroying a VM (vmdestroy)

A running vm can be destroyed using:

```bash
vmdestroy myvm
```

For a full list of features see `vmdestroy --help`

## Notes

 * Tested on Ubuntu 14.04.4 LTS kvm host, scripts running remotely on OSX 10.11

### OSX specific

Homebrew's libvirt implementation uses a different socket path for libvirt. To manage a Ubuntu host from an OSX
machine, the correct socket path on the server must be set in the `LIBVIRT_DEFAULT_URI`.

```bash
export LIBVIRT_DEFAULT_URI=qemu+ssh://example.com/system?socket=/var/run/libvirt/libvirt-sock
```
