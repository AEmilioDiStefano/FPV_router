# FPV_router
This repository contains instructions for building a powerful FPV robotics router from a Raspberry Pi 4 and a common WiFi Dongle.  The router is optimized for low-latency first-person-view robotics operations.

<br>  
<br>  
<br>  

# MATERIALS: 

### ONE Raspberry Pi 4 (5 also works)

### ONE USB WiFi Dongle

### ONE Raspberry Pi charger 

### ONE SD card (at least 32 gigs)

<br>  
<br>  
<br>  

# INSTRUCTIONS

<br>

# 1. Prepare your SD Card for the Raspberry Pi

###  NOTE: Use the official Raspberry Pi Imager!

<br>

## 1.1 Insert your SD card in to your laptop via USB adapter or full-sized SD adapter

<br>

## 1.2 Open the Raspberry Pi Imager and enter the following specifications:

**Raspberry Pi 4** as your **Raspberry Pi Device** (unless you are using a Raspberry Pi 5)

**Ubuntu Server 24.04.3 LTS (64-BIT)** as your **Operating System** (this will be under "General Purpose OS" and then "Ubuntu")

**The SD card you would like to flash** as your **Storage**

<br>

## 1.3 Set your initial specifications for the Pi

After you have set the **Raspberry Pi Device**, **Operating System**, and **Storage**, click **NEXT** and you will see a pop-up window asking if you would like to apply OS customization settings.  

Click **EDIT SETTINGS** and another pop-up will appear where you are prompted to **Set hostname**, **Set username and password**, and **Configure Wireless LAN**.

**Under the "GENERAL" tab**, set the **hostname** that you would like to use for this router.  **This tutorial will use the hostname "gamboa"**, so if you want to use a differenty hostname for some reason, **remember to replace "gamboa" throughout this tutorial with your chosen hostname**.

**Under "Set username and password**, set the **Username** and **Password** that you would like to use **for your router**.  **This tutorial will use the username "router"**, so if you want to use a differenty username for some reason, **remember to replace "router" throughout this tutorial with your chosen username**.

**Under "Configure Wireless LAN"**, set the **SSID** and **Password** of the network that you would like for your your device to connect to initially **(usually your home or office WiFi)**.  This will be different for everyone, so be sure to take a close look at all of the commands in this tutorial and **be sure to replace the SSID and Password used in this tutorial with your own**.

**Under the "SERVICES" tab**,  make sure that **Enable SSH** is checked and that **Use password authentication** is selected.

**Under the "OPTIONS" tab**, make sure that all three boxes are checked.

**Before saving these changes, go back to the GENRRAL tab and take a screenshot so that you don't forget your settings** write down your passwords ona piece of paper or use a reliable and secure password-saving system.

**Click SAVE** at the bottom of the **EDIT SETTINGS** pop-up window, which should take you back to the **"Would you like to apply custom OS settings?"** pop-up.  Now that you have set your customized settings, click **YES**.

**WAIT FOR THE PROCESS TO BE COMPLETED** before removing your micro-SD card from your laptop.

<br>  
<br>  
<br>  

# 2. SSH into your Raspberry Pi

**Connect your SD card and your WiFi Dongle into your Pi and power on the Pi**.

<br>

## 2.1 Open a terminal and enter the following command:

```shell
ssh [username]@[hostname].local
```

**REMEMBER TO REPLACE [username] and [hostname]** with the username and hostname you set in **Step 1**!

Example:

```shell
ssh router@gamboa.local
```

**If you have any issues**, try using **arp-scan**:

```shell
sudo arp-scan --localnet
```

**This will show all devices currently connected to your neteork by IP address**.  If you are unable to SSH into your Pi using <hostname>.local, try using the following command:

```shell
ssh router@[ip address of Pi]
```

<br>
<br>
<br>

# 3. Verify your interfaces

<br>

## 3.1 Install iw (networking tool)

```shell
sudo apt install iw
```

<br>

## 3.2 Check the names of your interfaces

**ENTER** the following commands:

```shell
ip link
```

**The first command** (ip link) will show you your network interfaces.  

**INTERFACE 1** will likely be called "lo" and is a loopback interface which you will not need to touch in this tutorial.

**INTERFACE 2** will likely be called **eth0** but may be called something else on your device. 

**INTERFACE 3** will likely be called **wlan0** but may be called somethign else on your device.  **If wlan0 is not the name of this interface, then write down your actual interface name for use in this tutorial** and **replace wlan0** throughout this tutorial** with your actual interface name set for the WiFi Dongle.

**INTERFACE 4** will almost certainly reference **the interface created by your USB WiFi Dongle** (which at this point should be plugged into your Raspberry Pi).  A common default name for this interface on the Pi is  **wlx98ba5f8094f7**.  If this interface has a different name, then **TAKE NOTE OF THIS INTERFACE NAME** (you will be using it later) and **replace wlx98ba5f8094f7 throughout this tutorial** with your actual interface name set for the WiFi Dongle. 

<br>  

### ANOTHER WAY to get the interface name for your USB WiFi Dongle is to enter:

```shell
iw dev
```
You should see **two specifications**: **phy0** and **phy1**.  The interface name for your USB WiFi dongle will almost certainly be specified on the first line of **phy0**.  Again, a common default name for this interface on the Pi is  **wlx98ba5f8094f7**.  If this interface has a different name, then **TAKE NOTE OF THIS INTERFACE NAME** (you will be using it later) and **replace wlx98ba5f8094f7 throughout this tutorial** with your actual interface name set for the WiFi Dongle. 

**Now that you have the names of all of your network interfaces**, continue on to the next step.

<br>  
<br>  
<br>  

# 4. Remove potential DNS conflicts and install required packages

On Ubuntu, **port 53 is owned by systemd-resolved by default**.  This will interfere withour router's functionality, so we will **disable systemd-resolved** before proceeding:

```shell
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
```

**FIX** resolve.conf

```shell
sudo rm /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

<br>  

**INSTALL** the following packages:

```shell
sudo apt update
sudo apt install -y \
  hostapd \
  dnsmasq \
  iptables-persistent \
  netfilter-persistent
```

**STOP hostpad and dnsmasq** while we configure the router.

```shell
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq
```

<br>  
<br>  
<br>  

# 5. Configure netplan and force default route

<br>  

## 5.1 Define where your WiFi Dongle will get WiFi for the router

Open **/etc/netplan/01-router.yaml** in nano:

```shell
sudo nano /etc/netplan/01-router.yaml
```

**Once 01-router.yaml is opened**, paste the following file contents:

```shell
network:
  version: 2
  renderer: networkd

  wifis:
    wlx98ba5f8094f7:
      dhcp4: true
      optional: true
      access-points:
        "IZZI-E81F":
          password: "REAL_WIFI_PASSWORD"

  ethernets:
    wlan0:
      dhcp4: false
      addresses:
        - 10.42.0.1/24
      optional: true
```

**REMEMBER TO EDIT THESE CONTENTS WITH YOUR OWN SYSTEM-SPECIFIC INFORMATION!** 

**If your USB WiFi Dongle interface has a name other than wlx98ba5f8094f7**, then **replace wlx98ba5f8094f7** with the name of your actual interface.

**REPLACE** IZZI-E81F with **the SSID of the network you would like to connect to** (usually home or office WiFi).

**REPLACE** REAL_WIFI_PASSWORD with **the PASSWORD of the network you would like to connect to** (usually home or office WiFi).

**NOW** apply these changes safely:

```shell
sudo netplan generate
sudo netplan apply
```

<br>  

## 5.2 Force a default route 

**This assures** that your default interface (used for getting WiFi for the device) is thur **USB WiFi Dongle** interface rather than wlan0.

Open **/etc/systemd/network/10-wlx-uplink.network** in nano:

```shell
sudo nano /etc/systemd/network/10-wlx-uplink.network
```

**Once 10-wlx-uplink.network is opened**, paste the following file contents:

```shell
[Match]
Name=wlx98ba5f8094f7

[Network]
DHCP=yes

[DHCP]
RouteMetric=100
```

**REMEMBER TO EDIT THESE CONTENTS WITH YOUR OWN SYSTEM-SPECIFIC INFORMATION!** 

**If your USB WiFi Dongle interface has a name other than wlx98ba5f8094f7**, then **replace wlx98ba5f8094f7** with the name of your actual interface.

<br>  

Now restart your Pi's networking:

**IMPORTANT NOTE:  This step will shut down SSH between your laptop and your Pi, so after you enter the following command, exit out of the terminal window, open a new terminal, and SSH into your Pi again as you did in Step 2**.

```shell
sudo systemctl restart systemd-networkd
```

**NOW SSH BACK INTO YOUR PI**

**Exit out of the terminal window, open a new terminal, and SSH into your Pi again as you did in Step 2**.

Once back in, enter the following command:

```shell
ip route
```

**You should see**:

```shell
default via 192.168.x.1 dev wlx98ba5f8094f7 metric 100
```

**IMPORTANT NOTE:  If your USB WiFi Dongle interface is named differently than wlx98ba5f8094f7, then THAT NAME is what you should see im place of wlx98ba5f8094f7 in the above output**.

**If wlan0 is still the default (if wlan0 appears in the deefault line rather than the name of your USB WiFi dongle interface), then go back to Step 3 and make sure you follow the instrudctions correctly.**





