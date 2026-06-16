#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Spinner helper function
spin() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  # Hide cursor
  tput civis
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf "${BLUE}[%c]${NC} Processing..." "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
  done
  # Clear line and restore cursor
  printf "                 \b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
  tput cnorm
}

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}        openFitness iOS Deployment Script          ${NC}"
echo -e "${BLUE}===================================================${NC}"
echo ""
echo -e "${YELLOW}Please ensure you have completed the following prerequisites:${NC}"
echo -e " 1. Connect your physical iPhone to this Mac via USB or Wi-Fi (same network)."
echo -e " 2. Unlock your iPhone screen."
echo -e " 3. Enable Developer Mode on your iPhone:"
echo -e "    Go to ${GREEN}Settings > Privacy & Security > Developer Mode${NC} and turn it ON."
echo -e " 4. Ensure your Mac is trusted by the device."
echo -e " 5. If this is the first deployment using a free Personal Developer Team account,"
echo -e "    you will need to trust the certificate after installation under:"
echo -e "    ${GREEN}Settings > General > VPN & Device Management${NC}"
echo ""

# Ask for confirmation
read -p "Have you met all these prerequisites? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborting deployment. Please complete the prerequisites and run the script again.${NC}"
    exit 1
fi

echo ""
printf "Detecting connected physical iPhone... "

# Set the active developer directory to the Xcode application path
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

# Run xcdevice list in background and show spinner
xcrun xcdevice list > devices.json 2>&1 &
DETECT_PID=$!
spin $DETECT_PID
wait $DETECT_PID

# Parse the device list with Python to find the first physical iPhone
DEVICE_INFO=$(python3 -c "
import sys, json
try:
    with open('devices.json') as f:
        devices = json.load(f)
    iphones = [d for d in devices if d.get('platform') == 'com.apple.platform.iphoneos' and not d.get('simulator') and d.get('available')]
    if iphones:
        iphone = iphones[0]
        print(f\"{iphone['name']}|{iphone['identifier']}\")
    else:
        print(\"NONE\")
except Exception as e:
    print(f\"ERROR: {str(e)}\")
")
rm -f devices.json

if [[ "$DEVICE_INFO" == "NONE" ]]; then
    echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b${RED}Failed!${NC}"
    echo -e "${RED}Error: No connected physical iPhone detected.${NC}"
    echo -e "Please connect your iPhone via USB, unlock it, and try again."
    exit 1
elif [[ "$DEVICE_INFO" == ERROR* ]]; then
    echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b${RED}Failed!${NC}"
    echo -e "${RED}Error detecting devices: $DEVICE_INFO${NC}"
    exit 1
fi

# Split name and UDID
DEVICE_NAME=$(echo "$DEVICE_INFO" | cut -d'|' -f1)
DEVICE_UDID=$(echo "$DEVICE_INFO" | cut -d'|' -f2)

echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b${GREEN}Done!${NC}"
echo -e "${GREEN}Target Device:${NC} $DEVICE_NAME ($DEVICE_UDID)"
echo ""

# Build phase
printf "Cleaning and compiling openFitness app... "
xcodebuild clean build \
  -project openFitness.xcodeproj \
  -scheme openFitness \
  -destination "id=$DEVICE_UDID" \
  -configuration Debug \
  -derivedDataPath ./build > build.log 2>&1 &
BUILD_PID=$!
spin $BUILD_PID
wait $BUILD_PID
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b${RED}Failed!${NC}"
  echo -e "${RED}Build failed! Here are the last few lines of the build log:${NC}"
  tail -n 20 build.log
  echo -e "${RED}Full log available at: ./build.log${NC}"
  exit $EXIT_CODE
else
  rm -f build.log
  echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b${GREEN}Done!${NC}"
fi

# Install phase
printf "Installing app on $DEVICE_NAME... "
xcrun devicectl device install app --device "$DEVICE_UDID" "./build/Build/Products/Debug-iphoneos/openFitness.app" > install.log 2>&1 &
INSTALL_PID=$!
spin $INSTALL_PID
wait $INSTALL_PID
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b${RED}Failed!${NC}"
  echo -e "${RED}Installation failed! Here is the installation log:${NC}"
  cat install.log
  exit $EXIT_CODE
else
  rm -f install.log
  echo -e "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b${GREEN}Done!${NC}"
fi

echo ""
echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}  SUCCESS: openFitness deployed to $DEVICE_NAME!    ${NC}"
echo -e "${GREEN}===================================================${NC}"
echo -e "If this is a new profile, remember to trust it under:"
echo -e "Settings > General > VPN & Device Management"
