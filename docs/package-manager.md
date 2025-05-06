# Package Managers

## Create Shared Directory

For system-wide installation, a shared directory must be created. See [FHS](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html) standard for possible shared directory location. In our HPC system, the `/home/groups` will be used (see [/home](https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.html#homeUserHomeDirectories) section in FHS) for shared directory.

``` sh
sudo useradd --system --create-home --shell /sbin/nologin groups
sudo chmod 775 /home/groups
sudo setfacl -d -m g::rwx /home/groups
sudo setfacl -d -m o::rx /home/groups
```

To create groups under `/home/groups` directory, run the command:

``` sh
GROUP='cluster' # change this
sudo useradd --system --create-home --base-dir /home/groups --gid "${GROUP}" --shell /sbin/nologin "${GROUP}"
sudo chmod 2775 "/home/groups/${GROUP}"
```

To remove a group in `/home/groups`, run the command:

``` sh
GROUP='cluster' # change this
sudo userdel --remove "${GROUP}"
```

## Spack

[Spack](https://github.com/spack/spack) is a multi-platform package manager that builds and installs multiple versions and configurations of software. It works on Linux, macOS, Windows, and many supercomputers. Spack is non-destructive: installing a new version of a package does not break existing installations, so many configurations of the same package can coexist.

### Installation

To install `spack` package, make sure that the [minimum requirements](https://spack.readthedocs.io/en/latest/getting_started.html#system-prerequisites) are met.

``` sh
sudo dnf install -y epel-release
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y gcc-gfortran redhat-lsb-core python3 unzip
```

Install `spack` under a system-wide directory `/home/groups`.

``` sh
GROUP='cluster'; USER='admin' # change this
sudo usermod --append --groups "${GROUP}" "${USER}"
git clone -c feature.manyFiles=true --depth=2 https://github.com/spack/spack.git "/home/groups/${GROUP}/spack"
printf '. %s\n' "/home/groups/${GROUP}/spack/share/spack/setup-env.sh" | sudo tee /etc/profile.d/spack.sh
```

Restart the session to setup the environment for `spack`. Then, configure the `build_stage` to not use `/tmp` directory, since it has the possibility to be configured with a `noexec` attribute in `/etc/fstab`.

``` sh
spack config add config:build_stage:'$user_cache_path/stage'
spack config blame config # see changes
```

#### On Compute Nodes

Copy the file `/etc/profile.d/spack.sh` from the control node to the compute nodes.

``` sh
sudo wwctl container shell --bind /:/mnt 'rockylinux-8'
command cp -fp /mnt/etc/profile.d/spack.sh /etc/profile.d
exit 0
```

Always rebuild overlays manually after changes to the cluster. Then, [restart](provision.md) the compute nodes.

``` sh
sudo wwctl overlay build
```

#### Spack Usage
