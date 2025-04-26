# Flux

## Preparation

The [Flux Administrator's Guide](https://flux-framework.readthedocs.io/projects/flux-core/en/latest/guide/admin.html#) documents relevant information for installation, configuration, and management of Flux as the native resource manager on a cluster.

### Synchronize users and groups across the cluster

A check if the users of the host and container matches can be triggered with the syncuser command.

``` sh
CONTAINER_NAME='rockylinux-8'
sudo wwctl container syncuser "${CONTAINER_NAME}"
```

The system user `flux` is required as the Flux instance owner. The system user `flux` must exist on all nodes of the cluster.

``` sh
sudo groupadd --system 'flux'
sudo useradd --system --comment 'Flux Instance Owner' --gid 'flux' --shell '/sbin/nologin' 'flux'
```

Also, create a dedicated non-privileged user account for MUNGE. The recommended user/group name for this account is `munge`. See [MUNGE general recommendations](https://github.com/dun/munge/wiki/Installation-Guide#general-recommendations).

``` sh
MUNGE_USER='munge'
sudo groupadd --system "${MUNGE_USER}"
sudo useradd --system --comment "MUNGE Uid 'N' Gid Emporium" --gid "${MUNGE_USER}" --shell '/sbin/nologin' --home-dir '/run/munge' "${MUNGE_USER}"
```

With the `--write` flag it will update the container to match the user database of the host as described above. See warewulf docs about [syncuser](https://warewulf.org/docs/main/contents/containers.html#syncuser).

``` sh
CONTAINER_NAME='rockylinux-8'
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

## Flux Installation

### Control node

Install [flux-core](https://github.com/flux-framework/flux-core), [flux-security](https://github.com/flux-framework/flux-security), [flux-sched](https://github.com/flux-framework/flux-sched), and [flux-pmix](https://github.com/flux-framework/flux-pmix) on the control node (and compute nodes) using [spack](package-manager.md) package manager. See [this](https://flux-framework.readthedocs.io/projects/flux-core/en/latest/guide/admin.html#installing-software-packages) and [this](https://flux-framework.readthedocs.io/projects/flux-core/en/latest/index.html) one. The following command also installs `flux-core` and `flux-security`:

``` sh
spack install gcc@14.2.0
spack install flux-sched +cuda+docs %gcc@14.2.0 ^flux-core +security+cuda+docs %gcc@14.2.0
spack install --reuse flux-pmix %gcc@14.2.0 ^flux-core +security+cuda+docs %gcc@14.2.0
```

> For OpenMPI support, install `flux-pmix`.

> For Flux to manage and schedule Nvidia GPUs, include the +cuda variant in `flux-sched` and `flux-core` spack installations. See [this](https://spack.readthedocs.io/en/latest/basic_usage.html#variants) guide on how to specify package variants in `spack`.

Additionally, the [flux-accounting](https://github.com/flux-framework/flux-accounting) and [flux-pam](https://github.com/flux-framework/flux-pam) can be optionally installed to enable advanced functionalities. Currently, `flux-accounting` and `flux-pam` is not available on `spack` package manager.

Flux uses `hwloc` to verify that configured resources are present on nodes. Ensure that the system installed version includes any plugins needed for the hardware, especially GPUs. ***Optional*** since `hwloc` is listed as a dependency of `flux-core` spack package, and will be installed with `CUDA` support (for Nvidia GPUs).

``` sh
sudo dnf --enablerepo=devel install -y hwloc hwloc-devel hwloc-plugins  # optional
```

Load `flux` components. To see the loaded spack packages, run `spack load --list`.

``` sh
printf '\nspack load flux-core flux-security flux-sched flux-pmix\n' | sudo tee -a /etc/profile.d/spack.sh
printf '. "%s/etc/bash_completion.d/flux"\n' '$(spack location -i flux-core)' | sudo tee -a /etc/profile.d/spack.sh
```

> To verify the loaded environment variables, run `spack load --sh flux-core flux-security flux-sched flux-pmix`.

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
