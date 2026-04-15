# Ubuntu Server 24.04 FPV Router / Repeater on Raspberry Pi 4
## Full SSH-only build guide with automatic interface detection and remembered upstream Wi-Fis

![host-and-port](media/FPV-router.png)



This guide gets you from:

**“Raspberry Pi 4 + blank microSD card”**  
to  
**“Working Ubuntu-based FPV router/repeater that automatically brings up a robot network named `Rodriguez` and shares internet from an upstream Wi-Fi through a USB Wi-Fi dongle.”**

This version is designed to avoid the failure points from earlier attempts:

- cloud-init continuing to manage `wlan0`
- the wrong interface winning the default route
- `hostapd` starting while `wlan0` is still being treated like a client
- DHCP working but NAT missing
- hand-editing interface names everywhere
- forgetting old upstream Wi-Fis when adding a new one later

It is also written so the user can do the setup **entirely over SSH from a laptop**, without plugging the Pi into a monitor.

---

## 0. Materials

You need:

- **1 Raspberry Pi 4**
- **1 microSD card** (32 GB or larger recommended)
- **1 USB Wi-Fi dongle**
- **1 Raspberry Pi power supply**
- **1 laptop** that can connect over SSH
- Optional but recommended:
  - **high-endurance microSD card**
  - **UPS hat with batteries**

---

## 1. Flash Ubuntu Server onto the microSD card

Use the **official Raspberry Pi Imager**.

### 1.1 In Raspberry Pi Imager choose:

- **Device:** Raspberry Pi 4
- **Operating System:** Ubuntu Server 24.04 LTS (64-bit)
- **Storage:** your microSD card

### 1.2 Open the OS customization settings

When prompted, choose **Edit Settings**.

Set the following.

#### General tab

Set:
- **hostname**: `gamboa`
- **username**: `router`
- **password**: choose your own

Under **Configure Wireless LAN**, set the **initial upstream Wi-Fi** you want the Pi to use on first boot.

This is your internet source for setup, such as home or office Wi-Fi.

Example:
- SSID: `IZZI-E81F`
- Password: `YOUR_REAL_WIFI_PASSWORD`

#### Services tab

Enable:
- **SSH**
- **Use password authentication**

Flash the card.

---

## 2. Before the first SSH connection, make sure the setup conditions are correct

This matters.

### 2.1 Put the microSD card into the Pi

### 2.2 Plug the USB Wi-Fi dongle into the Pi

### 2.3 Power on the Pi

### 2.4 Make sure your laptop and the Pi are on the same network

For the first SSH session, the Pi will use the Wi-Fi you configured in Raspberry Pi Imager.

Your **laptop must be on that same network**.

### 2.5 Prefer a 2.4 GHz setup network during initial setup

For initial setup, make sure:

- the Pi is joining a **2.4 GHz network**
- your laptop is also on that same **2.4 GHz network**
- the network does not isolate wireless clients from each other

If your router uses the same SSID for both 2.4 GHz and 5 GHz, create or choose a **dedicated 2.4 GHz SSID** for setup if possible.

This avoids avoidable SSH discovery problems.

---

## 3. SSH into the Pi

First try:

```bash
ssh router@gamboa.local
```

If that does not work, scan your local network from the laptop:

```bash
sudo arp-scan --localnet
```

Look for the Pi’s IP, then connect with:

```bash
ssh router@<PI_IP_ADDRESS>
```

Once in, everything else in this tutorial is done from your laptop over SSH.

---

## 4. Install required packages

Run:

```bash
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  hostapd \
  dnsmasq \
  iptables \
  iptables-persistent \
  netfilter-persistent \
  iw \
  rfkill \
  ethtool \
  arp-scan \
  avahi-daemon
```

Stop the router services while configuring:

```bash
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true
```

---

## 5. Automatically detect interface names and create persistent variables

This step lets the rest of the tutorial use the same commands on different Pis and different USB dongles.

### 5.1 Create the interface-detection script

```bash
sudo tee /usr/local/sbin/fpv-router-detect-ifaces >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mapfile -t WIFI_IFACES < <(iw dev | awk '$1=="Interface"{print $2}')

if [ "${#WIFI_IFACES[@]}" -lt 2 ]; then
  echo "ERROR: Need two Wi-Fi interfaces (internal + USB dongle)." >&2
  echo "Make sure the USB Wi-Fi dongle is plugged in." >&2
  exit 1
fi

WAN_IF=""
AP_IF=""

for IFACE in "${WIFI_IFACES[@]}"; do
  DEVPATH="$(readlink -f "/sys/class/net/${IFACE}/device" || true)"
  if [[ "$DEVPATH" == *"/usb"* || "$DEVPATH" == *"usb"* ]]; then
    WAN_IF="$IFACE"
    break
  fi
done

if [ -z "$WAN_IF" ]; then
  echo "ERROR: Could not automatically identify the USB Wi-Fi dongle interface." >&2
  echo "Detected Wi-Fi interfaces: ${WIFI_IFACES[*]}" >&2
  exit 1
fi

for IFACE in "${WIFI_IFACES[@]}"; do
  if [ "$IFACE" != "$WAN_IF" ]; then
    AP_IF="$IFACE"
    break
  fi
done

if [ -z "$AP_IF" ]; then
  echo "ERROR: Could not identify the AP interface." >&2
  exit 1
fi

cat >/root/fpv-router.env <<ENV
export WAN_IF="${WAN_IF}"
export AP_IF="${AP_IF}"
export LAN_IP="10.42.0.1"
export LAN_CIDR="10.42.0.1/24"
export LAN_NET="10.42.0.0/24"
export DHCP_START="10.42.0.50"
export DHCP_END="10.42.0.150"
export AP_SSID="Rodriguez"
export AP_PSK="ChangeThisPasswordNow"
export WIFI_COUNTRY="US"
ENV

chmod 600 /root/fpv-router.env

echo
echo "Wrote /root/fpv-router.env with:"
echo "  WAN_IF=${WAN_IF}"
echo "  AP_IF=${AP_IF}"
echo
EOF

sudo chmod +x /usr/local/sbin/fpv-router-detect-ifaces
```

### 5.2 Run it

```bash
sudo /usr/local/sbin/fpv-router-detect-ifaces
source /root/fpv-router.env
```

### 5.3 Load the variables automatically in future shells

```bash
grep -qxF 'source /root/fpv-router.env 2>/dev/null || true' ~/.bashrc || \
echo 'source /root/fpv-router.env 2>/dev/null || true' >> ~/.bashrc

source ~/.bashrc
```

### 5.4 Verify what was detected

```bash
echo "WAN_IF=$WAN_IF"
echo "AP_IF=$AP_IF"
ip link
iw dev
```

You should see:
- `$WAN_IF` = USB Wi-Fi dongle
- `$AP_IF` = internal Pi Wi-Fi

---

## 6. Create the remembered upstream Wi-Fi list

This is how the router will remember multiple upstream networks later.

### 6.1 Create the upstream Wi-Fi file

```bash
sudo tee /root/uplinks.conf >/dev/null <<'EOF'
IZZI-E81F|YOUR_REAL_WIFI_PASSWORD
EOF

sudo chmod 600 /root/uplinks.conf
```

Each line in this file is:

```text
SSID|PASSWORD
```

---

## 7. Create the configuration renderer

This script generates all router config files using the auto-detected interface names and the remembered upstream Wi-Fi list.

### 7.1 Create the renderer

```bash
sudo tee /usr/local/sbin/render-fpv-router-config >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

source /root/fpv-router.env

if [ ! -f /root/uplinks.conf ]; then
  echo "ERROR: /root/uplinks.conf not found." >&2
  exit 1
fi

ACCESS_POINTS_BLOCK="$(
while IFS='|' read -r SSID PSK; do
  [ -z "${SSID}" ] && continue
  case "$SSID" in \#*) continue ;; esac
  printf '        "%s":\n          password: "%s"\n' "$SSID" "$PSK"
done < /root/uplinks.conf
)"

sudo mkdir -p /etc/netplan
cat <<EOF_NETPLAN | sudo tee /etc/netplan/01-router.yaml >/dev/null
network:
  version: 2
  renderer: networkd

  wifis:
    ${WAN_IF}:
      dhcp4: true
      optional: true
      access-points:
${ACCESS_POINTS_BLOCK}
  ethernets:
    ${AP_IF}:
      dhcp4: false
      addresses:
        - ${LAN_CIDR}
      optional: true
EOF_NETPLAN

sudo chown root:root /etc/netplan/01-router.yaml
sudo chmod 600 /etc/netplan/01-router.yaml

sudo mkdir -p /etc/systemd/network
cat <<EOF_WAN | sudo tee /etc/systemd/network/10-fpv-wan.network >/dev/null
[Match]
Name=${WAN_IF}

[Network]
DHCP=yes

[DHCPv4]
RouteMetric=100
EOF_WAN

sudo mkdir -p /etc/hostapd
cat <<EOF_HOSTAPD | sudo tee /etc/hostapd/hostapd.conf >/dev/null
interface=${AP_IF}
driver=nl80211

ssid=${AP_SSID}
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1

auth_algs=1
ignore_broadcast_ssid=0

wpa=2
wpa_passphrase=${AP_PSK}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

country_code=${WIFI_COUNTRY}
ieee80211d=1
EOF_HOSTAPD

cat <<EOF_DEFAULT_HOSTAPD | sudo tee /etc/default/hostapd >/dev/null
DAEMON_CONF="/etc/hostapd/hostapd.conf"
DAEMON_OPTS=""
EOF_DEFAULT_HOSTAPD

sudo mkdir -p /etc/systemd/system/hostapd.service.d
cat <<EOF_HOSTAPD_OVERRIDE | sudo tee /etc/systemd/system/hostapd.service.d/override.conf >/dev/null
[Service]
ExecStartPre=
ExecStartPre=/usr/sbin/rfkill unblock all
ExecStartPre=/bin/sh -c '/usr/sbin/iw dev ${AP_IF} set type __ap || true'
EOF_HOSTAPD_OVERRIDE

cat <<EOF_DNSMASQ | sudo tee /etc/dnsmasq.conf >/dev/null
interface=${AP_IF}
bind-interfaces
port=0

dhcp-range=${DHCP_START},${DHCP_END},255.255.255.0,12h
dhcp-option=option:router,${LAN_IP}
dhcp-option=option:dns-server,1.1.1.1,8.8.8.8
EOF_DNSMASQ

cat <<'EOF_ROUTER_SYSCTL' | sudo tee /etc/sysctl.d/99-router.conf >/dev/null
net.ipv4.ip_forward=1
EOF_ROUTER_SYSCTL

cat <<'EOF_FPV_SYSCTL' | sudo tee /etc/sysctl.d/99-fpv.conf >/dev/null
net.core.rmem_max=26214400
net.core.wmem_max=26214400
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384
net.ipv4.tcp_low_latency=1
EOF_FPV_SYSCTL

sudo mkdir -p /etc/systemd/journald.conf.d
cat <<'EOF_JOURNAL' | sudo tee /etc/systemd/journald.conf.d/volatile.conf >/dev/null
[Journal]
Storage=volatile
RuntimeMaxUse=64M
EOF_JOURNAL

cat <<EOF_WIFI_PS | sudo tee /etc/systemd/system/wifi-powersave-off.service >/dev/null
[Unit]
Description=Disable WiFi power saving
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/iw dev ${AP_IF} set power_save off
ExecStart=/usr/sbin/iw dev ${WAN_IF} set power_save off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_WIFI_PS

echo "Rendered router configuration."
EOF

sudo chmod +x /usr/local/sbin/render-fpv-router-config
```

### 7.2 Run the renderer

```bash
sudo /usr/local/sbin/render-fpv-router-config
```

---

## 8. Disable cloud-init networking so it stops fighting later

If you do not do this, cloud-init can keep trying to manage the internal Wi-Fi as a client later, which breaks the AP.

### 8.1 Disable future cloud-init network generation

```bash
sudo mkdir -p /etc/cloud/cloud.cfg.d
printf 'network: {config: disabled}\n' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

### 8.2 Move the generated cloud-init netplan file out of the way if present

```bash
ls /etc/netplan
```

If `50-cloud-init.yaml` exists, move it:

```bash
sudo mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.disabled
```

---

## 9. Apply the WAN/AP split

At this point, the router will stop using the internal Wi-Fi as a client and will switch the USB dongle into the WAN role.

### 9.1 Apply netplan

```bash
sudo netplan generate
sudo netplan apply
```

### 9.2 Restart networkd

```bash
sudo systemctl restart systemd-networkd
```

### 9.3 Expect SSH to drop here

If you are connected over SSH, your session may disconnect now.

That is normal.

### Why SSH drops here

Before this point, the Pi may have been using the internal Wi-Fi path it got during first boot.  
Now you are changing the roles so that:

- `$WAN_IF` becomes the true upstream internet interface
- `$AP_IF` stops being a client and becomes the AP-side interface

That transition can interrupt your SSH session.

### 9.4 Reconnect

Use `arp-scan` from the laptop if needed:

```bash
sudo arp-scan --localnet
```

Then reconnect:

```bash
ssh router@<WAN_IP_OF_THE_PI>
```

After reconnecting, reload the environment:

```bash
source ~/.bashrc
```

---

## 10. Verify the route fix worked

Run:

```bash
ip route
```

You want to see:

```text
default via 192.168.x.1 dev <YOUR_WAN_IF> metric 100
```

And also:

```text
10.42.0.0/24 dev <YOUR_AP_IF>
```

If the default route is not through `$WAN_IF`, stop here and fix that before continuing.

---

## 11. Reboot once before bringing up the AP services

This reboot is deliberate and important. It clears stale client-side state and makes the AP role transition reliable.

Run:

```bash
sudo reboot
```

Reconnect again over SSH to the WAN IP, then run:

```bash
source ~/.bashrc
ip route
```

Confirm again that `$WAN_IF` is the default route.

---

## 12. Enable sysctls, journaling policy, and router services

Apply sysctls:

```bash
sudo sysctl --system
sudo systemctl restart systemd-journald
```

Unmask and enable router services:

```bash
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl daemon-reload
sudo systemctl enable wifi-powersave-off
```

---

## 13. Set up NAT and forwarding

### 13.1 Flush stale rules from previous attempts

```bash
sudo iptables -F
sudo iptables -t nat -F
```

### 13.2 Add the correct rules

```bash
sudo iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE
sudo iptables -A FORWARD -i "$AP_IF" -o "$WAN_IF" -j ACCEPT
sudo iptables -A FORWARD -i "$WAN_IF" -o "$AP_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### 13.3 Save them persistently

```bash
sudo netfilter-persistent save
sudo systemctl enable netfilter-persistent
```

### 13.4 Verify them

```bash
sudo iptables -t nat -S
sudo iptables -S FORWARD
```

You should see:
- a MASQUERADE rule on `$WAN_IF`
- FORWARD rules in both directions between `$AP_IF` and `$WAN_IF`

---

## 14. Start the router services

Run:

```bash
sudo systemctl restart dnsmasq
sudo systemctl restart hostapd
sudo systemctl restart wifi-powersave-off
```

Now verify both:

```bash
systemctl status dnsmasq --no-pager
systemctl status hostapd --no-pager
```

Both should be **active (running)**.

---

## 15. Verify the AP is really up

Run:

```bash
iw dev "$AP_IF" info
```

At this point you want to see:
- `ssid Rodriguez`
- `type AP`

If you see `type managed`, do not continue. That means something is still trying to use the AP interface as a client.

With the tutorial above, it should be `type AP`.

---

## 16. Connect a client and verify DHCP + internet

Connect your laptop, phone, or robot to:

- **SSID**: `Rodriguez`
- **Password**: the value stored in `AP_PSK` inside `/root/fpv-router.env`

### 16.1 Verify DHCP on the Pi

Run:

```bash
journalctl -u dnsmasq -n 50 --no-pager
```

Look for `DHCPACK(...)` lines.

### 16.2 Verify internet on the client

From the client:

```bash
ping 10.42.0.1
ping 8.8.8.8
ping google.com
```

All three should work.

If `10.42.0.1` works but `8.8.8.8` does not, the problem is forwarding/NAT.  
If `8.8.8.8` works but `google.com` does not, the problem is DNS handoff.

---

## 17. Final power-cycle test

This is the real proof that the router is ready for field use.

### 17.1 Power it down

```bash
sudo poweroff
```

Wait until it is fully off.

### 17.2 Turn it back on

Power the Pi back on with the USB Wi-Fi dongle connected.

What should now happen automatically:

- the Pi boots
- the USB dongle reconnects to any remembered upstream Wi-Fi that is available
- the AP `Rodriguez` appears
- clients connect and get `10.42.0.x`
- clients get internet through the upstream Wi-Fi
- no monitor is needed

---

## 18. Easiest way to add a new upstream Wi-Fi later without forgetting old ones

This is the “used in another location” workflow.

### 18.1 Create the helper script once

```bash
sudo tee /usr/local/sbin/add-uplink-wifi >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: sudo add-uplink-wifi \"SSID\" \"PASSWORD\"" >&2
  exit 1
fi

SSID="$1"
PSK="$2"

touch /root/uplinks.conf
chmod 600 /root/uplinks.conf

if ! grep -Fqx "${SSID}|${PSK}" /root/uplinks.conf; then
  printf '%s|%s\n' "$SSID" "$PSK" >> /root/uplinks.conf
fi

/usr/local/sbin/render-fpv-router-config
netplan generate
netplan apply
systemctl restart systemd-networkd

echo
echo "Added uplink Wi-Fi: ${SSID}"
echo "Previous uplinks were preserved."
echo
EOF

sudo chmod +x /usr/local/sbin/add-uplink-wifi
```

### 18.2 Use it later

Connect to the router over `Rodriguez`:

```bash
ssh router@10.42.0.1
```

Then run:

```bash
sudo add-uplink-wifi "NewNetworkName" "NewNetworkPassword"
```

This:
- remembers the new network
- keeps the old ones
- regenerates the router config
- reapplies the WAN side

### 18.3 Verify afterwards

```bash
ip route
ping -c 3 8.8.8.8
```

---

## 19. Optional: quiet the harmless arp-scan vendor warnings

If you see vendor-file permission warnings on a machine running `arp-scan`, quiet them with:

```bash
sudo chmod 644 /usr/share/arp-scan/ieee-oui.txt /usr/share/arp-scan/mac-vendor.txt 2>/dev/null || true
```

---

## 20. Quick troubleshooting checklist

### The AP does not appear

Run:

```bash
systemctl status hostapd --no-pager
iw dev "$AP_IF" info
```

If `$AP_IF` is not `type AP`, the AP side is not fully claimed by hostapd.

### Clients connect but get no internet

Run:

```bash
sysctl net.ipv4.ip_forward
sudo iptables -t nat -S
sudo iptables -S FORWARD
```

### The wrong interface is still the default route

Run:

```bash
cat /etc/systemd/network/10-fpv-wan.network
ip route
```

### Need to re-render everything after editing values

Run:

```bash
sudo /usr/local/sbin/render-fpv-router-config
sudo netplan generate
sudo netplan apply
sudo systemctl restart systemd-networkd
sudo sysctl --system
sudo systemctl daemon-reload
sudo systemctl restart dnsmasq
sudo systemctl restart hostapd
sudo systemctl restart wifi-powersave-off
```

---

This version keeps the commands the same across different Raspberry Pi 4 builds and different USB Wi-Fi dongles because the interface names are detected automatically and stored as variables before the rest of the setup begins.
<br>  


