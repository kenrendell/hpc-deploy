# Node Provisioning

## Install Warewulf

Install [Warewulf](https://warewulf.org/) on the control/access node. The preferred way to install Warewulf on Enterprise Linux is using the RPMs published in [GitHub releases](https://github.com/warewulf/warewulf/releases).

``` sh
sudo dnf install https://github.com/warewulf/warewulf/releases/download/v4.5.8/warewulf-4.5.8-1.el8.x86_64.rpm
```

## IP Addressing Configuration

The private network that will be used in a Warewulf cluster is `10.0.0.0/22`. Below is a recommended IP addressing scheme:

- `10.0.0.1`: Private network address IP
- `10.0.0.1 - 10.0.0.255`: Cluster infrastructure including this host, schedulers, file systems, routers, switches, etc.
- `10.0.1.1 - 10.0.1.255`: DHCP range for booting nodes
- `10.0.2.1 - 10.0.2.255`: Static node addresses
- `10.0.3.1 - 10.0.3.255`: IPMI and/or out of band addresses for the compute nodes

> The DHCP range from `10.0.1.1` to `10.0.1.255` is dedicated for DHCP during node boot and should not overlap with any static IP address assignments.

Modify the IP address of the private network interface card (NIC) to match the IP addressing scheme.

``` sh
PRIVATE_NIC='enp3s0'
sudo nmcli connection modify "${PRIVATE_NIC}" ipv4.method 'manual' ipv4.addresses '10.0.0.1/22' autoconnect 'true'
sudo nmcli connection up "${PRIVATE_NIC}"
```

For more info about the network configuration, see [control server setup](https://warewulf.org/docs/main/contents/setup.html).

## Configure Warewulf

Edit the file `/etc/warewulf/warewulf.conf` and ensure that appropriate configuration parameters are set. Then, enable the `warewulfd` service.

``` sh
sudo systemctl enable --now warewulfd
```

Configure all services and configurations that Warewulf relies on to operate.

``` sh
sudo wwctl configure --all
```

To check if the system have SELinux enforcing, run `getenforce` or `sestatus`. If the system have SELinux enforcing, run the following command:

``` sh
sudo restorecon -Rv /var/lib/tftpboot/
```

When using `firewalld` with Warewulf, the following services are required to be added for successful node interconnectivity. See [Warewulf configuration guide](https://warewulf.org/docs/main/contents/configuration.html).

``` sh
sudo firewall-cmd --permanent --zone=public --add-service=warewulf
sudo firewall-cmd --permanent --zone=public --add-service=dhcp
sudo firewall-cmd --permanent --zone=public --add-service=nfs
sudo firewall-cmd --permanent --zone=public --add-service=tftp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

## Configure nodes

Pull a basic node image from Docker Hub and import the default running kernel from the controller node and set both in the “default” node profile. See [Warewulf node images](https://github.com/warewulf/warewulf-node-images).

``` sh
sudo wwctl container import --build docker://ghcr.io/warewulf/warewulf-rockylinux:8 'rockylinux-8'
sudo wwctl profile set default --container 'rockylinux-8'
```

Configure the default node profile, so that all nodes share the netmask and gateway configuration.

``` sh
sudo wwctl profile set -y default --netmask=255.255.252.0 --gateway=10.0.0.1
sudo wwctl profile list --all
```

Update the container image.

``` sh
sudo wwctl container shell 'rockylinux-8'
dnf update -y
```

Exit Warewulf container shell with 0 exit status to force a rebuild.

``` sh
exit 0
```

### Add nodes

Adding nodes can be done while setting configurations in one command. Node IP addresses should follow the IP addressing scheme discussed previously, and node names must be unique.

``` sh
sudo wwctl node add n1 --ipaddr=10.0.2.1 --discoverable=true
sudo wwctl node list -a n1
sudo wwctl overlay build n1
# Then, boot `n1' node

sudo wwctl node add n2 --ipaddr=10.0.2.2 --discoverable=true
sudo wwctl node list -a n2
sudo wwctl overlay build n2
# Then, boot `n2' node

sudo wwctl node add n3 --ipaddr=10.0.2.3 --discoverable=true
sudo wwctl node list -a n3
sudo wwctl overlay build n3
# Then, boot `n3' node

sudo wwctl node add n4 --ipaddr=10.0.2.4 --discoverable=true
sudo wwctl node list -a n4
sudo wwctl overlay build n4
# Then, boot `n4' node

sudo wwctl node add n5 --ipaddr=10.0.2.5 --discoverable=true
sudo wwctl node list -a n5
sudo wwctl overlay build n5
# Then, boot `n5' node

# ... for other nodes
```

Overlay autobuild has been broken at various times prior to v4.5.6; so it’s a reasonable practice to rebuild overlays manually after changes to the cluster.

``` sh
sudo wwctl overlay build
```

## Controlling the nodes

### Rebooting the nodes

To shutdown all 5 nodes, run the following to make the `wake-on-lan` available for remote power-on.

``` sh
sudo wwctl ssh n[1-5] 'ethtool -s eth0 wol g && poweroff'
```

> Note: If the HPC server supports `IPMI`, it is better to use `IPMI` instead of `wake-on-lan` of NIC.

To power-on the nodes, run the script `ether-wake.sh`.

``` sh
# Power-on all Warewulf nodes
sudo ww-ether-wake.sh

# Power-on specific Warewulf nodes
sudo ww-ether-wake.sh 1 3 5
```

https://github.com/kenrendell/hpc-deploy/blob/5a12866acb228fe1507e3e037c89f36ec5a55ce4/scripts/ether-wake.sh#L1-L21
