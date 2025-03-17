# Rocky Linux Installation

## Partition


## OS Installation

Update the system.

``` sh
sudo dnf update -y
sudo dnf --enablerepo=elrepo-kernel install kernel-ml
#sudo dnf --enablerepo=elrepo-kernel install kernel-lt
```

> You can use `kernel-lt` (Linux LTS Kernel) if it is greater than or equal to the version `5.6` for `wireguard` and `orangefs` compatibility.

Reboot the system. Then, clean the system.

``` sh
sudo dnf remove -y kernel kernel-core
sudo dnf clean -y all
sudo dnf remove -y --oldinstallonly
```
