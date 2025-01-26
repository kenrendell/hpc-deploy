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

## Configure nodes

Pull a basic node image from Docker Hub and import the default running kernel from the controller node and set both in the “default” node profile. See [Warewulf node images](https://github.com/warewulf/warewulf-node-images).

``` sh
sudo wwctl container import --build docker://ghcr.io/warewulf/warewulf-rockylinux:8 rockylinux-8
sudo wwctl profile set default --container rockylinux-8
```

Configure the default node profile, so that all nodes share the netmask and gateway configuration.

``` sh
sudo wwctl profile set -y default --netmask=255.255.252.0 --gateway=10.0.0.1
sudo wwctl profile list --all
```

### Add nodes

Adding nodes can be done while setting configurations in one command. Node IP addresses should follow the IP addressing scheme discussed previously, and node names must be unique.

``` sh
sudo wwctl node add n1 --ipaddr=10.0.2.1 --discoverable=true
sudo wwctl node list -a n1

sudo wwctl node add n2 --ipaddr=10.0.2.2 --discoverable=true
sudo wwctl node list -a n2

sudo wwctl node add n3 --ipaddr=10.0.2.3 --discoverable=true
sudo wwctl node list -a n3

sudo wwctl node add n4 --ipaddr=10.0.2.4 --discoverable=true
sudo wwctl node list -a n4

sudo wwctl node add n5 --ipaddr=10.0.2.5 --discoverable=true
sudo wwctl node list -a n5
```

Overlay autobuild has been broken at various times prior to v4.5.6; so it’s a reasonable practice to rebuild overlays manually after changes to the cluster.

``` sh
# you can also supply an `n1` argument to build for the specific node
sudo wwctl overlay build
```
