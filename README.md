# FPV_router
This repository contains instructions for building a powerful FPV robotics router from a Raspberry Pi 4 and a common WiFi dongle.  The router is optimized for low-latency first-person-view robotics operations.

# MATERIALS: 

### ONE Raspberry Pi 4 (5 also works)

### ONE WiFi dongle

### ONE Raspberry Pi charger 

### ONE SD card (at least 32 gigs)

<br>  
<br>  
<br>  

# INSTRUCTIONS

<br>

# 1. Prepare your SD Card for the Raspberry Pi

### NOTE: Use the official Raspberry Pi Imager!

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

## 2.1 



