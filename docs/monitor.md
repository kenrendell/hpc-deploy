# Monitoring and Logging

## Control node

### Install Prometheus

Create a dedicated non-privileged user account for Prometheus.

``` sh
PROMETHEUS_USER='prometheus'
sudo groupadd --system "${PROMETHEUS_USER}"
sudo useradd --system --comment 'Prometheus Monitoring System' --gid "${PROMETHEUS_USER}" --shell '/sbin/nologin' --home-dir '/var/lib/prometheus' "${PROMETHEUS_USER}"
```

Create directories `/etc/prometheus` and `/var/lib/prometheus`.

``` sh
sudo mkdir -p /var/lib/prometheus /etc/prometheus /etc/prometheus/consoles /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /var/lib/prometheus /etc/prometheus
```

Download the latest release of `prometheus` for your platform, then extract. Precompiled binaries for released versions are available in the [download section](https://prometheus.io/download/) on [prometheus.io](https://prometheus.io/). See the [installation](https://prometheus.io/docs/prometheus/latest/installation/) section.

``` sh
cd ~/src
wget https://github.com/prometheus/prometheus/releases/download/v3.1.0/prometheus-3.1.0.linux-amd64.tar.gz
tar xvf prometheus-3.1.0.linux-amd64.tar.gz
```

Install `prometheus` on the system.

``` sh
cd ./prometheus-3.1.0.linux-amd64
sudo command cp -f prometheus promtool /usr/local/bin
sudo command cp -f prometheus.yml /etc/prometheus
sudo chmod 755 /usr/local/bin/prometheus /usr/local/bin/promtool
```

Edit the file `/etc/prometheus/prometheus.yml` with the following modifications (use port `9091` instead of `9090`).

``` text
# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "prometheus"

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ["localhost:9091"]
```

Create and edit the file `/etc/systemd/system/prometheus.service` with the following modifications.

``` text
[Unit]
Description=Monitoring system and time series database
Documentation=https://prometheus.io/docs/introduction/overview/ man:prometheus(1)
Wants=network-online.target
After=network-online.target
After=time-sync.target

[Service]
Restart=on-failure
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
    --web.listen-address=0.0.0.0:9091 \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=20s
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
```

Restart and enable the `prometheus` service.

``` sh
sudo systemctl daemon-reload
sudo systemctl restart prometheus.service
sudo systemctl enable prometheus.service
```

Allow TCP port 9091 for `prometheus` service.

``` sh
sudo firewall-cmd --permanent --zone=public --add-port=9091/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

Update the container to match the user database of the host. See warewulf docs about [syncuser](https://warewulf.org/docs/main/contents/containers.html#syncuser).

``` sh
sudo wwctl container syncuser --write --build 'rockylinux-8'
```

Always rebuild overlays manually after changes to the cluster.

``` sh
sudo wwctl overlay build
```
