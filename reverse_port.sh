#!/bin/bash
~/Library/Android/sdk/platform-tools/adb reverse tcp:8000 tcp:8000
echo "ADB Port 8000 reversed successfully!"
