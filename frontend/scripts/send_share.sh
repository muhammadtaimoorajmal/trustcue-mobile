#!/bin/sh
# TrustCue Android Intent Share Dispatch Helper
# Location: frontend/scripts/send_share.sh
# Usage: ./send_share.sh [optional_text_or_path]

DEFAULT_DEVICE_SAMPLE="/data/local/tmp/sample_benign.txt"

if [ -n "$1" ]; then
  if [ -f "$1" ]; then
    MSG=$(cat "$1")
  else
    MSG="$1"
  fi
elif [ -f "$DEFAULT_DEVICE_SAMPLE" ]; then
  MSG=$(cat "$DEFAULT_DEVICE_SAMPLE")
else
  MSG="Hi Mom, what time is dinner tonight? Can you please ask Dad to pick up milk on his way home from work? Thanks!"
fi

am start -n io.github.muhammadtaimoorajmal.trustcue/.MainActivity \
  -a android.intent.action.SEND \
  -t text/plain \
  --es android.intent.extra.TEXT "$MSG"
