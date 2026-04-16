# Ubuntu Server 24.04 FPV Router / Repeater on Raspberry Pi 4
## Full SSH-only build guide with automatic interface detection and remembered upstream Wi-Fi networks

![host-and-port](media/FPV-router.png)



This guide gets you from:

**“Raspberry Pi 4 + blank microSD card + WiFi Dongle”**  
to  
**“Working Ubuntu-based FPV router/repeater that automatically brings up a robot network and shares internet from an upstream Wi-Fi through a USB Wi-Fi dongle.”**

This setup process avoids common failure types such as:

- cloud-init continuing to manage the AP-side interface
- the wrong interface winning the default route
- `hostapd` starting while the Pi's internal Wi-Fi is still being treated like a client
- DHCP working but NAT missing
- hand-editing interface names everywhere
- overwriting older upstream Wi-Fi credentials when adding a new one later

Everything below is written so the user can do the setup **entirely over SSH from a laptop**, without plugging the Pi into a monitor.

Additional repo docs:

- [Git Workflow](DOCS/git_workflow.md)

---

## Materials

You need:

- **1 Raspberry Pi 4**
- **1 microSD card** (32 GB or larger recommended)
- **1 USB Wi-Fi dongle** with stable Linux support
- **1 Raspberry Pi power supply**
- **1 laptop** that can connect over SSH
- Optional but recommended:
  - **high-endurance microSD card**
  - **UPS hat with batteries**

---

## Clone This Repo on Your Laptop

Run these commands on your laptop:

```bash
git clone https://github.com/AEmilioDiStefano/FPV_router.git
cd FPV_router
```

The rest of this guide assumes you have this repo available on your laptop because you will use the tracked helper scripts in `scripts/pi/` instead of pasting large script blocks into the Pi terminal.

---

## 0. Flash Ubuntu Server onto the microSD card

Use the **official Raspberry Pi Imager**.

### 0.1 In Raspberry Pi Imager choose:

- **Device:** Raspberry Pi 4
- **Operating System:** Ubuntu Server 24.04 LTS (64-bit)
- **Storage:** your microSD card

### 0.2 Open the OS customization settings

When prompted, choose **Edit Settings**.

Set:
- **hostname**: choose the Linux hostname you want to use for this Pi
- **username**: choose the Linux username you want to use over SSH
- **password**: choose a password for that Linux user

Example only: you might choose a hostname like gamboa, a username like router, and a password like secure_password_DO_NOT_USE_THIS_ONE!.

Under **Configure Wireless LAN**, set the **initial upstream Wi-Fi** you want the Pi to use on first boot.

This is your internet source for setup, such as home or office Wi-Fi.

Set:
- **SSID**: your upstream Wi-Fi network name
- **Password**: your upstream Wi-Fi password

Example only: an upstream Wi-Fi could be called WorkshopWiFi24, with a matching password such as ExamplePassword123.

#### Services tab

Enable:
- **SSH**
- **Use password authentication**

Flash the card.

The first boot can take several minutes while Ubuntu expands the filesystem and finishes cloud-init, so give it a little time before scanning for it.

---

## 1. Before the first SSH connection, make sure the setup conditions are correct

This matters.

### 1.1 Put the microSD card into the Pi

### 1.2 Plug the USB Wi-Fi dongle into the Pi

### 1.3 Power on the Pi

### 1.4 Make sure your laptop and the Pi are on the same network

For the first SSH session, the Pi will use the Wi-Fi you configured in Raspberry Pi Imager, usually through the Pi's built-in Wi-Fi.

Your **laptop must be on that same network**.

The USB Wi-Fi dongle is switched into the permanent upstream WAN role later in this guide.

### 1.5 Prefer a 2.4 GHz setup network during initial setup

For initial setup, make sure:

- the Pi is joining a **2.4 GHz network**
- your laptop is also on that same **2.4 GHz network**
- the network does not isolate wireless clients from each other

If your router uses the same SSID for both 2.4 GHz and 5 GHz, create or choose a **dedicated 2.4 GHz SSID** for setup if possible.

This avoids common SSH discovery problems.

---

## 2. Install the Router Helper Scripts onto the Pi

### 2.1 Save the router SSH target values in your laptop terminal

Run these commands on your laptop, not inside the router SSH session:

```bash
read -rp "Enter the Linux USERNAME chosen in Raspberry Pi Imager for the ROUTER: " PI_USER
read -rp "Enter the Linux HOSTNAME chosen in Raspberry Pi Imager for the ROUTER (without .local): " PI_HOST
```

Example only: if the Linux username were `router` and the Linux hostname were `gamboa`, the saved values would be equivalent to `PI_USER=router` and `PI_HOST=gamboa`.

### 2.2 Try the `.local` hostname as the current router SSH target and install the router helper scripts

Run this on your laptop from the repo root:

```bash
PI_SSH_TARGET="${PI_HOST}.local"
./scripts/install_pi_helpers.sh --user "$PI_USER" --host "$PI_SSH_TARGET"
```

If that works, continue to Step 2.4.

### 2.3 If the `.local` hostname does not work, use `arp-scan` and the router Pi IP instead

Run this on your laptop:

```bash
sudo arp-scan --localnet
read -rp "Enter the ROUTER Pi IP address shown by arp-scan: " PI_SSH_TARGET
./scripts/install_pi_helpers.sh --user "$PI_USER" --host "$PI_SSH_TARGET"
```

### 2.4 SSH into the router

After the helper installer succeeds, SSH into the router:

```bash
ssh "${PI_USER}@${PI_SSH_TARGET}"
```

The helper installer copies the tracked router helper scripts from `scripts/pi/` in this repo onto the router Pi and installs them into `/usr/local/sbin`, which removes the need to paste large script blocks into the Pi terminal.

---

## 3. Reset To A Clean Retry State Without Reflashing

Run this step once after the first SSH login, even on a freshly flashed microSD card.

The installed reset helper checks first whether anything actually needs to be cleaned up.

On a freshly flashed microSD card, or on any Pi that is already in the clean pre-router state, it prints that no reset is needed and returns you to the same SSH prompt without rebooting.

If it finds router-specific system state from an earlier attempt that would interfere with a clean rerun, it removes those artifacts, restores the normal first-boot-style network path, and then reboots so you can continue from the normal pre-router state without reflashing.

### 3.1 Run the reset helper

```bash
sudo /usr/local/sbin/fpv-router-reset-for-retry
```

If the helper prints `No reset is needed.`, stay in the same SSH session and continue directly to Step 4.

If it says a reset is needed and then your SSH session disconnects, wait 30 to 120 seconds for the router Pi to reboot, then SSH back into the router the same way that worked in Step 2.4.

### 3.2 Verify the reset if the helper rebooted the router Pi

Only run this step if the reset helper actually rebooted the router Pi.

```bash
sudo /usr/local/sbin/fpv-router-verify-reset
```

### 3.3 Continue

If the reset helper reported that no reset was needed, continue with Step 4 in the same SSH session.

If the reset helper rebooted the Pi and the reset verifier passed afterwards, continue with Step 4.

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
  wpasupplicant \
  avahi-daemon
```

`wpasupplicant` is included explicitly because Ubuntu's `networkd` Wi-Fi client path depends on it.

Stop the router services while configuring:

```bash
sudo systemctl stop hostapd || true
sudo systemctl stop dnsmasq || true
```

---

## 5. Automatically detect interface names and create persistent variables

This step lets the rest of the tutorial use the same commands on different Pis and different USB dongles.

This is also where you set the SSID and password for the new Wi-Fi network that the Pi will broadcast.

### 5.1 Run the installed interface-detection helper

```bash
sudo /usr/local/sbin/fpv-router-detect-ifaces
source ~/.config/fpv-router/router.env
```

The helper was installed onto the Pi in Step 2 and lives in this repo at `scripts/pi/fpv-router-detect-ifaces`.

### 5.2 Load the variables automatically in future shells

```bash
LINE='source ~/.config/fpv-router/router.env 2>/dev/null || true'
grep -qxF "$LINE" ~/.bashrc || printf '%s\n' "$LINE" >> ~/.bashrc

source ~/.bashrc
```

### 5.3 Verify what was detected

The script already asked you for the router AP name and password and wrote them into `~/.config/fpv-router/router.env`, so there is no hand-edit step here.

```bash
echo "WAN_IF=$WAN_IF"
echo "AP_IF=$AP_IF"
echo "AP_SSID=$AP_SSID"
printf 'AP_PSK_LENGTH=%s\n' "${#AP_PSK}"
ip link
iw dev
```

You should see:
- `$WAN_IF` = USB Wi-Fi dongle
- `$AP_IF` = internal Pi Wi-Fi
- `$AP_SSID` = the router AP name you entered

---

## 6. Create the remembered upstream Wi-Fi list

This is how the router will remember multiple upstream networks later.

### 6.1 Run the installed initial upstream Wi-Fi wizard

```bash
sudo /usr/local/sbin/set-initial-uplink-wifi
```

The helper was installed onto the Pi in Step 2 and lives in this repo at `scripts/pi/set-initial-uplink-wifi`.

The wizard writes the first remembered upstream Wi-Fi entry to `/etc/fpv-router/uplinks.conf` without asking you to hand-edit a command block.

Example only: one remembered upstream Wi-Fi might be called WorkshopWiFi24, and another might be called FieldHotspot2G.

You will use the terminal wizard in Step 18 later if you want to add, delete, or update remembered upstream Wi-Fi networks without editing this file by hand.

---

## 7. Render the router configuration

This script generates all router config files using the auto-detected interface names and the remembered upstream Wi-Fi list.

### 7.1 Run the installed configuration renderer

```bash
sudo /usr/local/sbin/render-fpv-router-config
```

The helper was installed onto the Pi in Step 2 and lives in this repo at `scripts/pi/render-fpv-router-config`.

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

### NOW CLOSE THE TERMINAL, OPEN A NEW TERMINAL, AND SSH BACK INTO YOUR PI

The network path usually changes here, so the SSH session you were using may stop responding. That is normal.

SSH back into the router the same way that works on your network, then continue below.

### Then source `.bashrc`

```bash
source ~/.bashrc
```

---

## 10. Verify the route fix worked

Run:

```bash
ip route
ip addr show "$AP_IF"
```

You want to see:

- a default route that uses `$WAN_IF` with metric `100`

And on `ip addr show "$AP_IF"` you want to see:

```text
inet 10.42.0.1/24
```

If the default route is not through `$WAN_IF`, or if `$AP_IF` does not have `10.42.0.1/24`, stop here and fix that before continuing.

---

## 11. Reboot once before bringing up the AP services

This reboot is deliberate and important. It clears stale client-side state and makes the AP role transition reliable.

Run:

```bash
sudo reboot
```

### SSH BACK INTO YOUR PI!

Then run:  

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
sudo systemctl daemon-reload
sudo systemctl unmask hostapd
sudo systemctl enable hostapd dnsmasq wifi-powersave-off
```

---

## 13. Set up NAT and forwarding

### 13.1 Clear any stale rules

```bash
sudo iptables -F
sudo iptables -t nat -F
```

### 13.2 Add the correct rules

```bash
sudo iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE
sudo iptables -A FORWARD -i "$AP_IF" -o "$WAN_IF" -j ACCEPT
sudo iptables -A FORWARD -i "$WAN_IF" -o "$AP_IF" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
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
sudo systemctl status dnsmasq --no-pager
sudo systemctl status hostapd --no-pager
```

Both should be **active (running)**.

---

## 15. Verify the AP is really up

Run:

```bash
iw dev "$AP_IF" info
```

At this point you want to see:
- `ssid` matching the `AP_SSID` value you saved earlier
- `type AP`

If you see `type managed`, do not continue. That means something is still trying to use the AP interface as a client.

With the tutorial above, it should be `type AP`.

---

## 16. Connect a client and verify DHCP + internet

Connect your laptop, phone, or robot to:

- **SSID**: the router AP name you entered in Step 5
- **Password**: the router AP password you entered in Step 5

### 16.1 Verify DHCP on the Pi

Run:

```bash
sudo journalctl -u dnsmasq -n 50 --no-pager
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
- the AP appears with the SSID from `AP_SSID`
- clients connect and get `10.42.0.x`
- clients get internet through the upstream Wi-Fi
- no monitor is needed

---

## 18. Reuse the uplink wizard later

The uplink management helper was already installed onto the Pi in Step 2 and lives in this repo at `scripts/pi/manage-uplink-wifis`.

### 18.1 Use it later

Connect to the router through the AP network:

```bash
[ -n "${PI_USER:-}" ] || read -rp "Enter the Linux USERNAME chosen in Raspberry Pi Imager for the ROUTER: " PI_USER
ssh "${PI_USER}@10.42.0.1"
```

Then run:

```bash
sudo /usr/local/sbin/manage-uplink-wifis
```

The wizard will:
- print the names of all remembered upstream Wi-Fi networks
- ask whether you want to add a new one
- show a detected Wi-Fi list when adding, while still allowing manual SSID entry
- add a new upstream Wi-Fi
- modify the password for a remembered upstream Wi-Fi
- delete a remembered upstream Wi-Fi
- automatically re-render and reapply the WAN-side config when you finish

Example only: one remembered upstream Wi-Fi might be called WorkshopWiFi24, and another might be called FieldHotspot2G.

The wizard stores the remembered upstream networks in `/etc/fpv-router/uplinks.conf`.
It prints SSID names, but it does not print saved passwords.

### 18.2 Verify afterwards

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
sudo systemctl status hostapd --no-pager
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
cat /etc/netplan/01-router.yaml
ip route
```

### Need to re-render everything after changing saved values

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

The commands stay portable across different Raspberry Pi 4 builds and different USB Wi-Fi dongles because the interface names are detected automatically once and then reused when the router configuration is rendered.
<br>  
