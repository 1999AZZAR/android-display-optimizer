#!/bin/bash

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Global variable for selected device
SELECTED_DEVICE=""

# Function to check and select device
check_and_select_device() {
    echo -e "${BLUE}Checking for connected devices...${RESET}"

    # Get list of devices
    DEVICE_LIST=($(adb devices | grep -v "List" | grep -v "^$" | awk '{print $1}'))
    DEVICE_COUNT=${#DEVICE_LIST[@]}

    if [ $DEVICE_COUNT -eq 0 ]; then
        echo -e "${RED}No devices connected. Please connect a device and try again.${RESET}"
        exit 1
    elif [ $DEVICE_COUNT -eq 1 ]; then
        SELECTED_DEVICE=${DEVICE_LIST[0]}
        echo -e "${GREEN}✓ Using device: $SELECTED_DEVICE${RESET}"
    else
        echo -e "${YELLOW}Multiple devices found:${RESET}"
        for i in "${!DEVICE_LIST[@]}"; do
            DEVICE=${DEVICE_LIST[$i]}
            MODEL=$(adb -s $DEVICE shell getprop ro.product.model 2>/dev/null | tr -d '\r')
            echo -e "  ${BOLD}$((i + 1))${RESET}. $DEVICE ${YELLOW}($MODEL)${RESET}"
        done

        while true; do
            echo -ne "${BOLD}Select device (1-$DEVICE_COUNT): ${RESET}"
            read selection

            if [[ $selection =~ ^[0-9]+$ ]] && [ $selection -ge 1 ] && [ $selection -le $DEVICE_COUNT ]; then
                SELECTED_DEVICE=${DEVICE_LIST[$((selection - 1))]}
                echo -e "${GREEN}✓ Selected device: $SELECTED_DEVICE${RESET}"
                break
            else
                echo -e "${RED}Invalid selection. Please try again.${RESET}"
            fi
        done
    fi
    echo
}

# Function to run ADB command on selected device
run_adb() {
    adb -s $SELECTED_DEVICE $@
}

# Function to get current animation settings
get_animation_settings() {
    echo -e "${BOLD}Current Animation Settings:${RESET}"
    echo -e "Window animation scale: ${GREEN}$(run_adb shell settings get global window_animation_scale)${RESET}"
    echo -e "Transition animation scale: ${GREEN}$(run_adb shell settings get global transition_animation_scale)${RESET}"
    echo -e "Animator duration scale: ${GREEN}$(run_adb shell settings get global animator_duration_scale)${RESET}"
    echo
}

# Function to get DPI information
get_dpi_info() {
    CURRENT_DPI=$(run_adb shell wm density | grep -oE '[0-9]+' | head -1)
    DEFAULT_DPI=$(run_adb shell getprop ro.sf.lcd_density)

    echo -e "${BOLD}DPI Information:${RESET}"
    echo -e "Current DPI: ${GREEN}$CURRENT_DPI${RESET}"
    echo -e "Default DPI: ${GREEN}$DEFAULT_DPI${RESET}"
    echo
}

# Function to get hardware acceleration status
get_hw_acceleration_status() {
    # Check different hardware acceleration settings
    HW_ACCEL_GENERAL=$(run_adb shell getprop debug.hwui.render_dirty_regions 2>/dev/null | tr -d '\r')
    HW_ACCEL_GPU=$(run_adb shell getprop ro.config.hw_quickpoweron 2>/dev/null | tr -d '\r')
    HW_GPU_FORCE=$(run_adb shell settings get global force_gpu_rendering 2>/dev/null | tr -d '\r')
    HW_ACCEL_UI=$(run_adb shell getprop persist.sys.ui.hw 2>/dev/null | tr -d '\r')
    HW_ACCEL_DEVELOPER=$(run_adb shell settings get global hardware_accelerated_rendering 2>/dev/null | tr -d '\r')
    HW_GPU_USE=$(run_adb shell getprop debug.egl.hw 2>/dev/null | tr -d '\r')
    HW_GPU_PROFILER=$(run_adb shell getprop debug.egl.profiler 2>/dev/null | tr -d '\r')
    HW_OPENGL_TRACES=$(run_adb shell getprop debug.egl.trace 2>/dev/null | tr -d '\r')

    echo -e "${BOLD}Hardware Acceleration Status:${RESET}"
    echo -e "HW Rendering: ${GREEN}${HW_ACCEL_GENERAL:-"Not set"}${RESET}"
    echo -e "GPU Acceleration: ${GREEN}${HW_ACCEL_GPU:-"Not set"}${RESET}"
    echo -e "Force GPU Rendering: ${GREEN}${HW_GPU_FORCE:-"Not set"}${RESET}"
    echo -e "UI Hardware Acceleration: ${GREEN}${HW_ACCEL_UI:-"Not set"}${RESET}"
    echo -e "Developer Settings HW Accel: ${GREEN}${HW_ACCEL_DEVELOPER:-"Not set"}${RESET}"
    echo -e "GPU Usage: ${GREEN}${HW_GPU_USE:-"Not set"}${RESET}"
    echo -e "GPU Profiler: ${GREEN}${HW_GPU_PROFILER:-"Not set"}${RESET}"
    echo -e "OpenGL Traces: ${GREEN}${HW_OPENGL_TRACES:-"Not set"}${RESET}"
    echo
}

# Function to get device information
get_device_info() {
    echo -e "${BOLD}Device Information:${RESET}"
    echo -e "Device ID: ${GREEN}$SELECTED_DEVICE${RESET}"
    echo -e "Device Model: ${GREEN}$(run_adb shell getprop ro.product.model)${RESET}"
    echo -e "Android Version: ${GREEN}$(run_adb shell getprop ro.build.version.release)${RESET}"
    echo -e "SDK Version: ${GREEN}$(run_adb shell getprop ro.build.version.sdk)${RESET}"
    echo -e "Screen Resolution: ${GREEN}$(run_adb shell wm size)${RESET}"

    get_hw_acceleration_status
}

# Function to set animation scales
set_animation_scale() {
    SCALE=$1
    echo -e "${BLUE}Setting all animation scales to ${SCALE}x${RESET}"
    run_adb shell settings put global window_animation_scale $SCALE
    run_adb shell settings put global transition_animation_scale $SCALE
    run_adb shell settings put global animator_duration_scale $SCALE
    echo -e "${GREEN}✓ Animation scales set to ${SCALE}x${RESET}"
    echo
}

# Function to set custom DPI
set_custom_dpi() {
    NEW_DPI=$1
    echo -e "${BLUE}Setting device DPI to $NEW_DPI${RESET}"
    run_adb shell wm density $NEW_DPI
    echo -e "${GREEN}✓ DPI set to $NEW_DPI${RESET}"
    echo -e "${BOLD}Note: You may need to restart your device for changes to take full effect${RESET}"
    echo
}

# Function to reset DPI to default
reset_dpi() {
    echo -e "${BLUE}Resetting DPI to device default${RESET}"
    run_adb shell wm density reset
    echo -e "${GREEN}✓ DPI reset to default${RESET}"
    echo -e "${BOLD}Note: You may need to restart your device for changes to take full effect${RESET}"
    echo
}

# Function to enable all hardware acceleration
enable_all_hw_acceleration() {
    echo -e "${BLUE}Enabling all hardware acceleration features...${RESET}"

    # Set properties that control hardware acceleration
    run_adb shell setprop debug.hwui.render_dirty_regions true
    run_adb shell setprop persist.sys.ui.hw 1
    run_adb shell settings put global hardware_accelerated_rendering 1
    run_adb shell settings put global force_gpu_rendering 1
    run_adb shell setprop debug.egl.hw 1
    run_adb shell setprop ro.config.hw_quickpoweron 1

    echo -e "${GREEN}✓ All hardware acceleration features enabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to enable only GPU acceleration
enable_gpu_acceleration() {
    echo -e "${BLUE}Enabling GPU acceleration...${RESET}"

    # Set GPU-specific properties
    run_adb shell settings put global force_gpu_rendering 1
    run_adb shell setprop debug.egl.hw 1
    run_adb shell setprop ro.config.hw_quickpoweron 1

    echo -e "${GREEN}✓ GPU acceleration enabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to enable only UI hardware acceleration
enable_ui_hw_acceleration() {
    echo -e "${BLUE}Enabling UI hardware acceleration...${RESET}"

    # Set UI-specific properties
    run_adb shell setprop persist.sys.ui.hw 1
    run_adb shell setprop debug.hwui.render_dirty_regions true

    echo -e "${GREEN}✓ UI hardware acceleration enabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to disable all hardware acceleration
disable_all_hw_acceleration() {
    echo -e "${BLUE}Disabling all hardware acceleration features...${RESET}"

    # Disable hardware acceleration properties
    run_adb shell setprop debug.hwui.render_dirty_regions false
    run_adb shell setprop persist.sys.ui.hw 0
    run_adb shell settings put global hardware_accelerated_rendering 0
    run_adb shell settings put global force_gpu_rendering 0
    run_adb shell setprop debug.egl.hw 0
    run_adb shell setprop ro.config.hw_quickpoweron 0

    echo -e "${GREEN}✓ All hardware acceleration features disabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to disable only GPU acceleration
disable_gpu_acceleration() {
    echo -e "${BLUE}Disabling GPU acceleration...${RESET}"

    # Disable GPU-specific properties
    run_adb shell settings put global force_gpu_rendering 0
    run_adb shell setprop debug.egl.hw 0
    run_adb shell setprop ro.config.hw_quickpoweron 0

    echo -e "${GREEN}✓ GPU acceleration disabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to disable only UI hardware acceleration
disable_ui_hw_acceleration() {
    echo -e "${BLUE}Disabling UI hardware acceleration...${RESET}"

    # Disable UI-specific properties
    run_adb shell setprop persist.sys.ui.hw 0
    run_adb shell setprop debug.hwui.render_dirty_regions false

    echo -e "${GREEN}✓ UI hardware acceleration disabled${RESET}"
    echo -e "${BOLD}Note: Some changes may require device restart to take full effect${RESET}"
    echo
}

# Function to reset hardware acceleration to device defaults
reset_hw_acceleration() {
    echo -e "${BLUE}Resetting hardware acceleration to device defaults...${RESET}"

    # Remove any custom property settings
    run_adb shell setprop debug.hwui.render_dirty_regions ""
    run_adb shell setprop persist.sys.ui.hw ""
    run_adb shell settings delete global hardware_accelerated_rendering
    run_adb shell settings delete global force_gpu_rendering
    run_adb shell setprop debug.egl.hw ""
    run_adb shell setprop ro.config.hw_quickpoweron ""

    echo -e "${GREEN}✓ Hardware acceleration reset to system defaults${RESET}"
    echo -e "${BOLD}Note: A device restart is recommended for changes to take full effect${RESET}"
    echo
}

# Function to reboot device
reboot_device() {
    echo -e "${YELLOW}Rebooting device $SELECTED_DEVICE...${RESET}"
    run_adb reboot
    echo -e "${GREEN}✓ Reboot command sent${RESET}"
    echo -e "${BOLD}Device is now restarting...${RESET}"
    echo -e "${BLUE}Please wait for the device to reconnect before continuing${RESET}"
    echo
    echo -e "${YELLOW}Would you like to wait for the device to reconnect? (y/n)${RESET}"
    read wait_response

    if [[ "$wait_response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Waiting for device to reconnect...${RESET}"
        adb -s $SELECTED_DEVICE wait-for-device
        echo -e "${GREEN}✓ Device reconnected!${RESET}"
    else
        echo -e "${YELLOW}You'll need to restart this script after your device has rebooted${RESET}"
        exit 0
    fi
}

# Function to change device
change_device() {
    check_and_select_device
}

# Display menu
show_menu() {
    clear
    echo -e "${BOLD}╔═════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Android Display & Performance Optimizer    ║${RESET}"
    echo -e "${BOLD}╚═════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BOLD}SELECTED DEVICE:${RESET} ${GREEN}$SELECTED_DEVICE${RESET} ($(run_adb shell getprop ro.product.model | tr -d '\r'))"
    echo -e "${YELLOW}c. Change device${RESET}     ${RED}r. Reboot device${RESET}"
    echo
    echo -e "${BOLD}INFORMATION:${RESET}"
    echo -e "  1. Show animation settings"
    echo -e "  2. Show current DPI information"
    echo -e "  3. Show device information"
    echo -e "  4. Show hardware acceleration status"
    echo
    echo -e "${BOLD}ANIMATION SETTINGS:${RESET}"
    echo -e "  5. Set animation scales to 1.0x (default)"
    echo -e "  6. Set animation scales to 0.90x"
    echo -e "  7. Set animation scales to 0.75x"
    echo -e "  8. Set animation scales to custom value"
    echo -e "  9. Turn off animations (0.0x)"
    echo
    echo -e "${BOLD}DPI SETTINGS:${RESET}"
    echo -e " 10. Set custom DPI"
    echo -e " 11. Reset DPI to default"
    echo
    echo -e "${BOLD}HARDWARE ACCELERATION:${RESET}"
    echo -e " 12. Enable all hardware acceleration features"
    echo -e " 13. Enable GPU acceleration only"
    echo -e " 14. Enable UI hardware acceleration only"
    echo -e " 15. Disable all hardware acceleration features"
    echo -e " 16. Disable GPU acceleration only"
    echo -e " 17. Disable UI hardware acceleration only"
    echo -e " 18. Reset hardware acceleration to device defaults"
    echo
    echo -e "${BOLD}OTHER:${RESET}"
    echo -e "  0. Exit"
    echo
    echo -e "${BOLD}Select an option: ${RESET}"
}

# Function to wait for user confirmation
wait_for_enter() {
    echo -e "Press Enter to continue"
    read
}

# Main program
check_and_select_device

# Main loop
while true; do
    show_menu
    read choice

    case $choice in
    0)
        echo -e "${GREEN}Exiting...${RESET}"
        exit 0
        ;;
    c | C)
        change_device
        ;;
    r | R)
        reboot_device
        wait_for_enter
        ;;
    1)
        get_animation_settings
        wait_for_enter
        ;;
    2)
        get_dpi_info
        wait_for_enter
        ;;
    3)
        get_device_info
        wait_for_enter
        ;;
    4)
        get_hw_acceleration_status
        wait_for_enter
        ;;
    5)
        set_animation_scale 1.0
        wait_for_enter
        ;;
    6)
        set_animation_scale 0.90
        wait_for_enter
        ;;
    7)
        set_animation_scale 0.75
        wait_for_enter
        ;;
    8)
        echo -n -e "${BOLD}Enter custom scale (e.g., 0.5): ${RESET}"
        read custom_scale
        set_animation_scale $custom_scale
        wait_for_enter
        ;;
    9)
        set_animation_scale 0.0
        echo -e "${GREEN}✓ Animations turned off (0.0x)${RESET}"
        wait_for_enter
        ;;
    10)
        get_dpi_info
        echo -n -e "${BOLD}Enter new DPI value: ${RESET}"
        read new_dpi
        set_custom_dpi $new_dpi
        wait_for_enter
        ;;
    11)
        reset_dpi
        wait_for_enter
        ;;
    12)
        enable_all_hw_acceleration
        wait_for_enter
        ;;
    13)
        enable_gpu_acceleration
        wait_for_enter
        ;;
    14)
        enable_ui_hw_acceleration
        wait_for_enter
        ;;
    15)
        disable_all_hw_acceleration
        wait_for_enter
        ;;
    16)
        disable_gpu_acceleration
        wait_for_enter
        ;;
    17)
        disable_ui_hw_acceleration
        wait_for_enter
        ;;
    18)
        reset_hw_acceleration
        wait_for_enter
        ;;
    *)
        echo -e "${RED}Invalid option. Please try again.${RESET}"
        sleep 2
        ;;
    esac
done
