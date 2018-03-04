#!/bin/bash
xinput_calibrator --output-filename /home/volumio/calib.txt
cat /home/volumio/calib.txt >> /usr/share/X11/xorg.conf.d/10-evdev.conf
#/usr/bin/startx /etc/X11/Xsession /opt/calib.sh --

