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
apt-get -y install u-boot-tools mc lirc

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

echo "  Configure LIRC_BBB"
echo "# /etc/lirc/hardware.conf
#
# Arguments which will be used when launching lircd
LIRCD_ARGS=""

#Don't start lircmd even if there seems to be a good config file
#START_LIRCMD=false

#Don't start irexec, even if a good config file seems to exist.
#START_IREXEC=false

#Try to load appropriate kernel modules
LOAD_MODULES=true

# Run "lircd --driver=help" for a list of supported drivers.
DRIVER="default"
# usually /dev/lirc0 is the correct setting for systems using udev
DEVICE="/dev/lirc0"
MODULES="lirc_bbb"

# Default configuration files for your hardware if any
LIRCD_CONF=""
LIRCMD_CONF=""
" > /etc/lirc/hardware.conf
echo "
# Please make this file available to others
# by sending it to <lirc@bartelmus.de>
#
# this config file was automatically generated
# using lirc-0.9.0-pre1(default) on Tue Mar 13 15:19:03 2018
#
# contributed by 
#
# brand:                       MyRemote.conf
# model no. of remote control: 
# devices being controlled by this remote:
#

begin remote

  name  MyRemote.conf
  flags RAW_CODES
  eps            30
  aeps          100

  gap          95957

      begin raw_codes

          name BTN_1
             9013    4580     472     664     533     583
              555     579     476     663     534     583
              555     580     474     664     533     583
              553    1712     529    1711     493    1752
              552    1716     533    1713     484    1751
              550    1711     529    1712     494    1751
              552     580     494     641     529    1710
              496     641     529     585     550     581
              495     641     529     585     552    1709
              529    1713     494     641     529    1711
              495    1749     552    1711     529    1711
              495   39914    8986    2322     527

          name BTN_2
             9012    4577     474     663     533     585
              555     580     476     666     531     584
              553     581     475     664     532     585
              555    1710     533    1708     477    1775
              552    1712     533    1708     477    1774
              556    1711     533    1710     476    1771
              557     579     478    1772     556    1712
              530    1709     475     664     531     585
              555     580     476     664     535    1707
              480     661     534     584     556     579
              476    1772     556    1710     531    1710
              475   39858    9006    2350     529

          name BTN_3
             8999    4559     482     642     532     580
              551     585     469     666     522     584
              551     581     473     663     535     581
              552    1711     533    1710     475    1772
              555    1710     533    1709     473    1774
              552    1711     531    1710     474    1775
              553    1710     531    1710     472    1774
              552    1711     531     584     554     579
              473     664     532     584     554     579
              474     664     531     584     553     580
              473    1775     552    1710     557    1685
              472   39936    9004    2322     557

          name BTN_4
             9027    4579     473     665     531     583
              555     579     474     664     534     582
              557     578     476     663     534     583
              556    1709     535    1709     473    1773
              555    1709     533    1709     475    1775
              552    1710     533    1709     475    1772
              554     580     477    1770     554    1710
              533     583     554     579     475     664
              532     584     555     578     477    1770
              557     578     474     664     534    1708
              475    1772     555    1712     531    1709
              476   39956    9050    2345     533

          name BTN_5
             9143    4521     533     580     477     665
              511     608     555     580     476     664
              532     586     556     578     477     663
              532    1711     476    1776     549    1712
              531    1712     474    1773     553    1712
              531    1712     476    1771     552    1714
              531     586     551     582     476    1771
              553    1711     531     586     551     582
              475     664     530     586     553    1714
              529    1712     474     664     530     587
              552    1712     531    1711     477    1770
              552   39854    9052    2263     473

          name BTN_6
             9122    4497     533     602     478     664
              511     608     557     580     478     663
              532     584     557     579     476     663
              510    1734     477    1772     554    1715
              528    1711     477    1772     554    1712
              532    1715     474    1771     557    1712
              510    1734     476     663     533    1714
              473    1772     556     580     476     664
              532     585     555     580     475     664
              532    1715     474     664     535     584
              555    1711     533    1712     475    1772
              562   39758    9097    2255     474

          name BTN_7
             9181    4520     537     601     479     664
              514     607     536     606     475     664
              515     604     538     602     480     662
              516    1732     479    1772     536    1733
              537    1710     479    1771     536    1733
              513    1736     477    1773     534    1734
              536     583     559     580     478     664
              513    1736     475     664     513     606
              535     601     481     662     537    1709
              479    1772     536    1732     515     607
              557    1710     538    1708     479    1775
              555   39852    9092    2289     475

          name BTN_8
             9064    4521     552     581     475     663
              533     585     533     603     529     611
              512     606     533     603     477     663
              514    1729     479    1770     531    1734
              508    1734     530    1722     529    1734
              511    1734     476    1773     531    1738
              507     607     532    1735     510     607
              532    1734     509     607     528     605
              474     666     504     610     530    1734
              509     608     532    1734     510     608
              532    1738     507    1734     476    1772
              530   39877    9049    2283     474

          name BTN_9
             9268    4494     567     572     484     664
              512     611     543     598     481     663
              517     605     540     600     483     664
              517    1730     481    1771     561    1709
              516    1734     477    1772     538    1731
              516    1731     480    1772     540    1729
              516    1733     482    1771     569     573
              485    1771     568     575     484     663
              548     578     570     573     486     663
              546     577     545    1739     509     603
              570    1701     518    1729     483    1771
              535   39840    9378    2245     499

          name BTN_0
             9084    4496     555     578     476     664
              534     582     555     579     476     663
              534     583     555     579     475     663
              534    1708     478    1770     555    1710
              534    1709     474    1773     557    1712
              534    1709     478    1772     558     578
              478    1773     557     580     475     663
              537    1709     478     664     537     582
              560     577     476    1773     557     581
              473    1773     554    1710     534     582
              557    1709     534    1711     473    1773
              555   39797    9122    2259     475

          name BTN_BASE
             9032    4501     547     585     491     641
              528     586     549     582     494     642
              529     585     550     580     472     664
              528    1714     492    1752     548    1713
              529    1712     493    1750     551    1714
              527    1710     494    1751     550     581
              493    1751     553     579     494     641
              528     585     550     582     471     664
              530     583     550    1713     528     585
              553    1709     528    1712     494    1751
              550    1710     529    1714     492    1750
              549   39856    9038    2261     473

          name BTN_BASE2
             9334    4415     567     575     537     640
              528     598     560     595     453     668
              548     574     570     567     492     690
              515    1704     483    1782     560    1709
              543    1702     484    1780     553    1717
              535    1713     472    1774     562     572
              482    1777     582     554     481    1783
              558     571     483     663     520     604
              568     572     478    1783     557     574
              481    1778     559     577     478    1784
              557    1708     538    1717     467    1778
              563   39741    9133    2281     481

          name BTN_BASE3
             9117    4578     478     663     537     582
              559     578     478     664     535     584
              557     578     476     664     534     583
              555    1714     530    1710     475    1772
              556    1716     542    1705     475    1765
              557    1708     535    1709     476     665
              533     584     563     572     475     664
              533     583     562     578     473    1772
              554     580     474    1774     562    1702
              533    1710     475    1772     555    1711
              533    1713     473     664     532    1711
              476   39929    9053    2343     535

          name BTN_BASE4
             9002    4588     469     664     537     582
              559     577     478     664     538     582
              564     573     476     664     537     582
              559    1709     534    1709     475    1774
              557    1708     535    1709     475    1773
              556    1710     536    1711     474     664
              534    1709     475    1774     555    1711
              533    1713     471     664     533     584
              555     579     475    1773     555     580
              475     664     533     585     553     579
              475    1773     555    1710     534    1710
              475   39946    9040    2335     531

          name BTN_BASE5
             9086    4578     478     663     543     581
              565     577     480     663     537     583
              559     579     480     663     538     587
              556    1709     539    1708     479    1772
              559    1710     537    1714     477    1773
              561    1710     539    1710     482     664
              543     580     563    1708     530    1720
              482     664     541     582     564    1708
              544     579     565    1708     540    1709
              482     663     541     582     562    1709
              542    1707     482     663     517    1734
              481   39799    9129    2344     536

          name BTN_BASE6
             9106    4582     477     663     537     582
              558     578     477     663     535     583
              557     578     475     665     533     583
              555    1715     530    1710     475    1772
              558    1710     535    1712     472    1774
              557    1710     537    1708     479    1773
              559     581     475    1773     560     578
              478     665     538     582     560     578
              479     664     538     582     560    1711
              536     582     560    1708     537    1709
              478    1774     557    1710     536    1709
              477   39938    9054    2346     537

          name BTN_BACK
             9151    4580     480     664     544     581
              567     576     485     664     544     581
              567     580     481     664     544     581
              567    1707     543    1708     484    1772
              567    1710     541    1707     484    1772
              567    1706     543    1710     481     663
              544     581     566    1707     543    1707
              483     664     544     581     541     602
              483     663     544    1708     483    1773
              564     578     484     663     543    1711
              480    1773     566    1707     545    1706
              484   39923    9145    2345     542

          name BTN_A
             9065    4577     477     663     534     586
              555     580     478     663     534     585
              554     581     477     664     533     585
              556    1715     531    1709     530    1719
              531    1736     535    1712     475    1772
              533    1734     533    1712     478    1770
              556     584     476    1772     554    1713
              509     609     555     580     478    1772
              557     580     478     663     535    1710
              479     663     535     586     554    1713
              535    1710     479     664     534    1710
              480   39929    9056    2344     535

          name BTN_B
             9042    4582     478     663     512     607
              557     583     475     664     535     585
              556     580     478     664     512     607
              534    1733     512    1737     475    1773
              555    1712     535    1711     477    1773
              559    1709     511    1734     478     664
              510     607     557    1711     536     583
              558    1709     513     606     533    1735
              513     606     556    1711     536    1713
              474     663     535    1711     477     663
              534    1711     478     663     512    1736
              475   39936    9051    2344     535

          name BTN_C
             9053    4579     476     664     536     582
              557     579     478     663     537     582
              558     578     478     664     534     584
              559    1709     537    1708     477    1773
              557    1709     536    1710     479    1770
              557    1710     536    1708     478     663
              536    1709     479    1771     557     579
              476    1773     557     579     476     664
              535     583     556    1713     533     583
              556     579     476    1772     557     579
              476    1772     558    1713     531    1709
              476   39962    9028    2344     524

          name BTN_X
             8989    4581     472     664     533     582
              556     579     478     661     532     584
              555     579     474     665     532     584
              556    1709     534    1709     478    1771
              556    1710     536    1708     477    1773
              557    1711     532    1710     474     664
              535     582     556    1710     533    1708
              476    1772     556     579     474     664
              533     583     554    1711     532    1712
              471     665     531     585     553     579
              474    1772     555    1710     532    1713
              472   39933    9008    2349     531


      end raw_codes

end remote
" > /etc/lirc/lircd.conf

echo "begin
prog = irexec
button = OK
config = /usr/local/bin/volumio toggle
end
begin
prog = irexec
button = BTN_BASE4
config = /usr/local/bin/volumio volume plus
end
begin
prog = irexec
button = BTN_BASE2
config = /usr/local/bin/volumio volume minus
end
begin
prog = irexec
button = BTN_BASE6
config = /usr/local/bin/volumio next
end
begin
prog = irexec
button = BTN_BASE
config = /usr/local/bin/volumio previous
end
begin
prog = irexec
button = BTN_C
config = /usr/local/bin/volumio volume toggle
repeat = 0
end
begin
prog = irexec
button = BTN_BACK
config = /usr/local/bin/volumio seek plus
end
begin
prog = irexec
button = BTN_BASE5
config = /usr/local/bin/volumio seek minus
end
begin
prog = irexec
button = BTN_BASE3
config = /usr/local/bin/volumio repeat
end
begin
prog = irexec
button = BTN_X
config = /usr/local/bin/volumio random
end
begin
prog = irexec
button = BTN_A
config = /usr/bin/sudo systemctl poweroff
end
begin
prog = irexec
button = BTN_B
config = /usr/local/bin/volumio clear
end
" > /etc/lirc/lircrc
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
