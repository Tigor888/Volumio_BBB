#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Creating \"fstab\""
echo "# bbb fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab


echo "Installing additonal packages"
apt-get update
apt-get -y install u-boot-tools mc

echo "Adding custom modules loop, overlayfs, squashfs, nls_cp437, usb-storage and nls_iso8859_1"
echo "loop" >> /etc/initramfs-tools/modules
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules
echo "nls_iso8859_1" >> /etc/initramfs-tools/modules
echo "usb-storage" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

#On The Fly Patch
if [ "$PATCH" = "volumio" ]; then
echo "No Patch To Apply"
else
echo "Applying Patch ${PATCH}"
PATCHPATH=/${PATCH}
cd $PATCHPATH
#Check the existence of patch script
if [ -f "patch.sh" ]; then
sh patch.sh
else
echo "Cannot Find Patch File, aborting"
fi
cd /
rm -rf ${PATCH}
fi
rm /patch

# Retrieve choosen kernel version
uname_r=$(sed -n 's/^uname_r=//p' /boot/uEnv.txt)
# Update kernel dependencies

depmod ${uname_r}

#sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

echo "Installing Kiosk"

echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

  echo "Installing Chromium Dependencies"
  apt-get update
  apt-get -y install
  echo "Installing Graphical environment"
  DEBIAN_FRONTEND=noninteractive apt-get install -y xinit xorg matchbox-window-manager matchbox-keyboard libexif12 xinput-calibrator

  echo "Download Chromium"
  cd /home/volumio/
  wget http://launchpadlibrarian.net/234969703/chromium-browser_48.0.2564.82-0ubuntu0.15.04.1.1193_armhf.deb
  wget http://launchpadlibrarian.net/234969705/chromium-codecs-ffmpeg-extra_48.0.2564.82-0ubuntu0.15.04.1.1193_armhf.deb

  echo "Install  Chromium"
  dpkg -i /home/volumio/chromium-*.deb
  apt-get install -y -f
  dpkg -i /home/volumio/chromium-*.deb

  rm /home/volumio/chromium-*.deb


#echo "Installing Japanese, Korean, Chinese and Taiwanese fonts"

#  cd /home/volumio/
#  wget http://ftp.ru.debian.org/debian/pool/main/x/xinput-calibrator/xinput-calibrator_0.7.5+git20140201-1+b2_armhf.deb
#  sudo dpkg -i -B xinput-calibrator_0.7.5+git20140201-1+b2_armhf.deb
#  rm /home/volumio/xinput-calibrator_0.7.5+git20140201-1+b2_armhf.deb
# *********************************************************************************
# xset +dpms
# xset s blank
# xset 0 0 120
# matchbox-keyboard -d &
# matchbox-window-manager -use_titlebar no &

##!/bin/bash
#xset -dpms
#xset s off
#xset s noblank

#matchbox-keyboard -d &
#matchbox-window-manager -use_titlebar no &

## openbox-session &
#while true; do
#rm -rf ~/.{config,cache}/chromium/
#/usr/bin/chromium-browser --disable-session-crashed-bubble --disable-infobars --kiosk --no-first-run 'http://localhost:3000'


echo "Dependencies installed"

echo "Creating Kiosk Data dir"
mkdir /data/volumiokiosk

echo "  Creating chromium kiosk start script"
echo "#!/bin/bash
xset s noblank
xset s off
xset -dpms
matchbox-keyboard -d &
matchbox-window-manager -use_titlebar no &
while true; do
  /usr/bin/chromium-browser \\
    --disable-pinch \\
    --kiosk \\
    --no-first-run \\
    --disable-3d-apis \\
    --disable-breakpad \\
    --disable-crash-reporter \\
    --disable-infobars \\
    --disable-session-crashed-bubble \\
    --disable-translate \\
    --user-data-dir='/data/volumiokiosk' \
    --no-sandbox \
    http://localhost:3000
done" > /opt/volumiokiosk.sh
/bin/chmod +x /opt/volumiokiosk.sh

echo "#!/bin/bash
xinput_calibrator --output-filename /home/volumio/calib.txt
cat /home/volumio/calib.txt >> /usr/share/X11/xorg.conf.d/10-evdev.conf
#/usr/bin/startx /etc/X11/Xsession /opt/calib.sh --
" > /opt/calib.sh
/bin/chmod +x /opt/calib.sh

echo "Creating Systemd Unit for Kiosk"
echo "[Unit]
Description=Start Volumio Kiosk
Wants=volumio.service
After=volumio.service
[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh --
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300
[Install]
WantedBy=multi-user.target
" > /lib/systemd/system/volumio-kiosk.service
/bin/ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service


echo "  Allowing volumio to start an xsession"
/bin/sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

echo "Disabling Kiosk Service"


#requred to end the plugin install
echo "plugininstallend"

echo "Configuring hostapd"
echo "interface=wlan0
ssid=Volumio
channel=4
hw_mode=g
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=volumio2

##### hostapd configuration file ##############################################

ctrl_interface=/var/run/hostapd

##### Wi-Fi Protected Setup (WPS) #############################################

eap_server=1

# WPS state
# 0 = WPS disabled (default)
# 1 = WPS enabled, not configured
# 2 = WPS enabled, configured
#wps_state=2

uuid=12345678-9abc-def0-1234-56789abcdef0

# Device Name
# User-friendly description of device; up to 32 octets encoded in UTF-8
device_name=RTL8188EU

# Manufacturer
# The manufacturer of the device (up to 64 ASCII characters)
manufacturer=Realtek

# Model Name
# Model of the device (up to 32 ASCII characters)
model_name=RTW_SOFTAP

# Model Number
# Additional device description (up to 32 ASCII characters)
model_number=WLAN_CU
# Serial Number
# Serial number of the device (up to 32 characters)
serial_number=12345

# Primary Device Type
# Used format: <categ>-<OUI>-<subcateg>
# categ = Category as an integer value
# OUI = OUI and type octet as a 4-octet hex-encoded value; 0050F204 for
#       default WPS OUI
# subcateg = OUI-specific Sub Category as an integer value
# Examples:
#   1-0050F204-1 (Computer / PC)
#   1-0050F204-2 (Computer / Server)
#   5-0050F204-1 (Storage / NAS)
#   6-0050F204-1 (Network Infrastructure / AP)
device_type=6-0050F204-1

# OS Version
# 4-octet operating system version number (hex string)
os_version=01020300

# Config Methods
# List of the supported configuration methods
config_methods=label display push_button keypad


##### default configuration #######################################

driver=rtl871xdrv
beacon_int=100
ieee80211n=1
wme_enabled=1
ht_capab=[SHORT-GI-20][SHORT-GI-40]
max_num_sta=8
wpa_group_rekey=86400
" > /etc/hostapd/hostapd.conf

echo "Hostapd conf files"
cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.tmpl
chmod -R 777 /etc/hostapd

echo "blacklist rtl8192cu" | tee -a /etc/modprobe.d/blacklist.conf
echo "blacklist rtl8xxxu" | tee -a /etc/modprobe.d/blacklist.conf
echo "blacklist rtl8192c_common" | tee -a /etc/modprobe.d/blacklist.conf

echo "Add to first start calibration"
echo "/usr/bin/startx /etc/X11/Xsession /opt/calib.sh --
reboot
" >> /bin/firststart.sh

# Reduce locales to just one beyond C.UTF-8
echo "Existing locales:"
locale -a
echo "Generating required locales:"
[ -f /etc/locale.gen ] || touch -m /etc/locale.gen
#echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "Removing unused locales"
echo "en_US.UTF-8" >> /etc/locale.nopurge
echo "ru_RU.UTF-8" >> /etc/locale.nopurge
# To remove existing locale data we must turn off the dpkg hook
sed -i -e 's/^USE_DPKG/#USE_DPKG/' /etc/locale.nopurge
# Ensure that the package knows it has been configured
sed -i -e 's/^NEEDSCONFIGFIRST/#NEEDSCONFIGFIRST/' /etc/locale.nopurge
dpkg-reconfigure localepurge -f noninteractive
localepurge
# Turn dpkg feature back on, it will handle further locale-cleaning
sed -i -e 's/^#USE_DPKG/USE_DPKG/' /etc/locale.nopurge
dpkg-reconfigure localepurge -f noninteractive
echo "Final locale list"
locale -a
echo ""

echo "Installing winbind here, since it freezes networking"
apt-get update
apt-get install -y winbind libnss-winbind

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

# Retrieve choosen kernel version
uname_r=$(sed -n 's/^uname_r=//p' /boot/uEnv.txt)
# Update kernel dependencies

depmod ${uname_r}

#sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

mv -f /boot/volumio.initrd /boot/initrd.img-${uname_r}

# BBB bootloader searches kernel+dtb+initrd in the /boot subdir of the boot volume
cd /boot
mkdir boot
mv -t boot dtbs/ *${uname_r}
