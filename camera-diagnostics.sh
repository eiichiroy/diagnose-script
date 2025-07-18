#!/bin/bash

# Camera diagnostic script
# This script runs various diagnostics for Pi camera issues and saves all outputs to log files

# Colors for better terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Create directory for logs and snapshots
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="./logs"
SNAP_DIR="./snapshots"
mkdir -p "$LOG_DIR" "$SNAP_DIR"

# Define log files
MAIN_LOG="$LOG_DIR/camera_diagnostic_$TIMESTAMP.log"
OUTPUT_LOG="$LOG_DIR/output_$TIMESTAMP.log"

# Log both to file and stdout
log() {
    echo -e "$1" | tee -a "$MAIN_LOG"
}

# Log command execution
log_cmd() {
    local cmd="$1"
    local separator="====================================================="
    
    # Log command execution
    log "\n$separator"
    log "${BOLD}${BLUE}EXECUTING: $cmd${NC}"
    log "$separator\n"
    
    # Execute command and capture output
    echo -e "\n$separator\nCOMMAND: $cmd\n$separator\n" >> "$OUTPUT_LOG"
    
    # Run command, tee output to log file and capture exit status
    eval "$cmd" 2>&1 | tee -a "$OUTPUT_LOG" | while IFS= read -r line; do
        log "  | $line"
    done
    
    return ${PIPESTATUS[0]}  # Return the exit status of the command
}

# Check if v4l2-ctl is installed
check_v4l2() {
    if ! command -v v4l2-ctl &> /dev/null; then
        log "${RED}v4l2-ctl not found. Please install it with: sudo apt install v4l-utils${NC}"
        exit 1
    fi
    log "${GREEN}v4l2-ctl is installed.${NC}"
}

# Main script execution
log "${BOLD}Starting Camera Diagnostic at $(date)${NC}"
log "Logs will be saved to: $LOG_DIR"

# Check for required tools
check_v4l2

# List video devices
log "\n${YELLOW}Checking for video devices...${NC}"
log_cmd "ls -la /dev/video*"

# Get device info
log "\n${YELLOW}Getting v4l2 device info...${NC}"
log_cmd "v4l2-ctl --device /dev/video0 --all"

# Check USB tree
log "\n${YELLOW}Checking USB topology...${NC}"
log_cmd "lsusb -t"

# List available formats
log "\n${YELLOW}Listing available formats...${NC}"
log_cmd "v4l2-ctl -d /dev/video0 --list-formats-ext"

# Get v4l2 info
log "\n${YELLOW}Getting v4l2 info...${NC}"
log_cmd "v4l2-ctl -info"
log_cmd "v4l2-ctl --info"

# Capture HD image
log "\n${YELLOW}Capturing HD image with v4l2-ctl...${NC}"
SNAP_FILE="$SNAP_DIR/snap_$TIMESTAMP.jpg"

# Execute the capture command directly instead of using log_cmd function
log "${BOLD}${BLUE}EXECUTING: v4l2-ctl --device /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=MJPG --stream-mmap --stream-to=$SNAP_FILE --stream-count=1${NC}"
echo "\n=========================================================\nCOMMAND: v4l2-ctl capture\n=========================================================" >> "$OUTPUT_LOG"

# Direct execution without eval or pipes
v4l2-ctl --device /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=MJPG --stream-mmap --stream-to="$SNAP_FILE" --stream-count=1 2>&1 | tee -a "$OUTPUT_LOG"

# Check if capture was successful
if [ -f "$SNAP_FILE" ]; then
    FILE_SIZE=$(du -h "$SNAP_FILE" | cut -f1)
    log "${GREEN}✅ Successfully captured HD image to $SNAP_FILE (Size: $FILE_SIZE)${NC}"
else
    log "${RED}❌ Failed to capture HD image${NC}"
fi

# Collect system logs related to camera/video
log "\n${YELLOW}Collecting system logs related to camera and video...${NC}"

# Kernel messages related to camera/video
log "\n${YELLOW}Recent kernel messages related to camera/video...${NC}"
log_cmd "dmesg | grep -i -E 'camera|video|v4l|uvc|usb.*cam' | tail -n 50"

# Journal logs related to camera
if command -v journalctl &> /dev/null; then
    log "\n${YELLOW}Recent systemd journal entries related to camera...${NC}"
    log_cmd "journalctl -b | grep -i -E 'camera|video|v4l|uvc|usb.*cam' | tail -n 50"
fi

# Check loaded modules related to camera
log "\n${YELLOW}Loaded kernel modules related to camera...${NC}"
log_cmd "lsmod | grep -i -E 'video|camera|uvc|v4l'"

# Check camera device permissions
log "\n${YELLOW}Camera device permissions...${NC}"
log_cmd "ls -la /dev/video*"

# Check kernel config for camera support
if [ -f "/boot/config-$(uname -r)" ]; then
    log "\n${YELLOW}Kernel config related to camera support...${NC}"
    log_cmd "grep -i 'V4L\|CAMERA\|UVC' /boot/config-$(uname -r)"
fi

# Hardware information
log "\n${YELLOW}Hardware information...${NC}"
log_cmd "cat /proc/cpuinfo | grep Model"
log_cmd "cat /etc/os-release"

# Pi specific: Check if camera is enabled in config.txt
if [ -f "/boot/config.txt" ]; then
    log "\n${YELLOW}Checking Raspberry Pi camera settings...${NC}"
    log_cmd "grep -i 'camera\|start_x' /boot/config.txt"
fi

# Complete
log "\n${GREEN}Camera Diagnostic completed at $(date)${NC}"
log "Log files saved to: $LOG_DIR"
log "Snapshot (if successful) saved to: $SNAP_DIR"

chmod +x "$0"  # Make sure the script is executable
