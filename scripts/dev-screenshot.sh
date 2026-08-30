#!/bin/zsh
# Builds the app, relaunches it, opens the launcher through the
# com.omnicast.open notification, and captures the screen to the given path.
set -euo pipefail
out="${1:-.build-app/launcher.png}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
scripts/build-app.sh >/dev/null
pkill -x Omnicast || true
sleep 0.5
open .build-app/Omnicast.app
sleep 2
swift - <<'SWIFT'
import Foundation
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.omnicast.open"), object: nil, userInfo: nil, deliverImmediately: true)
SWIFT
sleep 1.5
screencapture -x "$out"
echo "wrote $out"
