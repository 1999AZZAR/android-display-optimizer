#!/usr/bin/env bash
set -euo pipefail
if ! command -v adb >/dev/null 2>&1; then
    echo -e "\033[0;31mADB is required but not installed. Please install ADB and ensure it's in your PATH.\033[0m"
    exit 1
fi

# Global variable for selected device
SELECTED_DEVICE=""
CAP_ROTATION_WINDOW_CMD=0

# Default color definitions (can be overridden by config.ini)
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# --- Function Definitions ---

run_adb() {
    adb -s "$SELECTED_DEVICE" "$@"
}

run_menu_action() {
    local status
    set +e
    "$@"
    status=$?
    set -e

    if [ $status -ne 0 ]; then
        echo
        echo -e "${RED}Action failed with exit code ${status}.${RESET}"
        echo -e "${YELLOW}Some properties require root, are read-only on your device, or are unsupported on this Android build.${RESET}"
    fi

    return $status
}

run_step() {
    local description status

    description=$1
    shift

    set +e
    "$@"
    status=$?
    set -e

    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ ${description}${RESET}"
    else
        echo -e "${RED}✗ ${description} (exit ${status})${RESET}"
    fi

    return $status
}

run_step_summary() {
    local action_name success_count failure_count

    action_name=$1
    success_count=$2
    failure_count=$3

    if [ $failure_count -eq 0 ]; then
        echo -e "${GREEN}✓ ${action_name} completed successfully${RESET}"
        return 0
    fi

    if [ $success_count -gt 0 ]; then
        echo -e "${YELLOW}${action_name} partially completed: ${success_count} succeeded, ${failure_count} failed.${RESET}"
    else
        echo -e "${RED}${action_name} failed: all ${failure_count} steps failed.${RESET}"
    fi

    return 1
}

load_config_vars() {
    local config_file="${1:-config.ini}"

    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Configuration file '$config_file' not found.${RESET}" >&2
        return 1
    fi

    # Only load simple KEY=VALUE assignments and ignore section headers/comments.
    source <(sed -n '/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/p' "$config_file" | sed 's/^[[:space:]]*//; s/[[:space:]]*=[[:space:]]*/=/')
}

detect_device_capabilities() {
    local window_help status

    CAP_ROTATION_WINDOW_CMD=0

    set +e
    window_help=$(run_adb shell cmd window help 2>/dev/null | tr -d '\r')
    status=$?
    set -e

    if [ $status -eq 0 ] && printf '%s\n' "$window_help" | grep -q "set-allowed-display-rotations"; then
        CAP_ROTATION_WINDOW_CMD=1
    fi
}

check_and_select_device() {
    echo -e "${BLUE}Checking for connected devices...${RESET}"
    mapfile -t DEVICE_LIST < <(adb devices | awk '$2 == "device" {print $1}')
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
            MODEL=$(adb -s "$DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
            echo -e "  ${BOLD}$((i + 1))${RESET}. $DEVICE ${YELLOW}($MODEL)${RESET}"
        done

        while true; do
            echo -ne "${BOLD}Select device (1-$DEVICE_COUNT): ${RESET}"
            read -r selection
            if [[ $selection =~ ^[0-9]+$ ]] && [ $selection -ge 1 ] && [ $selection -le $DEVICE_COUNT ]; then
                SELECTED_DEVICE=${DEVICE_LIST[$((selection - 1))]}
                echo -e "${GREEN}✓ Selected device: $SELECTED_DEVICE${RESET}"
                break
            else
                echo -e "${RED}Invalid selection. Please try again.${RESET}"
            fi
        done
    fi
    detect_device_capabilities
    echo
}

create_config_if_missing() {
    CONFIG_FILE="config.ini"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Configuration file not found. Creating a default config.ini...${RESET}"
        save_settings_to_config # Generate config from current device state
        echo -e "${GREEN}✓ Default config.ini created from current device settings.${RESET}"
        echo -e "${YELLOW}You can now edit this file to create a custom default profile.${RESET}"
        echo
    fi
}

save_settings_to_config() {
    CONFIG_FILE="config.ini"
    echo -e "${BLUE}Saving current device settings to ${CONFIG_FILE}...${RESET}"
    {
        echo "# Android Optimizer Configuration Profile"
        echo "# Edit these values to define the script's default behavior."
        echo
        echo "[Animation]"
        echo "window_animation_scale=$(run_adb shell settings get global window_animation_scale)"
        echo "transition_animation_scale=$(run_adb shell settings get global transition_animation_scale)"
        echo "animator_duration_scale=$(run_adb shell settings get global animator_duration_scale)"
        echo
        echo "[Display]"
        echo "density=$(run_adb shell wm density | grep -oE '[0-9]+' | head -1)"
        echo "screen_off_timeout=$(run_adb shell settings get system screen_off_timeout | tr -d '\r')"
        echo "screen_brightness=$(run_adb shell settings get system screen_brightness | tr -d '\r')"
        echo "screen_brightness_mode=$(run_adb shell settings get system screen_brightness_mode | tr -d '\r')"
        echo "font_scale=$(run_adb shell settings get system font_scale | tr -d '\r')"
        echo
        echo "[HardwareAcceleration]"
        echo "force_gpu_rendering=$(run_adb shell settings get global force_gpu_rendering)"
        echo "profile_gpu_rendering=$(run_adb shell getprop debug.hwui.profile)"
        echo "debug_gpu_overdraw=$(run_adb shell getprop debug.hwui.overdraw)"
        echo
        echo "[Power]"
        echo "stay_on_while_plugged_in=$(run_adb shell settings get global stay_on_while_plugged_in | tr -d '\r')"
        echo
        echo "[Rotation]"
        echo "accelerometer_rotation=$(run_adb shell settings get system accelerometer_rotation)"
        echo "user_rotation=$(run_adb shell settings get system user_rotation)"
        echo
        echo "[Backup]"
        echo "Prefix=android_settings_"
        echo
        echo "[Colors]"
        echo "BOLD='\033[1m'"
        echo "GREEN='\033[0;32m'"
        echo "BLUE='\033[0;34m'"
        echo "CYAN='\033[0;36m'"
        echo "YELLOW='\033[0;33m'"
        echo "RED='\033[0;31m'"
        echo "RESET='\033[0m'"
    } > "$CONFIG_FILE"
    echo -e "${GREEN}✓ Settings saved to ${CONFIG_FILE}${RESET}"
}

load_config_to_device() {
    echo -e "${YELLOW}Applying all settings from config.ini to device...${RESET}"
    load_config_vars config.ini

    # Apply settings
    run_adb shell settings put global window_animation_scale "$window_animation_scale"
    run_adb shell settings put global transition_animation_scale "$transition_animation_scale"
    run_adb shell settings put global animator_duration_scale "$animator_duration_scale"
    run_adb shell wm density "$density"
    run_adb shell settings put system screen_off_timeout "$screen_off_timeout"
    run_adb shell settings put system screen_brightness_mode "$screen_brightness_mode"
    run_adb shell settings put system screen_brightness "$screen_brightness"
    run_adb shell settings put system font_scale "$font_scale"
    run_adb shell settings put global force_gpu_rendering "$force_gpu_rendering"
    run_adb shell setprop debug.hwui.profile "$profile_gpu_rendering"
    run_adb shell setprop debug.hwui.overdraw "$debug_gpu_overdraw"
    run_adb shell settings put global stay_on_while_plugged_in "$stay_on_while_plugged_in"
    run_adb shell settings put system accelerometer_rotation "$accelerometer_rotation"
    run_adb shell settings put system user_rotation "$user_rotation"

    echo -e "${GREEN}✓ All settings from config.ini have been applied.${RESET}"
    echo -e "${BOLD}A reboot may be required for some changes to take full effect.${RESET}"
}

get_animation_settings() {
    echo -e "${BOLD}Current Animation Settings:${RESET}"
    echo -e "Window animation scale: ${GREEN}$(run_adb shell settings get global window_animation_scale)${RESET}"
    echo -e "Transition animation scale: ${GREEN}$(run_adb shell settings get global transition_animation_scale)${RESET}"
    echo -e "Animator duration scale: ${GREEN}$(run_adb shell settings get global animator_duration_scale)${RESET}"
}

get_dpi_info() {
    local current_dpi default_dpi current_brightness brightness_mode brightness_mode_label current_font_scale

    current_dpi=$(run_adb shell wm density | grep -oE '[0-9]+' | head -1)
    default_dpi=$(run_adb shell getprop ro.sf.lcd_density)
    current_brightness=$(run_adb shell settings get system screen_brightness | tr -d '\r')
    brightness_mode=$(run_adb shell settings get system screen_brightness_mode | tr -d '\r')
    current_font_scale=$(run_adb shell settings get system font_scale | tr -d '\r')

    case "$brightness_mode" in
        0) brightness_mode_label="Manual";;
        1) brightness_mode_label="Adaptive";;
        *) brightness_mode_label="Unknown ($brightness_mode)";;
    esac

    echo -e "${BOLD}Display Information:${RESET}"
    echo -e "Current DPI: ${GREEN}$current_dpi${RESET}"
    echo -e "Default DPI: ${GREEN}$default_dpi${RESET}"
    echo -e "Brightness: ${GREEN}$current_brightness${RESET} ${YELLOW}(0-255)${RESET}"
    echo -e "Brightness mode: ${GREEN}$brightness_mode_label${RESET}"
    echo -e "Font scale: ${GREEN}$current_font_scale${RESET}"
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

get_full_device_info() {
    local manufacturer brand device_name android_version sdk_version security_patch
    local build_id build_type abi_list serial battery_line battery_level battery_status
    local mem_total mem_available storage_line uptime_seconds uptime_human ip_address

    manufacturer=$(run_adb shell getprop ro.product.manufacturer | tr -d '\r')
    brand=$(run_adb shell getprop ro.product.brand | tr -d '\r')
    device_name=$(run_adb shell getprop ro.product.model | tr -d '\r')
    android_version=$(run_adb shell getprop ro.build.version.release | tr -d '\r')
    sdk_version=$(run_adb shell getprop ro.build.version.sdk | tr -d '\r')
    security_patch=$(run_adb shell getprop ro.build.version.security_patch | tr -d '\r')
    build_id=$(run_adb shell getprop ro.build.display.id | tr -d '\r')
    build_type=$(run_adb shell getprop ro.build.type | tr -d '\r')
    abi_list=$(run_adb shell getprop ro.product.cpu.abilist | tr -d '\r')
    serial=$(run_adb shell getprop ro.serialno | tr -d '\r')

    battery_line=$(run_adb shell dumpsys battery | tr -d '\r')
    battery_level=$(printf '%s\n' "$battery_line" | sed -n 's/.*level: \([0-9]\+\).*/\1/p' | head -1)
    battery_status=$(printf '%s\n' "$battery_line" | sed -n 's/.*status: \([0-9]\+\).*/\1/p' | head -1)

    mem_total=$(run_adb shell "awk '/MemTotal/ {print \$2 \" kB\"}' /proc/meminfo" | tr -d '\r')
    mem_available=$(run_adb shell "awk '/MemAvailable/ {print \$2 \" kB\"}' /proc/meminfo" | tr -d '\r')
    storage_line=$(run_adb shell df -h /data 2>/dev/null | tail -1 | tr -d '\r')
    uptime_seconds=$(run_adb shell cut -d. -f1 /proc/uptime | tr -d '\r')
    ip_address=$(run_adb shell "ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print \$2}' | cut -d/ -f1" | tr -d '\r')

    if [ -n "$uptime_seconds" ] && [[ "$uptime_seconds" =~ ^[0-9]+$ ]]; then
        uptime_human="$((uptime_seconds / 86400))d $(((uptime_seconds % 86400) / 3600))h $(((uptime_seconds % 3600) / 60))m"
    else
        uptime_human="Unknown"
    fi

    case "$battery_status" in
        2) battery_status="Charging";;
        3) battery_status="Discharging";;
        4) battery_status="Not charging";;
        5) battery_status="Full";;
        *) battery_status="Unknown";;
    esac

    [ -z "$ip_address" ] && ip_address="Unavailable"

    echo -e "${BOLD}Full Device Information:${RESET}"
    echo -e "Device ID: ${GREEN}$SELECTED_DEVICE${RESET}"
    echo -e "Serial: ${GREEN}$serial${RESET}"
    echo -e "Manufacturer: ${GREEN}$manufacturer${RESET}"
    echo -e "Brand: ${GREEN}$brand${RESET}"
    echo -e "Model: ${GREEN}$device_name${RESET}"
    echo -e "Android Version: ${GREEN}$android_version${RESET}"
    echo -e "SDK Version: ${GREEN}$sdk_version${RESET}"
    echo -e "Security Patch: ${GREEN}$security_patch${RESET}"
    echo -e "Build ID: ${GREEN}$build_id${RESET}"
    echo -e "Build Type: ${GREEN}$build_type${RESET}"
    echo -e "CPU ABIs: ${GREEN}$abi_list${RESET}"
    echo -e "Screen Resolution: ${GREEN}$(run_adb shell wm size | tr -d '\r')${RESET}"
    echo -e "Battery Level: ${GREEN}${battery_level:-Unknown}%${RESET}"
    echo -e "Battery Status: ${GREEN}$battery_status${RESET}"
    echo -e "Memory Total: ${GREEN}${mem_total:-Unknown}${RESET}"
    echo -e "Memory Available: ${GREEN}${mem_available:-Unknown}${RESET}"
    echo -e "Storage (/data): ${GREEN}${storage_line:-Unavailable}${RESET}"
    echo -e "Uptime: ${GREEN}$uptime_human${RESET}"
    echo -e "Wi-Fi IP: ${GREEN}$ip_address${RESET}"
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
    run_adb shell settings put global window_animation_scale "$SCALE"
    run_adb shell settings put global transition_animation_scale "$SCALE"
    run_adb shell settings put global animator_duration_scale "$SCALE"
    echo -e "${GREEN}✓ Animation scales set to ${SCALE}x${RESET}"
}

set_custom_dpi() {
    get_dpi_info
    echo -n -e "${BOLD}Enter new DPI value: ${RESET}"
    read -r new_dpi
    if [[ "$new_dpi" =~ ^[0-9]+$ ]]; then
        echo -e "${BLUE}Setting device DPI to $new_dpi...${RESET}"
        run_adb shell wm density "$new_dpi"
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

set_screen_timeout() {
    local timeout_seconds timeout_millis

    timeout_seconds=$1
    timeout_millis=$((timeout_seconds * 1000))

    echo -e "${BLUE}Setting screen timeout to ${timeout_seconds} seconds...${RESET}"
    run_adb shell settings put system screen_off_timeout "$timeout_millis"
    echo -e "${GREEN}✓ Screen timeout set to ${timeout_seconds} seconds${RESET}"
}

set_custom_screen_timeout() {
    local timeout_seconds

    echo -n -e "${BOLD}Enter screen timeout in seconds: ${RESET}"
    read -r timeout_seconds

    if [[ "$timeout_seconds" =~ ^[0-9]+$ ]] && [ "$timeout_seconds" -gt 0 ]; then
        set_screen_timeout "$timeout_seconds"
    else
        echo -e "${RED}Invalid timeout value. Please enter a positive whole number.${RESET}"
    fi
}

set_brightness_mode() {
    local brightness_mode brightness_mode_label

    brightness_mode=$1

    case "$brightness_mode" in
        0) brightness_mode_label="manual";;
        1) brightness_mode_label="adaptive";;
        *) brightness_mode_label="unknown";;
    esac

    echo -e "${BLUE}Setting brightness mode to ${brightness_mode_label}...${RESET}"
    run_adb shell settings put system screen_brightness_mode "$brightness_mode"
    echo -e "${GREEN}✓ Brightness mode set to ${brightness_mode_label}${RESET}"
}

set_brightness() {
    local brightness_level

    brightness_level=$1

    echo -e "${BLUE}Setting brightness to ${brightness_level}...${RESET}"
    run_adb shell settings put system screen_brightness_mode 0
    run_adb shell settings put system screen_brightness "$brightness_level"
    echo -e "${GREEN}✓ Brightness set to ${brightness_level}${RESET}"
}

set_custom_brightness() {
    local brightness_level

    echo -n -e "${BOLD}Enter brightness value (0-255): ${RESET}"
    read -r brightness_level

    if [[ "$brightness_level" =~ ^[0-9]+$ ]] && [ "$brightness_level" -ge 0 ] && [ "$brightness_level" -le 255 ]; then
        set_brightness "$brightness_level"
    else
        echo -e "${RED}Invalid brightness value. Please enter a whole number from 0 to 255.${RESET}"
    fi
}

set_font_scale() {
    local scale_value

    scale_value=$1

    echo -e "${BLUE}Setting font scale to ${scale_value}...${RESET}"
    run_adb shell settings put system font_scale "$scale_value"
    echo -e "${GREEN}✓ Font scale set to ${scale_value}${RESET}"
}

set_custom_font_scale() {
    local scale_value

    echo -n -e "${BOLD}Enter font scale (example: 1.15): ${RESET}"
    read -r scale_value

    if [[ "$scale_value" =~ ^[0-9]+(\.[0-9]+)?$ ]] && awk "BEGIN {exit !($scale_value > 0)}"; then
        set_font_scale "$scale_value"
    else
        echo -e "${RED}Invalid font scale. Please enter a positive number.${RESET}"
    fi
}

set_stay_awake_mode() {
    local plug_value mode_label

    plug_value=$1

    case "$plug_value" in
        0) mode_label="disabled";;
        3) mode_label="AC and USB";;
        7) mode_label="AC, USB, and wireless";;
        *) mode_label="custom ($plug_value)";;
    esac

    echo -e "${BLUE}Setting stay-awake mode to ${mode_label}...${RESET}"
    run_adb shell settings put global stay_on_while_plugged_in "$plug_value"
    echo -e "${GREEN}✓ Stay-awake mode set to ${mode_label}${RESET}"
}

enable_all_rotations() {
    if [ "$CAP_ROTATION_WINDOW_CMD" -ne 1 ]; then
        echo -e "${YELLOW}This device does not support 'cmd window set-allowed-display-rotations'.${RESET}"
        return 1
    fi
    echo -e "${BLUE}Enabling all screen rotations (including upside-down)...${RESET}"
    run_adb shell cmd window set-allowed-display-rotations 0,1,2,3
    echo -e "${GREEN}✓ All screen rotations enabled${RESET}"
}

disable_upside_down_rotation() {
    if [ "$CAP_ROTATION_WINDOW_CMD" -ne 1 ]; then
        echo -e "${YELLOW}This device does not support 'cmd window set-allowed-display-rotations'.${RESET}"
        return 1
    fi
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
    run_adb shell settings put system user_rotation "$ROTATION"
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
    local success_count failure_count

    success_count=0
    failure_count=0

    echo -e "${BLUE}Enabling all hardware acceleration features...${RESET}"
    run_step "Enable HWUI dirty region rendering" run_adb shell setprop debug.hwui.render_dirty_regions true && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Enable persist.sys.ui.hw" run_adb shell setprop persist.sys.ui.hw 1 && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Enable force GPU rendering" run_adb shell settings put global force_gpu_rendering 1 && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step_summary "Hardware acceleration enable" "$success_count" "$failure_count"
    echo -e "${BOLD}Note: A device restart is recommended for changes to take full effect${RESET}"
}

disable_all_hw_acceleration() {
    local success_count failure_count

    success_count=0
    failure_count=0

    echo -e "${BLUE}Disabling all hardware acceleration features...${RESET}"
    run_step "Disable HWUI dirty region rendering" run_adb shell setprop debug.hwui.render_dirty_regions false && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Disable persist.sys.ui.hw" run_adb shell setprop persist.sys.ui.hw 0 && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Disable force GPU rendering" run_adb shell settings put global force_gpu_rendering 0 && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step_summary "Hardware acceleration disable" "$success_count" "$failure_count"
    echo -e "${BOLD}Note: A device restart is recommended for changes to take full effect${RESET}"
}

reset_hw_acceleration() {
    local success_count failure_count

    success_count=0
    failure_count=0

    echo -e "${BLUE}Resetting hardware acceleration to device defaults...${RESET}"
    run_step "Reset HWUI dirty region rendering" run_adb shell setprop debug.hwui.render_dirty_regions "" && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Reset persist.sys.ui.hw" run_adb shell setprop persist.sys.ui.hw "" && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Delete force GPU rendering override" run_adb shell settings delete global force_gpu_rendering && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Disable GPU profile rendering" run_adb shell setprop debug.hwui.profile false && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step "Disable GPU overdraw debug" run_adb shell setprop debug.hwui.overdraw false && success_count=$((success_count + 1)) || failure_count=$((failure_count + 1))
    run_step_summary "Hardware acceleration reset" "$success_count" "$failure_count"
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
    read -r wait_response
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
    load_config_vars config.ini
    BACKUP_FILE="${Prefix}$(date +%Y%m%d_%H%M%S).bak"
    echo -e "${BLUE}Performing a full backup of all known settings to ${BACKUP_FILE}...${RESET}"
    save_settings_to_config # Use the same logic to ensure all settings are captured
    mv config.ini "$BACKUP_FILE"
    echo -e "${GREEN}✓ Full backup complete: ${BACKUP_FILE}${RESET}"
    create_config_if_missing # Recreate a default config to continue working
}

change_device() {
    check_and_select_device
}

get_selected_device_model() {
    local model status

    set +e
    model=$(run_adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    status=$?
    set -e

    if [ $status -ne 0 ] || [ -z "$model" ]; then
        echo "Unknown device"
    else
        echo "$model"
    fi
}

restore_settings() {
    local backup_files=()

    shopt -s nullglob
    backup_files=(*.bak)
    shopt -u nullglob

    if [ ${#backup_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No backup files found in the current directory.${RESET}"
        return 1
    fi

    echo -e "${BLUE}Select a backup file to restore:${RESET}"
    select BACKUP_FILE in "${backup_files[@]}"; do
        if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
            break
        else
            echo -e "${RED}Invalid selection. Please try again.${RESET}"
        fi
    done

    echo -e "${YELLOW}Restoring all settings from ${BACKUP_FILE}...${RESET}"
    cp "$BACKUP_FILE" config.ini
    load_config_to_device
    echo -e "${GREEN}✓ All settings restored from ${BACKUP_FILE}${RESET}"
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
            read -r custom_scale
            if [[ "$custom_scale" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                set_animation_scale "$custom_scale"
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

handle_screen_timeout() {
    case $1 in
        20) set_screen_timeout 30;;
        21) set_screen_timeout 60;;
        22) set_screen_timeout 120;;
        23) set_screen_timeout 300;;
        24) set_screen_timeout 600;;
        25) set_screen_timeout 1800;;
        26) set_screen_timeout 7;;
        27) set_screen_timeout 10;;
        28) set_screen_timeout 15;;
        29) set_screen_timeout 20;;
        30) set_custom_screen_timeout;;
    esac
}

handle_brightness() {
    case $1 in
        31) set_brightness_mode 0;;
        32) set_brightness_mode 1;;
        33) set_brightness 64;;
        34) set_brightness 128;;
        35) set_brightness 192;;
        36) set_custom_brightness;;
    esac
}

handle_font_scale() {
    case $1 in
        37) set_font_scale 0.85;;
        38) set_font_scale 1.0;;
        39) set_font_scale 1.15;;
        40) set_font_scale 1.3;;
        41) set_custom_font_scale;;
    esac
}

handle_stay_awake() {
    case $1 in
        42) set_stay_awake_mode 0;;
        43) set_stay_awake_mode 3;;
        44) set_stay_awake_mode 7;;
    esac
}

handle_hw_acceleration() {
    case $1 in
        45) enable_all_hw_acceleration;;
        46) disable_all_hw_acceleration;;
        47) reset_hw_acceleration;;
        48) toggle_gpu_profile;;
        49) toggle_gpu_overdraw;;
        *) echo -e "${YELLOW}This option is deprecated or invalid.${RESET}";;
    esac
}

show_menu() {
    local rotation_enable_label rotation_disable_label

    if [ "$CAP_ROTATION_WINDOW_CMD" -eq 1 ]; then
        rotation_enable_label="13. Enable all rotations"
        rotation_disable_label="14. Disable upside-down rot."
    else
        rotation_enable_label="13. Enable all rotations [unsupported]"
        rotation_disable_label="14. Disable upside-down rot. [unsupported]"
    fi

    clear
    echo -e "${BOLD}╔═════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║       Android Display & Performance Optimizer    ║${RESET}"
    echo -e "${BOLD}╚═════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BOLD}SELECTED DEVICE:${RESET} ${GREEN}$SELECTED_DEVICE${RESET} ($(get_selected_device_model))"
    echo -e "${YELLOW}c. Change device${RESET}     ${CYAN}i. Full device info${RESET}     ${RED}r. Reboot device${RESET}     ${BLUE}b. Backup${RESET}    ${GREEN}s. Restore${RESET}    ${RED}0. Exit${RESET}"
    echo
    echo -e "${BOLD}--- INFORMATION ---${RESET}"
    echo -e "  1. Show animation settings      4. Show HW acceleration status"
    echo -e "  2. Show display info            5. Show rotation settings"
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
    echo -e " ${rotation_enable_label}        18. Lock rotation: Upside-down"
    echo -e " ${rotation_disable_label}    19. Lock rotation: Landscape (rev)"
    echo -e " 15. Toggle auto-rotation"
    echo
    echo -e "${BOLD}--- SCREEN TIMEOUT ---${RESET}"
    echo -e " 20. Set timeout to 30 seconds   24. Set timeout to 10 minutes"
    echo -e " 21. Set timeout to 1 minute     25. Set timeout to 30 minutes"
    echo -e " 22. Set timeout to 2 minutes    26. Set timeout to 7 seconds"
    echo -e " 23. Set timeout to 5 minutes    27. Set timeout to 10 seconds"
    echo -e "                                 28. Set timeout to 15 seconds"
    echo -e "                                 29. Set timeout to 20 seconds"
    echo -e "                                 30. Set custom timeout"
    echo
    echo -e "${BOLD}--- BRIGHTNESS ---${RESET}"
    echo -e " 31. Set mode: manual            34. Set brightness: 128"
    echo -e " 32. Set mode: adaptive          35. Set brightness: 192"
    echo -e " 33. Set brightness: 64          36. Set custom brightness"
    echo
    echo -e "${BOLD}--- FONT SCALE ---${RESET}"
    echo -e " 37. Set font scale: 0.85        40. Set font scale: 1.3"
    echo -e " 38. Set font scale: 1.0         41. Set custom font scale"
    echo -e " 39. Set font scale: 1.15"
    echo
    echo -e "${BOLD}--- POWER ---${RESET}"
    echo -e " 42. Stay awake: off             44. Stay awake: AC + USB + wireless"
    echo -e " 43. Stay awake: AC + USB"
    echo
    echo -e "${BOLD}--- HARDWARE ACCELERATION ---${RESET}"
    echo -e " 45. Enable all HW acceleration      48. Toggle GPU Profile Rendering"
    echo -e " 46. Disable all HW acceleration     49. Toggle GPU Overdraw Debug"
    echo -e " 47. Reset HW acceleration to default"
    echo
    echo -ne "${BOLD}Select an option: ${RESET}"
}

wait_for_enter() {
    echo
    echo -n -e "Press Enter to continue..."
    read -r
}

# --- Main Execution ---
check_and_select_device
create_config_if_missing
load_config_vars config.ini

while true; do


    show_menu
    read -r choice

    case $choice in
        [1-5]) run_menu_action handle_info "$choice"; wait_for_enter;;
        [6-9]|10) run_menu_action handle_animation "$choice"; wait_for_enter;;
        11|12) run_menu_action handle_dpi "$choice"; wait_for_enter;;
        13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49)
            if [ $choice -ge 13 ] && [ $choice -le 19 ]; then
                run_menu_action handle_rotation "$choice"
            elif [ $choice -ge 20 ] && [ $choice -le 30 ]; then
                run_menu_action handle_screen_timeout "$choice"
            elif [ $choice -ge 31 ] && [ $choice -le 36 ]; then
                run_menu_action handle_brightness "$choice"
            elif [ $choice -ge 37 ] && [ $choice -le 41 ]; then
                run_menu_action handle_font_scale "$choice"
            elif [ $choice -ge 42 ] && [ $choice -le 44 ]; then
                run_menu_action handle_stay_awake "$choice"
            elif [ $choice -ge 45 ] && [ $choice -le 49 ]; then
                run_menu_action handle_hw_acceleration "$choice"
            fi
            wait_for_enter
            ;;
        c|C) change_device;;
        i|I) run_menu_action get_full_device_info; wait_for_enter;;
        r|R) run_menu_action reboot_device; wait_for_enter;;
        b|B) run_menu_action backup_settings; wait_for_enter;;
        s|S) run_menu_action restore_settings; wait_for_enter;;
        0) echo -e "${GREEN}Exiting...${RESET}"; exit 0;;
        *) echo -e "${RED}Invalid option. Please try again.${RESET}"; sleep 1;;
    esac
done
