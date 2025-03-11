# Parallel File System

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

## OrangeFS Installation

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

### Mount OrangeFS Storage on the Access node
