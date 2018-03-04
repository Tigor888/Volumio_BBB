#!/bin/bash
xset s noblank
xset s off
xset -dpms
openbox-session &
while true; do
  /usr/bin/chromium-browser \
    --disable-pinch \
    --kiosk \
    --no-first-run \
    --disable-3d-apis \
    --disable-breakpad \
    --disable-crash-reporter \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-translate \
    --user-data-dir='/data/volumiokiosk'     --no-sandbox     http://localhost:3000
done
