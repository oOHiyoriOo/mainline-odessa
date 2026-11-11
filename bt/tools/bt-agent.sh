#!/bin/sh
# Keep a Just-Works pairing agent registered *and default*.
#
# The image is headless: without a default NoInputNoOutput agent bluetoothd
# falls back to an agent that asks for passkey confirmation, which nobody can
# answer, and pairing fails with 0x05 (Authentication Failed) - the phone shows
# "PIN or Passkey wrong".  bluetoothctl must stay alive for the registration to
# hold, so feed it a long-lived stdin.
while true; do
    {
        echo "agent NoInputNoOutput"
        sleep 1
        echo "default-agent"
        sleep 86400
    } | /usr/bin/bluetoothctl --agent NoInputNoOutput >/dev/null 2>&1
    sleep 5
done
