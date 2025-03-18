# File System

## Prepare Disk Provisioning Tools on Compute nodes

Warewulf provides structures to define disks, partitions, and file systems. These structures can generate a configuration for [Ignition](https://coreos.github.io/ignition/) to provision partitions and file systems dynamically on cluster nodes.

As specified in the [Warewulf Disk Management documentation](https://warewulf.org/docs/main/nodes/disks.html#disks-and-partitions), packages for ignition are not available for the Rocky Linux 8. See [this](https://kb.ciq.com/article/disk-management) guide for building `ignition` from source.

Run a shell inside a Warewulf container (image that is used by other nodes).

``` sh
sudo wwctl container shell 'rockylinux-8'
```

Install development tools/headers (for building `ignition` from source), and `gdisk`.

``` sh
dnf group install -y "Development Tools"
dnf install -y gdisk xfsprogs libblkid-devel
```

Download the latest `golang` binary distribution from the [official download page](https://go.dev/dl/) and [install](https://go.dev/doc/install).

``` sh
GO_VERSION='1.24.0'
wget -P /tmp "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
rm -rf /usr/local/go && tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
echo 'export PATH="${PATH}:/usr/local/go/bin/"' >> /etc/profile
source /etc/profile

# Confirm that the command prints the installed version of Go
go version
```

Then, build `ignition` from source:

``` sh
cd /tmp && git clone https://github.com/coreos/ignition.git
cd /tmp/ignition && make all && make install
```

To save space, remove some previously installed packages except `ignition` and `gdisk`. Note that this is **optional** if you have enough RAM.

``` sh
rm -rf /tmp/ignition /tmp/go*
rm -rf /root/.cache # go-build cache
dnf group remove -y "Development Tools"
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

## Configure Local Node Storage

### Swap Partition

On the control node, set the swap partition for the `default` profile.

``` sh
SWAP_SIZE=8 # swap size in GiB
sudo wwctl profile set default --diskname=/dev/sda --partname=swap --partsize="$((SWAP_SIZE * 1024))" --partnumber=1 --fsname=swap --fsformat=swap --fspath=swap --fswipe
```

> For specific nodes, use `wwctl node set <node-name>` instead of `wwctl profile set <profile-name>`.

Recommended swap space based on [RHEL 8 documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/managing_storage_devices/getting-started-with-swap_managing-storage-devices#recommended-system-swap-space_getting-started-with-swap):

| Amount of RAM in the system | Recommended Swap Space |
| :- | :- |
| < 2 GB | 2 times the amount of RAM |
| > 2 GB - 8 GB | Equal to the amount of RAM |
| > 8 GB - 64 GB | At least 4 GB |
| > 64 GB | At least 4 GB |

Verify if the swap partition is configured properly. For specific nodes, use `wwctl node list --fullall <node-name>`.

``` sh
sudo wwctl profile list --all
```

### Scratch Partition

Scratch partition is the partition that will be used by the parallel filesystem. On the control node, set the scratch partition for the `default` profile. This is the last partition, so does not require a partition size `--partsize` or number `--partnumber`; it will be extended to the maximum possible size.

``` sh
sudo wwctl profile set default --diskname=/dev/sda --diskwipe --partname=scratch --partcreate --fsname=scratch --fsformat=xfs --fspath /scratch --fswipe
```

> For specific nodes, use `wwctl node set <node-name>` instead of `wwctl profile set <profile-name>`.

Verify if the scratch partition is configured properly. For specific nodes, use `wwctl node list --all <node-name>`.

``` sh
sudo wwctl profile list --all
```

Always rebuild overlays manually after changes to the cluster.

``` sh
sudo wwctl overlay build
```

### Finalizing the Partition

Make sure that `should_exist: true` are set for both partitions in the configuration file. To edit the profile configuration file, use the command `wwctl profile edit <profile-name>`. And, for specific node configuration file, use the command `wwctl node edit <node-name>`.

``` sh
sudo wwctl profile edit default
```

Add/modify (do not delete lines) the following lines in the configuration file:

``` config
default:
# ...
  disks:
    /dev/sda:
      partitions:
        # ...
        scratch:
          # ...
          should_exist: "true"
        swap:
          # ...
          should_exist: "true"
# ...
```

Verify if the partitions are configured properly. For specific nodes, use `wwctl node list --all <node-name>`.

``` sh
sudo wwctl profile list --all
```

Always rebuild overlays manually after changes to the cluster. Then, restart the Warewulf server.

``` sh
sudo wwctl overlay build
sudo wwctl server restart
```

## OrangeFS Installation (Parallel File System)

### Compute nodes

On access node, modify the container of compute node.

``` sh
sudo wwctl container shell 'rockylinux-8'
```

Install `orangefs` and `orangefs-server` on the access node.

``` sh
dnf install -y epel-release
dnf install -y orangefs orangefs-server
```

Generate the configuration file `/etc/orangefs/orangefs.conf` using:

``` sh
SERVERS='n{1-5}' # format: <prefix>{#-#,#,#-#,...}
pvfs2-genconfig --quiet --protocol tcp --ioservers "${SERVERS}" --metaservers "${SERVERS}" --storage /scratch/data --metadata /scratch/meta /etc/orangefs/orangefs.conf
```

> Note: Adjust `ioservers` and `metaservers` hostnames depending on the requirement of the HPC topology.

Create the service files `orangefs-server.service` and `orangefs-server-create-storage-space.service` under the directory `/etc/systemd/system/`:

https://github.com/kenrendell/hpc-deploy/blob/b18b206ccd69ea995dc6d004b15ea405f2ab4f22/systemd/orangefs-server-create-storage.service#L1-L10

https://github.com/kenrendell/hpc-deploy/blob/b18b206ccd69ea995dc6d004b15ea405f2ab4f22/systemd/orangefs-server.service#L1-L11

Enable the `orangefs-server.service` and `orangefs-server-create-storage-space.service`.

``` sh
systemctl enable orangefs-server-create-storage-space.service
systemctl enable orangefs-server.service
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

Always rebuild overlays manually after changes to the cluster. Then, reboot the compute nodes.

``` sh
sudo wwctl overlay build
sudo ww-shutdown.sh
sudo ww-ether-wake.sh
```

To verify the OrangeFS servers, run the command `pvfs2-check-server`:

``` sh
# There is no outputs if successful
sudo wwctl ssh n[1-5] -- pvfs2-check-server -h localhost -f orangefs -n tcp -p 3334
```

### Mount OrangeFS Storage on the Access node

Install the OrangeFS client.

``` sh
sudo dnf install -y epel-release
sudo dnf install -y orangefs
```

Automatically load the kernel module `orangefs`.

``` sh
echo orangefs | sudo tee /etc/modules-load.d/orangefs.conf
```

> The filesystem type `pvfs2` is only available when the `orangefs` kernel module is loaded.

Modify `/etc/pvfs2tab` to mount the OrangeFS storage servers.
 
``` sh
sudo mkdir /scratch
HOST='n1' # any OrangeFS storage server
echo "tcp://${HOST}:3334/orangefs /scratch pvfs2 defaults,noauto 0 0" | sudo tee /etc/pvfs2tab
```

Enable the service `orangefs-client`.

``` sh
sudo systemctl enable orangefs-client.service
sudo systemctl restart orangefs-client.service
```

Test connectivity to the OrangeFS server.

``` sh
pvfs2-ping -m /scratch
```

Create the mount service file `orangefs-scratch.mount` under the directory `/etc/systemd/system/`. Modify the location `tcp://<hostname>:3334/orangefs` to match the configuration in `/etc/pvfs2tab`.

https://github.com/kenrendell/hpc-deploy/blob/68595f7c0a5d4c774b5e9ab564383f9f2da2175f/systemd/orangefs-scratch.mount#L1-L13

Enable the mount service for OrangeFS storage server.

``` sh
sudo systemctl daemon-reload
sudo systemctl enable scratch.mount
sudo systemctl restart scratch.mount
```

## Configure Storage nodes

Pull a basic node image from Docker Hub and import the default running kernel from the controller node and set both in the “storage” node profile. See [Warewulf node images](https://github.com/warewulf/warewulf-node-images). Use Rocky Linux 9 for storage nodes.

``` sh
sudo wwctl container import --build docker://ghcr.io/warewulf/warewulf-rockylinux:9 'rockylinux-9-storage'
sudo wwctl profile add storage --container 'rockylinux-9-storage'
```

Configure the storage node profile, so that all storage nodes share the netmask and gateway configuration.

``` sh
sudo wwctl profile set -y storage --netmask=255.255.252.0 --gateway=10.0.0.1
sudo wwctl profile list --all
```

Update the container image.

``` sh
sudo wwctl container shell 'rockylinux-9-storage'
dnf update -y
dnf remove -y --oldinstallonly
```

Install disk provisioning tools.

``` sh
dnf install -y gdisk ignition xfsprogs
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

### Add Storage nodes

``` sh
sudo wwctl node add s1 --profile=storage --ipaddr=10.0.2.100 --discoverable=true
sudo wwctl node list -a s1
sudo wwctl overlay build s1
# Then, boot `s1' node

# ... for other nodes
```

After adding all the storage nodes, update the `/etc/hosts` file with the following command:

``` sh
sudo wwctl configure hostfile
```
