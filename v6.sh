#!/usr/bin/env bash
set -euo pipefail
if ! command -v adb >/dev/null 2>&1; then
    echo -e "\033[0;31mADB is required but not installed. Please install ADB and ensure it's in your PATH.\033[0m"
    exit 1
fi

# Global variable for selected device
SELECTED_DEVICE=""

# Default color definitions (can be overridden by config.ini)
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# --- Function Definitions ---

run_adb() {
    adb -s $SELECTED_DEVICE $@
}

check_and_select_device() {
    echo -e "${BLUE}Checking for connected devices...${RESET}"
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

create_config_if_missing() {
    CONFIG_FILE="config.ini"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Configuration file not found. Creating a default config.ini...${RESET}"
        {
            echo "[AnimationScales]"
            echo "Default = 1.0"
            echo "Option1 = 0.9"
            echo "Option2 = 0.75"
            echo
            echo "[DPI]"
            echo "Default = 480"
            echo "Custom = 420"
            echo
            echo "[Colors]"
            echo "BOLD='\033[1m'"
            echo "GREEN='\033[0;32m'"
            echo "BLUE='\033[0;34m'"
            echo "YELLOW='\033[0;33m'"
            echo "RED='\033[0;31m'"
            echo "RESET='\033[0m'"
            echo
            echo "[Backup]"
            echo "Prefix = android_settings_"
        } > "$CONFIG_FILE"
        echo -e "${GREEN}✓ Default config.ini created. You can edit this file to change menu presets.${RESET}"
        echo
    fi
}

get_animation_settings() {
    echo -e "${BOLD}Current Animation Settings:${RESET}"
    echo -e "Window animation scale: ${GREEN}$(run_adb shell settings get global window_animation_scale)${RESET}"
    echo -e "Transition animation scale: ${GREEN}$(run_adb shell settings get global transition_animation_scale)${RESET}"
    echo -e "Animator duration scale: ${GREEN}$(run_adb shell settings get global animator_duration_scale)${RESET}"
}

get_dpi_info() {
    CURRENT_DPI=$(run_adb shell wm density | grep -oE '[0-9]+' | head -1)
    DEFAULT_DPI=$(run_adb shell getprop ro.sf.lcd_density)
    echo -e "${BOLD}DPI Information:${RESET}"
    echo -e "Current DPI: ${GREEN}$CURRENT_DPI${RESET}"
    echo -e "Default DPI: ${GREEN}$DEFAULT_DPI${RESET}"
}

get_hw_acceleration_status() {
    echo -e "${BOLD}Hardware Acceleration Status:${RESET}"
    echo -e "HW Rendering: ${GREEN}$(run_adb shell getprop debug.hwui.render_dirty_regions 2>/dev/null | tr -d '\r')${RESET}"
    echo -e "GPU Acceleration: ${GREEN}$(run_adb shell getprop ro.config.hw_quickpoweron 2>/dev/null | tr -d '\r')${RESET}"
    echo -e "Force GPU Rendering: ${GREEN}$(run_adb shell settings get global force_gpu_rendering 2>/dev/null | tr -d '\r')${RESET}"
    echo -e "UI Hardware Acceleration: ${GREEN}$(run_adb shell getprop persist.sys.ui.hw 2>/dev/null | tr -d '\r')${RESET}"
}

get_device_info() {
    echo -e "${BOLD}Device Information:${RESET}"
    echo -e "Device ID: ${GREEN}$SELECTED_DEVICE${RESET}"
    echo -e "Device Model: ${GREEN}$(run_adb shell getprop ro.product.model)${RESET}"
    echo -e "Android Version: ${GREEN}$(run_adb shell getprop ro.build.version.release)${RESET}"
    echo -e "SDK Version: ${GREEN}$(run_adb shell getprop ro.build.version.sdk)${RESET}"
    echo -e "Screen Resolution: ${GREEN}$(run_adb shell wm size)${RESET}"
}

get_rotation_settings() {
    ACCELEROMETER_ROTATION=$(run_adb shell settings get system accelerometer_rotation | tr -d '\r')
    USER_ROTATION=$(run_adb shell settings get system user_rotation | tr -d '\r')
    [ "$ACCELEROMETER_ROTATION" == "1" ] && ACCELEROMETER_ROTATION_STATUS="Enabled" || ACCELEROMETER_ROTATION_STATUS="Disabled"
    case "$USER_ROTATION" in
        "0") USER_ROTATION_VALUE="Portrait (0°)";;
        "1") USER_ROTATION_VALUE="Landscape (90°)";;
        "2") USER_ROTATION_VALUE="Upside down (180°)";;
        "3") USER_ROTATION_VALUE="Landscape reversed (270°)";;
        *) USER_ROTATION_VALUE="Unknown ($USER_ROTATION)";;
    esac
    echo -e "${BOLD}Current Rotation Settings:${RESET}"
    echo -e "Auto-Rotation: ${GREEN}$ACCELEROMETER_ROTATION_STATUS${RESET}"
    echo -e "Current Fixed Rotation: ${GREEN}$USER_ROTATION_VALUE${RESET}"
}

set_animation_scale() {
    SCALE=$1
    echo -e "${BLUE}Setting all animation scales to ${SCALE}x...${RESET}"
    run_adb shell settings put global window_animation_scale $SCALE
    run_adb shell settings put global transition_animation_scale $SCALE
    run_adb shell settings put global animator_duration_scale $SCALE
    echo -e "${GREEN}✓ Animation scales set to ${SCALE}x${RESET}"
}

set_custom_dpi() {
    get_dpi_info
    echo -n -e "${BOLD}Enter new DPI value: ${RESET}"
    read new_dpi
    if [[ "$new_dpi" =~ ^[0-9]+$ ]]; then
        echo -e "${BLUE}Setting device DPI to $new_dpi...${RESET}"
        run_adb shell wm density $new_dpi
        echo -e "${GREEN}✓ DPI set to $new_dpi${RESET}"
        echo -e "${BOLD}Note: You may need to restart your device for changes to take full effect${RESET}"
    else
        echo -e "${RED}Invalid DPI value. Please enter a number.${RESET}"
    fi
}

reset_dpi() {
    echo -e "${BLUE}Resetting DPI to device default...${RESET}"
    run_adb shell wm density reset
    echo -e "${GREEN}✓ DPI reset to default${RESET}"
    echo -e "${BOLD}Note: You may need to restart your device for changes to take full effect${RESET}"
}

enable_all_rotations() {
    echo -e "${BLUE}Enabling all screen rotations (including upside-down)...${RESET}"
    run_adb shell cmd window set-allowed-display-rotations 0,1,2,3
    echo -e "${GREEN}✓ All screen rotations enabled${RESET}"
}

disable_upside_down_rotation() {
    echo -e "${BLUE}Disabling upside-down rotation...${RESET}"
    run_adb shell cmd window set-allowed-display-rotations 0,1,3
    echo -e "${GREEN}✓ Upside-down rotation disabled${RESET}"
}

set_specific_rotation() {
    ROTATION=$1
    case "$ROTATION" in
        "0") ROTATION_NAME="Portrait (0°)";;
        "1") ROTATION_NAME="Landscape (90°)";;
        "2") ROTATION_NAME="Upside down (180°)";;
        "3") ROTATION_NAME="Landscape reversed (270°)";;
    esac
    echo -e "${BLUE}Setting rotation to ${ROTATION_NAME}...${RESET}"
    run_adb shell settings put system accelerometer_rotation 0
    run_adb shell settings put system user_rotation $ROTATION
    echo -e "${GREEN}✓ Rotation set to ${ROTATION_NAME}${RESET}"
}

toggle_auto_rotation() {
    CURRENT_AUTO_ROTATION=$(run_adb shell settings get system accelerometer_rotation | tr -d '\r')
    if [ "$CURRENT_AUTO_ROTATION" == "1" ]; then
        run_adb shell settings put system accelerometer_rotation 0
        echo -e "${GREEN}✓ Auto-rotation disabled${RESET}"
    else
        run_adb shell settings put system accelerometer_rotation 1
        echo -e "${GREEN}✓ Auto-rotation enabled${RESET}"
    fi
}

enable_all_hw_acceleration() {
    echo -e "${BLUE}Enabling all hardware acceleration features...${RESET}"
    run_adb shell setprop debug.hwui.render_dirty_regions true
    run_adb shell setprop persist.sys.ui.hw 1
    run_adb shell settings put global force_gpu_rendering 1
    echo -e "${GREEN}✓ All hardware acceleration features enabled${RESET}"
    echo -e "${BOLD}Note: A device restart is recommended for changes to take full effect${RESET}"
}

disable_all_hw_acceleration() {
    echo -e "${BLUE}Disabling all hardware acceleration features...${RESET}"
    run_adb shell setprop debug.hwui.render_dirty_regions false
    run_adb shell setprop persist.sys.ui.hw 0
    run_adb shell settings put global force_gpu_rendering 0
    echo -e "${GREEN}✓ All hardware acceleration features disabled${RESET}"
    echo -e "${BOLD}Note: A device restart is recommended for changes to take full effect${RESET}"
}

reset_hw_acceleration() {
    echo -e "${BLUE}Resetting hardware acceleration to device defaults...${RESET}"
    run_adb shell setprop debug.hwui.render_dirty_regions ""
    run_adb shell setprop persist.sys.ui.hw ""
    run_adb shell settings delete global force_gpu_rendering
    run_adb shell setprop debug.hwui.profile false
    run_adb shell setprop debug.hwui.overdraw false
    echo -e "${GREEN}✓ Hardware acceleration reset to system defaults${RESET}"
    echo -e "${BOLD}Note: A device restart is recommended for changes to take full effect${RESET}"
}

toggle_gpu_profile() {
    CURRENT_STATUS=$(run_adb shell getprop debug.hwui.profile)
    if [[ "$CURRENT_STATUS" == "true" || "$CURRENT_STATUS" == "visual_bars" ]]; then
        run_adb shell setprop debug.hwui.profile false
        echo -e "${GREEN}✓ GPU Profile Rendering disabled${RESET}"
    else
        run_adb shell setprop debug.hwui.profile true
        echo -e "${GREEN}✓ GPU Profile Rendering enabled (bars on screen)${RESET}"
    fi
}

toggle_gpu_overdraw() {
    CURRENT_STATUS=$(run_adb shell getprop debug.hwui.overdraw)
    if [[ "$CURRENT_STATUS" == "true" || "$CURRENT_STATUS" == "show" ]]; then
        run_adb shell setprop debug.hwui.overdraw false
        echo -e "${GREEN}✓ GPU Overdraw Debugging disabled${RESET}"
    else
        run_adb shell setprop debug.hwui.overdraw true
        echo -e "${GREEN}✓ GPU Overdraw Debugging enabled (colors on screen)${RESET}"
    fi
}

reboot_device() {
    echo -e "${YELLOW}Rebooting device $SELECTED_DEVICE...${RESET}"
    run_adb reboot
    echo -e "${GREEN}✓ Reboot command sent${RESET}"
    echo -e "${BOLD}Device is now restarting...${RESET}"
    echo -e "${BLUE}Please wait for the device to reconnect before continuing${RESET}"
    echo -n -e "${YELLOW}Would you like to wait for the device to reconnect? (y/n) ${RESET}"
    read wait_response
    if [[ "$wait_response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Waiting for device to reconnect...${RESET}"
        run_adb wait-for-device
        echo -e "${GREEN}✓ Device reconnected!${RESET}"
    else
        echo -e "${YELLOW}Exiting. You'll need to restart this script after your device has rebooted.${RESET}"
        exit 0
    fi
}

backup_settings() {
    BACKUP_FILE="${Prefix}$(date +%Y%m%d_%H%M%S).bak"
    echo -e "${BLUE}Backing up current settings to ${BACKUP_FILE}...${RESET}"

    {
        echo "# Android Display & Performance Settings Backup"
        echo "# Created on $(date)"
        echo
        echo "# Animation Scales"
        echo "window_animation_scale=$(run_adb shell settings get global window_animation_scale)"
        echo "transition_animation_scale=$(run_adb shell settings get global transition_animation_scale)"
        echo "animator_duration_scale=$(run_adb shell settings get global animator_duration_scale)"
        echo
        echo "# DPI"
        echo "density=$(run_adb shell wm density | grep -oE '[0-9]+' | head -1)"
        echo
        echo "# Hardware Acceleration"
        echo "hwui_render_dirty_regions=$(run_adb shell getprop debug.hwui.render_dirty_regions)"
        echo "persist_sys_ui_hw=$(run_adb shell getprop persist.sys.ui.hw)"
        echo "force_gpu_rendering=$(run_adb shell settings get global force_gpu_rendering)"
        echo
        echo "# Rotation"
        echo "accelerometer_rotation=$(run_adb shell settings get system accelerometer_rotation)"
        echo "user_rotation=$(run_adb shell settings get system user_rotation)"
    } > "$BACKUP_FILE"

    echo -e "${GREEN}✓ Backup complete: ${BACKUP_FILE}${RESET}"
}

restore_settings() {
    echo -e "${BLUE}Select a backup file to restore:${RESET}"
    select BACKUP_FILE in *.bak; do
        if [ -n "$BACKUP_FILE" ]; then
            break
        else
            echo -e "${RED}Invalid selection. Please try again.${RESET}"
        fi
    done

    echo -e "${YELLOW}Restoring settings from ${BACKUP_FILE}...${RESET}"

    while IFS='=' read -r key value; do
        if [[ ! "$key" =~ ^# && "$value" ]]; then
            case "$key" in
                window_animation_scale|transition_animation_scale|animator_duration_scale)
                    run_adb shell settings put global $key $value
                    ;;
                density)
                    run_adb shell wm density $value
                    ;;
                hwui_render_dirty_regions|persist_sys_ui_hw)
                    run_adb shell setprop $key $value
                    ;;
                force_gpu_rendering)
                    run_adb shell settings put global $key $value
                    ;;
                accelerometer_rotation|user_rotation)
                    run_adb shell settings put system $key $value
                    ;;
            esac
        fi
    done < "$BACKUP_FILE"

    echo -e "${GREEN}✓ Settings restored from ${BACKUP_FILE}${RESET}"
    echo -e "${BOLD}A reboot is recommended for all changes to take effect.${RESET}"
}

handle_info() {
    case $1 in
        1) get_animation_settings;;
        2) get_dpi_info;;
        3) get_device_info;;
        4) get_hw_acceleration_status;;
        5) get_rotation_settings;;
    esac
}

handle_animation() {
    case $1 in
        6) set_animation_scale 1.0;;
        7) set_animation_scale 0.9;;
        8) set_animation_scale 0.75;;
        9)
            echo -n -e "${BOLD}Enter custom scale (e.g., 0.5): ${RESET}"
            read custom_scale
            if [[ "$custom_scale" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                set_animation_scale $custom_scale
            else
                echo -e "${RED}Invalid scale. Please enter a number.${RESET}"
            fi
            ;;
        10) set_animation_scale 0.0;;
    esac
}

handle_dpi() {
    case $1 in
        11) set_custom_dpi;;
        12) reset_dpi;;
    esac
}

handle_rotation() {
    case $1 in
        13) enable_all_rotations;;
        14) disable_upside_down_rotation;;
        15) toggle_auto_rotation;;
        16) set_specific_rotation 0;;
        17) set_specific_rotation 1;;
        18) set_specific_rotation 2;;
        19) set_specific_rotation 3;;
    esac
}

handle_hw_acceleration() {
    case $1 in
        20) enable_all_hw_acceleration;;
        23) disable_all_hw_acceleration;;
        26) reset_hw_acceleration;;
        27) toggle_gpu_profile;;
        28) toggle_gpu_overdraw;;
        *) echo -e "${YELLOW}This option is deprecated or invalid.${RESET}";;
    esac
}

show_menu() {
    clear
    echo -e "${BOLD}╔═════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Android Display & Performance Optimizer    ║${RESET}"
    echo -e "${BOLD}╚═════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BOLD}SELECTED DEVICE:${RESET} ${GREEN}$SELECTED_DEVICE${RESET} ($(run_adb shell getprop ro.product.model | tr -d '\r'))"
    echo -e "${YELLOW}c. Change device${RESET}     ${RED}r. Reboot device${RESET}     ${BLUE}b. Backup${RESET}    ${GREEN}s. Restore${RESET}    ${RED}0. Exit${RESET}"
    echo
    echo -e "${BOLD}--- INFORMATION ---${RESET}"
    echo -e "  1. Show animation settings      4. Show HW acceleration status"
    echo -e "  2. Show current DPI info        5. Show rotation settings"
    echo -e "  3. Show device information"
    echo
    echo -e "${BOLD}--- ANIMATION ---${RESET}"
    echo -e "  6. Set animations to 1.0x       9. Set custom animation scale"
    echo -e "  7. Set animations to 0.9x      10. Turn off animations (0.0x)"
    echo -e "  8. Set animations to 0.75x"
    echo
    echo -e "${BOLD}--- DISPLAY & ROTATION ---${RESET}"
    echo -e " 11. Set custom DPI              16. Lock rotation: Portrait"
    echo -e " 12. Reset DPI to default        17. Lock rotation: Landscape"
    echo -e " 13. Enable all rotations        18. Lock rotation: Upside-down"
    echo -e " 14. Disable upside-down rot.    19. Lock rotation: Landscape (rev)"
    echo -e " 15. Toggle auto-rotation"
    echo
    echo -e "${BOLD}--- HARDWARE ACCELERATION ---${RESET}"
    echo -e " 20. Enable all HW acceleration      27. Toggle GPU Profile Rendering"
    echo -e " 23. Disable all HW acceleration     28. Toggle GPU Overdraw Debug"
    echo -e " 26. Reset HW acceleration to default"
    echo
    echo -ne "${BOLD}Select an option: ${RESET}"
}

wait_for_enter() {
    echo
    echo -n -e "Press Enter to continue..."
    read
}

# --- Main Execution ---
create_config_if_missing
source <(grep = config.ini | sed 's/ *= */=/g' | sed 's/\s\+/\n/g')
check_and_select_device

while true; do


    show_menu
    read choice

    case $choice in
        [1-5]) handle_info $choice; wait_for_enter;;
        [6-9]|10) handle_animation $choice; wait_for_enter;;
        11|12) handle_dpi $choice; wait_for_enter;;
        [1-2][0-6]) # Matches 13-19 and 20-26
            if [ $choice -ge 13 ] && [ $choice -le 19 ]; then
                handle_rotation $choice
            elif [ $choice -ge 20 ] && [ $choice -le 26 ]; then
                handle_hw_acceleration $choice
            fi
            wait_for_enter
            ;;
        c|C) change_device;;
        r|R) reboot_device; wait_for_enter;;
        b|B) backup_settings; wait_for_enter;;
        s|S) restore_settings; wait_for_enter;;
        0) echo -e "${GREEN}Exiting...${RESET}"; exit 0;;
        *) echo -e "${RED}Invalid option. Please try again.${RESET}"; sleep 1;;
    esac
done
