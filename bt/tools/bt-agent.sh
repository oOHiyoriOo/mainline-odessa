#!/bin/sh
# Keep a Just-Works pairing agent registered.
#
# The image is headless: without an agent bluetoothd cannot answer an incoming
# SSP request, and pairing from a phone fails with 0x05 (Authentication
# Failed) / "PIN or Passkey wrong".  bluetoothctl must stay alive for the
# agent to remain registered, so feed it a long-lived stdin.
while true; do
    sleep 86400 | /usr/bin/bluetoothctl --agent NoInputNoOutput >/dev/null 2>&1
    sleep 5
done
