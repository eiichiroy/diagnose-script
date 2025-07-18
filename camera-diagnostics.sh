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

# Define camera device
CAMERA_DEVICE="/dev/video0"

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

# Define simple arrays for commands and descriptions
# Format: description followed by command
DESC_VIDEO="Video devices"; CMD_VIDEO="ls -la /dev/video*"
DESC_INFO="Device info"; CMD_INFO="v4l2-ctl --device $CAMERA_DEVICE --all"
DESC_USB="USB topology"; CMD_USB="lsusb -t"
DESC_FORMATS="Available formats"; CMD_FORMATS="v4l2-ctl -d $CAMERA_DEVICE --list-formats-ext"
DESC_V4L_1="v4l2 info (1)"; CMD_V4L_1="v4l2-ctl -info"
DESC_V4L_2="v4l2 info (2)"; CMD_V4L_2="v4l2-ctl --info"

# System log commands
DESC_DMESG="Kernel messages"; CMD_DMESG="dmesg | grep -i -E 'camera|video|v4l|uvc|usb.*cam' | tail -n 50"
DESC_MODULES="Loaded modules"; CMD_MODULES="lsmod | grep -i -E 'video|camera|uvc|v4l'"
DESC_PERMS="Camera permissions"; CMD_PERMS="ls -la /dev/video*"
DESC_HW="Hardware info"; CMD_HW="cat /proc/cpuinfo | grep Model"
DESC_OS="OS release"; CMD_OS="cat /etc/os-release"

# Conditional commands
DESC_JOURNAL="Systemd journal entries"; CMD_JOURNAL="journalctl -b | grep -i -E 'camera|video|v4l|uvc|usb.*cam' | tail -n 50"
DESC_KERNEL="Kernel config"; CMD_KERNEL="grep -i 'V4L\|CAMERA\|UVC' /boot/config-$(uname -r)"
DESC_CONFIG="Pi camera settings"; CMD_CONFIG="grep -i 'camera\|start_x' /boot/config.txt"

# Main script execution
log "${BOLD}Starting Camera Diagnostic at $(date)${NC}"
log "Logs will be saved to: $LOG_DIR"

# Check for required tools
check_v4l2

# Run all diagnostic commands
log "\n${BOLD}${YELLOW}Running Basic Camera Diagnostics${NC}"

# Video devices
log "\n${YELLOW}Checking $DESC_VIDEO...${NC}"
log_cmd "$CMD_VIDEO"

# Device info
log "\n${YELLOW}Checking $DESC_INFO...${NC}"
log_cmd "$CMD_INFO"

# USB topology
log "\n${YELLOW}Checking $DESC_USB...${NC}"
log_cmd "$CMD_USB"

# Available formats
log "\n${YELLOW}Checking $DESC_FORMATS...${NC}"
log_cmd "$CMD_FORMATS"

# v4l2 info commands
log "\n${YELLOW}Checking $DESC_V4L_1...${NC}"
log_cmd "$CMD_V4L_1"

log "\n${YELLOW}Checking $DESC_V4L_2...${NC}"
log_cmd "$CMD_V4L_2"

# Capture HD image - direct execution without going through log_cmd
log "\n${BOLD}${YELLOW}Capturing HD Image${NC}"
SNAP_FILE="$SNAP_DIR/snap_$TIMESTAMP.jpg"

# Execute the capture command directly
log "${BOLD}${BLUE}EXECUTING: v4l2-ctl --device $CAMERA_DEVICE --set-fmt-video=width=1920,height=1080,pixelformat=MJPG --stream-mmap --stream-to=$SNAP_FILE --stream-count=1${NC}"
echo "\n=========================================================\nCOMMAND: v4l2-ctl capture\n=========================================================" >> "$OUTPUT_LOG"

# Direct execution without eval or pipes for image capture
v4l2-ctl --device $CAMERA_DEVICE --set-fmt-video=width=1920,height=1080,pixelformat=MJPG --stream-mmap --stream-to="$SNAP_FILE" --stream-count=1 2>&1 | tee -a "$OUTPUT_LOG"

# Check if capture was successful
if [ -f "$SNAP_FILE" ]; then
    FILE_SIZE=$(du -h "$SNAP_FILE" | cut -f1)
    log "${GREEN}✅ Successfully captured HD image to $SNAP_FILE (Size: $FILE_SIZE)${NC}"
else
    log "${RED}❌ Failed to capture HD image${NC}"
fi

# Run system log commands
log "\n${BOLD}${YELLOW}Collecting System Logs${NC}"

# Kernel messages
log "\n${YELLOW}Getting $DESC_DMESG...${NC}"
log_cmd "$CMD_DMESG"

# Loaded modules
log "\n${YELLOW}Getting $DESC_MODULES...${NC}"
log_cmd "$CMD_MODULES"

# Camera permissions
log "\n${YELLOW}Getting $DESC_PERMS...${NC}"
log_cmd "$CMD_PERMS"

# Hardware info
log "\n${YELLOW}Getting $DESC_HW...${NC}"
log_cmd "$CMD_HW"

# OS release
log "\n${YELLOW}Getting $DESC_OS...${NC}"
log_cmd "$CMD_OS"

# Run conditional commands
log "\n${BOLD}${YELLOW}Running Conditional Diagnostics${NC}"

# Check for journalctl
if command -v journalctl &> /dev/null; then
    log "\n${YELLOW}Checking $DESC_JOURNAL...${NC}"
    log_cmd "$CMD_JOURNAL"
fi

# Check for kernel config
if [ -f "/boot/config-$(uname -r)" ]; then
    log "\n${YELLOW}Checking $DESC_KERNEL...${NC}"
    log_cmd "$CMD_KERNEL"
fi

# Check for Pi config
if [ -f "/boot/config.txt" ]; then
    log "\n${YELLOW}Checking $DESC_CONFIG...${NC}"
    log_cmd "$CMD_CONFIG"
fi

# Complete
log "\n${GREEN}Camera Diagnostic completed at $(date)${NC}"
log "Log files saved to: $LOG_DIR"
log "Snapshot (if successful) saved to: $SNAP_DIR"
