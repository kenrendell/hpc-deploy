# Remote Access

## Setup a Virtual Private Server (VPS)

To remotely access a server, it must be internet-accessible, typically via a static IP. For servers with dynamic IPs, a dynamic DNS service can map the IP to a hostname. If dynamic DNS isn’t feasible (e.g., due to restricted router access preventing port forwarding), a VPS (e.g., from Google, Linode, Oracle) with a static IP can be used to establish a reverse VPN tunnel, enabling secure remote access.

### Google Cloud

#### Configure VPC Network Firewall

- Go to `Menu` → `VPC networks`, then select the network `default`, and go to the `FIREWALLS`:

  ![Firewall configuration](../assets/configure-vps-firewall-00.png)

- Select `ADD FIREWALL RULE` and set the following modifications for wireguard VPN:

  ![Firewall configuration](../assets/configure-vps-firewall-01.png)

- Add the UDP port `51820` (wireguard) and the TCP port `51821` (wireguard-gui):

  ![Firewall configuration](../assets/configure-vps-firewall-02.png)

- Save and verify the changes:

  ![Firewall configuration](../assets/configure-vps-firewall-03.png)

#### Create a VPS Instance

- Set the VPS image (OS) to Rocky Linux 8:

  ![VPS configuration](../assets/configure-vps-00.png)

- Enable `IP forwarding` in the networking settings:

  ![VPS configuration](../assets/configure-vps-01.png)

- Edit the network interface, and select the network `default`:

  ![VPS configuration](../assets/configure-vps-02.png)

- Setup the external IPv4 address (static IPv4 address):

  ![VPS configuration](../assets/configure-vps-03.png)

- Secure the server, and add your SSH public keys:

  > To list the SSH public keys in your machine, run the command `ssh-add -L`.

  ![VPS configuration](../assets/configure-vps-04.png)

- Verify the configurations, then create the instance:

  ![VPS configuration](../assets/configure-vps-05.png)
