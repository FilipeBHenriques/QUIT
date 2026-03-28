#!/bin/bash
# ============================================================
# QUIT App — Doze Survival Test (5 minutes, no force-stop)
#
# Prerequisites:
#   flutter build apk --release
#   adb install build/app/outputs/flutter-apk/app-release.apk
#   Open the app, block Instagram, close the app, then run this.
# ============================================================

ADB="/c/Users/USER/AppData/Local/Android/Sdk/platform-tools/adb.exe"
PACKAGE="com.example.quit"
INSTAGRAM="com.instagram.android"

GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

adb() { "$ADB" "$@"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   QUIT — Doze Survival Test              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check device connected
DEVICE=$(adb devices | grep -v "List of" | grep "device$" | awk '{print $1}' | head -1)
if [ -z "$DEVICE" ]; then
    echo -e "${RED}❌ No device connected.${NC}"; exit 1
fi
echo -e "${CYAN}📱 Device: $DEVICE${NC}"

# Check service is running
is_service_running() {
    adb shell dumpsys activity services "$PACKAGE" 2>/dev/null \
        | grep -q "ServiceRecord.*MonitoringService"
}

if ! is_service_running; then
    echo -e "${RED}❌ MonitoringService is NOT running.${NC}"
    echo "   Open the QUIT app, block an app, close QUIT, then re-run."
    exit 1
fi
echo -e "${GREEN}✅ MonitoringService running.${NC}"
echo ""

# ── Step 1: Enter Doze ───────────────────────────────────────
echo -e "${YELLOW}[1/4] Entering Doze mode (simulates phone idle/asleep)...${NC}"
adb shell dumpsys battery unplug &>/dev/null
adb shell dumpsys deviceidle force-idle deep &>/dev/null
sleep 3
echo -e "${CYAN}      $(adb shell dumpsys deviceidle 2>/dev/null | grep -i "mState=" | head -1)${NC}"

# ── Step 2: Wait 60 seconds in Doze ─────────────────────────
echo -e "${YELLOW}[2/4] Waiting 60s in Doze...${NC}"
for i in $(seq 60 -1 1); do
    printf "\r      ${CYAN}%2ds remaining...${NC}" $i
    sleep 1
done
echo ""

# ── Step 3: Check service still alive ────────────────────────
echo -e "${YELLOW}[3/4] Checking service...${NC}"
if is_service_running; then
    echo -e "${GREEN}      ✅ MonitoringService still running after Doze.${NC}"
    SVC_OK=1
else
    echo -e "${RED}      ❌ MonitoringService DIED during Doze.${NC}"
    SVC_OK=0
fi

# ── Step 4: Exit Doze and test blocking ──────────────────────
echo -e "${YELLOW}[4/4] Exiting Doze and testing Instagram block...${NC}"
adb shell dumpsys deviceidle unforce &>/dev/null
adb shell dumpsys battery reset &>/dev/null
sleep 2

# Launch Instagram
adb shell monkey -p "$INSTAGRAM" -c android.intent.category.LAUNCHER 1 &>/dev/null
sleep 3

# Check what's on screen — should be QUIT blocking screen, not Instagram
FOREGROUND=$(adb shell dumpsys activity activities 2>/dev/null \
    | grep "mResumedActivity" | head -1)

echo -e "${CYAN}      Foreground: $FOREGROUND${NC}"

if echo "$FOREGROUND" | grep -q "$PACKAGE"; then
    BLOCK_OK=1
    echo -e "${GREEN}      ✅ QUIT is in foreground — Instagram was blocked!${NC}"
elif echo "$FOREGROUND" | grep -q "$INSTAGRAM"; then
    BLOCK_OK=0
    echo -e "${RED}      ❌ Instagram is in foreground — blocking FAILED.${NC}"
else
    BLOCK_OK=0
    echo -e "${YELLOW}      ⚠️  Unknown foreground app — check manually.${NC}"
fi

# ── Results ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}════════════════ Results ════════════════${NC}"
[ $SVC_OK -eq 1 ] && echo -e "${GREEN}  Service: SURVIVED Doze ✅${NC}" || echo -e "${RED}  Service: DIED in Doze ❌${NC}"
[ $BLOCK_OK -eq 1 ] && echo -e "${GREEN}  Blocking: WORKS after Doze ✅${NC}" || echo -e "${RED}  Blocking: BROKEN after Doze ❌${NC}"
echo ""

if [ $SVC_OK -eq 1 ] && [ $BLOCK_OK -eq 1 ]; then
    echo -e "${GREEN}🎉 PASSED — app will block overnight.${NC}"
elif [ $SVC_OK -eq 1 ] && [ $BLOCK_OK -eq 0 ]; then
    echo -e "${RED}❌ Service alive but blocking broken — SharedPreferences read failing.${NC}"
    echo "   Check: adb logcat -s MonitoringService:D | grep '📦'"
elif [ $SVC_OK -eq 0 ]; then
    echo -e "${RED}❌ Service died — exempt from battery optimization in Settings.${NC}"
    echo "   Settings → Apps → QUIT → Battery → Unrestricted"
fi

# Show relevant logs
echo ""
echo -e "${YELLOW}Recent logs:${NC}"
adb logcat -d -s MonitoringService:D ServiceWatchdog:D 2>/dev/null | tail -20
echo ""
