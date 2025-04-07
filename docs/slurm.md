# SLURM

## Preparation

### Synchronize users and groups across the cluster

A check if the users of the host and container matches can be triggered with the syncuser command.

``` sh
CONTAINER_NAME='rockylinux-8'
sudo wwctl container syncuser "${CONTAINER_NAME}"
```

The *SlurmUser* `slurm` must exist prior to starting Slurm and must exist on all nodes of the cluster.

``` sh
SLURM_USER='slurm'
sudo groupadd --system "${SLURM_USER}"
sudo useradd --system --comment 'Slurm Workload Manager' --gid "${SLURM_USER}" --shell '/sbin/nologin' --home-dir '/etc/slurm' "${SLURM_USER}"
```

Also, create a dedicated non-privileged user account for MUNGE. The recommended user/group name for this account is `munge`. See [MUNGE general recommendations](https://github.com/dun/munge/wiki/Installation-Guide#general-recommendations).

``` sh
MUNGE_USER='munge'
sudo groupadd --system "${MUNGE_USER}"
sudo useradd --system --comment "MUNGE Uid 'N' Gid Emporium" --gid "${MUNGE_USER}" --shell '/sbin/nologin' --home-dir '/run/munge' "${MUNGE_USER}"
```

With the `--write` flag it will update the container to match the user database of the host as described above. See warewulf docs about [syncuser](https://warewulf.org/docs/main/contents/containers.html#syncuser).

``` sh
sudo wwctl container syncuser --write --build "${CONTAINER_NAME}"
```

Always rebuild overlays manually after changes to the cluster.

``` sh
sudo wwctl overlay build
```

### Synchronize time

#### Control node

Install `chrony` and `ntpstat` on the control node.

``` sh
sudo dnf install -y chrony ntpstat
```

Modify the file `/etc/chrony.conf` with the following modifications. See [time servers](https://github.com/jauderho/nts-servers) with NTS support.

``` text
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (https://www.pool.ntp.org/join.html).
#pool 2.rocky.pool.ntp.org iburst

# Use NTS-secured time server instead of public servers from the pool.ntp.org project.
server time.cloudflare.com iburst nts

# Allow NTP client access from local network.
#allow 192.168.0.0/16
allow 10.0.0.0/22
```

After editing the file `/etc/chrony.conf`, restart and enable the `chronyd` service.

``` sh
sudo systemctl restart chronyd.service
sudo systemctl enable chronyd.service
```

Check synchronization status with `chronyc` and `ntpstat`.

``` sh
chronyc tracking
ntpstat
```

Allow port for NTP service.

``` sh
sudo firewall-cmd --permanent --zone=public --add-service=ntp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

#### Other nodes

First, run a shell inside a Warewulf container (image that is used by other nodes).

``` sh
sudo wwctl container shell 'rockylinux-8'
```

The container image must be *writable* to allow interactive changes to the container image. See this [issue](https://warewulf.org/docs/main/contents/known-issues.html#containers-are-read-only), if the container image is *read-only*.

Install `chrony` and `ntpstat`.

``` sh
dnf install -y chrony ntpstat
```

Modify the file `/etc/chrony.conf` with the following modifications.

``` text
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (https://www.pool.ntp.org/join.html).
#pool 2.rocky.pool.ntp.org iburst

# Use the time server of the control node (10.0.0.1).
server 10.0.0.1 iburst minpoll 3 maxpoll 5

# Allow NTP client access from local network.
#allow 192.168.0.0/16
allow 10.0.0.0/22
```

After editing the file `/etc/chrony.conf`, enable the `chronyd` service.

``` sh
systemctl enable chronyd.service
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

Always rebuild overlays manually after changes to the cluster.

``` sh
sudo wwctl overlay build
```

Then, reboot the nodes. After reboot, check synchronization status with `chronyc` and `ntpstat`.

``` sh
sudo wwctl ssh n[1-5] chronyc tracking
sudo wwctl ssh n[1-5] ntpstat
```

### Install MUNGE for Authentication

#### Control node

Install `munge` on the control node.

``` sh
sudo dnf install -y munge
```

Create a key using the `create-munge-key` command. The key resides in `/etc/munge/munge.key`. This file must be owned by the same user ID that will run the munged daemon process, and its permissions should be set to 0600. Note that this file will need to be securely propagated to all hosts within the security realm. See [MUNGE configuration and setup](https://github.com/dun/munge/wiki/Installation-Guide#configuration-and-setup).

``` sh
sudo /usr/sbin/create-munge-key
```

The key file `/etc/munge/munge.key` must be created before starting the daemon.

``` sh
sudo systemctl restart munge.service
sudo systemctl enable munge.service
```

#### Other nodes

First, run a shell inside a Warewulf container (image that is used by other nodes).

``` sh
sudo wwctl container shell --bind /:/mnt 'rockylinux-8'
```

Install `munge`.

``` sh
dnf install -y munge
```

Copy the file `/etc/munge/munge.key` from the control node to the container.

``` sh
command cp -fp /mnt/etc/munge/munge.key /etc/munge
```

The key file `/etc/munge/munge.key` must be created before starting the daemon.

``` sh
systemctl enable munge.service
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

Always rebuild overlays manually after changes to the cluster.

``` sh
sudo wwctl overlay build
```

Then, reboot the nodes. After reboot, check if `munge` is configured properly.

``` sh
sudo wwctl ssh n[1-5] -- echo "$(munge -n)" \| unmunge
```

## Slurm Installation

### Control node

Install `slurmctld` on the control node.

``` sh
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --set-enabled powertools
sudo dnf install -y rocky-release-hpc
sudo dnf install -y slurm23.11-slurmctld
sudo dnf install -y openmpi
```

Modify the file `/etc/slurm/slurm.conf` with the following modifications.

``` text
ClusterName=cain-hpc-proto
SlurmctldHost=cain-hpc-proto.localdomain
SlurmctldAddr=10.0.0.1
SlurmUser=slurm

MpiDefault=none

ProctrackType=proctrack/cgroup
TaskPlugin=task/affinity,task/cgroup
TmpFS=/run

SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_CPU_Memory

ReturnToService=2

NodeName=n[1-4] NodeAddr=10.0.2.[1-4] CPUs=4 CoresPerSocket=2 ThreadsPerCore=2 RealMemory=7873 MemSpecLimit=2048 TmpDisk=2048
NodeName=n5 NodeAddr=10.0.2.5 CPUs=8 CoresPerSocket=4 ThreadsPerCore=2 RealMemory=7869 MemSpecLimit=2048 TmpDisk=2048

PartitionName=debug Nodes=ALL Default=YES MaxTime=INFINITE State=UP
```

Specify the minimum processor count (CPUs), real memory space (RealMemory, megabytes), and temporary disk space (TmpDisk, megabytes) that a node should have to be considered available for use. Any node lacking these minimum configuration values will be considered DOWN and not scheduled. Use `lscpu` and `lsmem` commands to determine node specifications. See [Slurm configuration docs](https://slurm.schedmd.com/quickstart_admin.html#Config).

`MpiDefault` identifies the default type of MPI to be used.  Srun may  override  this configuration  parameter  in any case. Currently supported versions include: pmi2, pmix, and none. To see the acceptable types:

``` sh
sudo srun --mpi=list
```

Also, modify the file `/etc/slurm/cgroup.conf` with the following modifications.

``` text
ConstrainCores=no
ConstrainDevices=no

#ConstrainRAMSpace=no
ConstrainRAMSpace=yes
ConstrainSwapSpace=yes
AllowedRAMSpace=100
AllowedSwapSpace=0
```

Create directories `/etc/slurm`, `/var/run/slurm`, `/var/spool/slurm`, and `/var/log/slurm`. Then, change the ownership of created directories to `SlurmUser`.

``` sh
sudo mkdir -p /etc/slurm /var/run/slurm /var/spool/slurm /var/log/slurm
sudo chown -R slurm:slurm /etc/slurm /var/run/slurm /var/spool/slurm /var/log/slurm
sudo chmod -R 644 /etc/slurm && sudo find /etc/slurm -type d -exec chmod 755 {} ';'
```

After editing the file `/etc/slurm/slurm.conf`, restart and enable the `slurmctld` service.

``` sh
sudo systemctl restart slurmctld.service
sudo systemctl enable slurmctld.service
```

Allow TCP port 6817 for `slurmctld` service.

``` sh
sudo firewall-cmd --permanent --zone=public --add-port=6817/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

### Other node

First, run a shell inside a Warewulf container.

``` sh
sudo wwctl container shell --bind /:/mnt 'rockylinux-8'
```

In compute node, install `slurmd`.

``` sh
dnf install -y dnf-plugins-core
dnf config-manager --set-enabled powertools
dnf install -y rocky-release-hpc
dnf install -y slurm23.11-slurmd
dnf install -y openmpi
```

Create directories `/etc/slurm`, `/var/run/slurm`, `/var/spool/slurm`, and `/var/log/slurm`. Then, change the ownership of created directories to `SlurmUser`.

``` sh
mkdir -p /etc/slurm /var/run/slurm /var/spool/slurm /var/log/slurm
chown -R slurm:slurm /etc/slurm /var/run/slurm /var/spool/slurm /var/log/slurm
```

Copy the file `/etc/slurm/slurm.conf` from the control node to the container.

``` sh
command cp -fp /mnt/etc/slurm/slurm.conf /mnt/etc/slurm/cgroup.conf /etc/slurm
```

Enable the `slurmd` service.

``` sh
systemctl enable slurmd.service
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

Always rebuild overlays manually after changes to the cluster.

``` sh
sudo wwctl overlay build
```

Then, reboot the nodes. To print the node configuration, run the following command on the compute nodes.

``` sh
sudo wwctl ssh n[1-5] -- slurmd -C
```

### Making changes on Slurm

Recommended process for adding a node or configuring Slurm:

- Stop the `slurmctld` systemd service on the control node.

  ``` sh
  sudo systemctl stop slurmctld.service
  ```

- Update Slurm and propagate the changes on `slurm.conf` file or any slurm-related files from the control node to all nodes in the cluster.

  ``` sh
  sudo wwctl container shell --bind /:/mnt 'rockylinux-8'
  ```

  Copy the file `/etc/slurm/slurm.conf` from the control node to the container.

  ``` sh
  command cp -fp /mnt/etc/slurm/slurm.conf /mnt/etc/slurm/cgroup.conf /etc/slurm
  exit 0
  ```

  Always rebuild overlays manually after changes to the cluster.

  ``` sh
  sudo wwctl overlay build
  ```

- Restart the `slurmd` systemd service on all nodes.

  > Reboot the nodes. No need to restart `slurmd` systemd service on all compute nodes.

- Restart the `slurmctld` systemd service on the control node.

  ``` sh
  sudo systemctl restart slurmctld.service
  ```

Interoperability is guaranteed between three consecutive versions of Slurm, with the following restrictions:

- The version of `slurmdbd` must be identical to or higher than the version of `slurmctld`.
- The version of `slurmctld` must the identical to or higher than the version of `slurmd`.
- The version of `slurmd` must be identical to or higher than the version of the Slurm user applications.

> In short: version(`slurmdbd`) >= version(`slurmctld`) >= version(`slurmd`) >= version(Slurm user CLIs)
