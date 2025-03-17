# Tips on Cleaning the System

``` sh
dnf remove --oldinstallonly --setopt installonly_limit=3
dnf remove --oldinstallonly
dnf clean all

du -d 1 -x / | sort -n
du -d 1 -hx /
```
