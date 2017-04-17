# VMTools

This project contains some simple bash-based VM management tools for a libvirt hypervisor. It is opinionated regarding
the infrastructure.

## Assumptions

 * Hypervisor is controlled by libvirt
 * Host disks are stored in a storage pool
 * Cloud images are stored in a storage pool (might be the same as the disk pool)
 * VMs can be configured using cloud-init

## Features

 * list all available images (`vm images`)
 * start a new VM using a cloud image and configure it according to a template (`vm create`)
 * destroy a VM and optionally its associated storages (`vm destroy`)
 * update image disks according to image specification (`vm updateimage`)

## What you need

 * a hypervisor with libvirtd
 * libvirt's virsh on the machine running the scripts (might be a remote host or the hypervisor itself)
 * QEMU installed if you want to upload qcow images

## Installation

Installation is done by running `make install`:

```bash
# install to /usr/local
sudo make install

# install to "$HOME/vmtools" (don't forget to add $HOME/vmtools/bin to your path)
make prefix="$HOME/vmtools" install
```

## Configuration

VMTools can be configured by editing `~/.vmtools/config`. 

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

### List available images (vm images)

All available images can be listed by running

```bash
vm images
```

### Update images (vm updateimage)

```bash
# (re)download disks for ubuntu-16.04 image
vm updateimage ubuntu-16.04
```

### Starting a VM (vm create)

A new Ubuntu 16.04 vm with 2 GB memory can be started by invoking:

```bash
vm create myvm --image=ubuntu-16.04 --memory=2G
```

You can specify a different memory size (`--memory=`), resize the disks during provisioning (`--disk0-size=`) or change
the number of virtual cpus (`--vcpus=`). To see all arguments, invoke `vmcreate --help`.

Memory and disk size can be specified using raw values or with a unit:
 * `1b` = 1 byte
 * `1k` = 1.000 bytes
 * `1m` = 1.000.000 bytes
 * `1g` = 1.000.000.000 bytes
 * `1K` = 1.024 bytes
 * `1M` = 1.048.576 bytes (1.024 ^ 2)
 * `1G` = 1.073.741.824 bytes (1.024 ^ 3)

### Destroying a VM (vm destroy)

A running vm can be destroyed using:

```bash
vm destroy myvm
```

For a full list of features see `vm destroy --help`

## Notes

 * Tested on Ubuntu 16.04.2 LTS host
