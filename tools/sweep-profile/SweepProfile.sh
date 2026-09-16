#!/usr/bin/env bash
set -euo pipefail

readonly sweep_address="${SWEEP_ADDRESS:-EA:96:13:93:DA:2F}"
readonly config_home="${SWEEP_PROFILE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
readonly state_home="${SWEEP_PROFILE_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprdots}"
readonly runtime_home="${SWEEP_PROFILE_RUNTIME_HOME:-${XDG_RUNTIME_DIR:-/tmp}/hyprdots-$UID}"
readonly active_config="$config_home/hypr/UserConfigs/ActiveKeybindProfile.conf"
readonly default_profile='$HOME/.config/hypr/UserConfigs/KeybindProfiles/Default.conf'
readonly sweep_profile='$HOME/.config/hypr/UserConfigs/KeybindProfiles/Sweep.conf'
readonly preference_file="$state_home/sweep-profile-enabled"
readonly event_reconnect_delay="${SWEEP_PROFILE_EVENT_RECONNECT_DELAY:-2}"
sweep_device_component="dev_${sweep_address^^}"
readonly sweep_device_component="${sweep_device_component//:/_}"

mkdir -p "$state_home" "$runtime_home" "$(dirname -- "$active_config")"

sweep_connected() {
    if [[ -n "${SWEEP_PROFILE_CONNECTED:-}" ]]; then
        [[ "$SWEEP_PROFILE_CONNECTED" == 1 ]]
        return
    fi
    LC_ALL=C timeout 4s bluetoothctl info "$sweep_address" 2>/dev/null |
        grep -qE '^[[:space:]]*Connected:[[:space:]]+yes$'
}

preference_enabled() {
    [[ -r "$preference_file" ]] && [[ "$(<"$preference_file")" == 1 ]]
}

write_preference() {
    local value="$1" temporary
    temporary="$(mktemp "$state_home/.sweep-profile-enabled.XXXXXX")"
    printf '%s\n' "$value" >"$temporary"
    mv -f -- "$temporary" "$preference_file"
}

signal_waybar() {
    [[ "${SWEEP_PROFILE_NO_SIGNAL:-0}" == 1 ]] && return 0
    pkill -RTMIN+12 -x waybar 2>/dev/null || true
}

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Sweep profile" "$1" "$2"
}

apply_profile() {
    local connected=0 requested=0 active=0 profile label temporary desired current=""
    sweep_connected && connected=1
    preference_enabled && requested=1
    (( connected && requested )) && active=1

    if (( active )); then
        profile="$sweep_profile"
        label=sweep
    else
        profile="$default_profile"
        label=default
    fi

    printf -v desired '# Managed by SweepProfile.sh.\nsource = %s' "$profile"
    [[ -r "$active_config" ]] && current="$(<"$active_config")"
    if [[ "$current" != "$desired" ]]; then
        temporary="$(mktemp "$(dirname -- "$active_config")/.ActiveKeybindProfile.XXXXXX")"
        printf '%b\n' "$desired" >"$temporary"
        mv -f -- "$temporary" "$active_config"
        if [[ "${SWEEP_PROFILE_NO_RELOAD:-0}" != 1 ]]; then
            hyprctl reload >/dev/null 2>&1 || true
        fi
        signal_waybar
    fi

    CONNECTED=$connected
    REQUESTED=$requested
    ACTIVE=$active
    PROFILE_LABEL=$label
}

print_status() {
    apply_profile
    if (( ! CONNECTED )); then
        printf '{"text":"󰌙 ","tooltip":"Sweep disconnected\\nDefault keybind profile active","class":"disconnected"}\n'
    elif (( ACTIVE )); then
        printf '{"text":"","tooltip":"Sweep connected\\nSweep keybind profile active\\nClick to use default bindings","class":"active"}\n'
    else
        printf '{"text":"","tooltip":"Sweep connected\\nDefault keybind profile active\\nClick to enable Sweep bindings","class":"inactive"}\n'
    fi
}

toggle_profile() {
    apply_profile
    if (( ! CONNECTED )); then
        write_preference 0
        apply_profile
        notify "Default profile" "Sweep is disconnected; its profile cannot be enabled."
        return 1
    fi
    if (( REQUESTED )); then
        write_preference 0
        apply_profile
        notify "Default profile active" "Sweep-specific Hyprland bindings are off."
    else
        write_preference 1
        apply_profile
        notify "Sweep profile active" "Thumb-friendly Hyprland bindings are on."
    fi
    signal_waybar
}

set_profile() {
    local value="$1"
    if [[ "$value" == 1 ]] && ! sweep_connected; then
        write_preference 0
        apply_profile
        notify "Default profile" "Sweep is disconnected; its profile cannot be enabled."
        return 1
    fi
    write_preference "$value"
    apply_profile
    signal_waybar
}

watch_state=""

sync_watched_state() {
    local current
    apply_profile
    current="$CONNECTED:$ACTIVE"
    if [[ "$current" != "$watch_state" ]]; then
        signal_waybar
        watch_state="$current"
    fi
}

is_relevant_bluez_event() {
    local event="$1"
    if [[ "$event" == *"$sweep_device_component"* ]] &&
       [[ "$event" == *Connected* || "$event" == *InterfacesAdded* || "$event" == *InterfacesRemoved* ]]; then
        return 0
    fi
    [[ "$event" == *"The name org.bluez "* ]]
}

monitor_bluez_once() {
    local coproc_fd event monitor_fd monitor_pid

    coproc SWEEP_BLUEZ_MONITOR { gdbus monitor --system --dest org.bluez 2>&1; }
    monitor_pid="$SWEEP_BLUEZ_MONITOR_PID"
    coproc_fd="${SWEEP_BLUEZ_MONITOR[0]}"
    exec {monitor_fd}<&"$coproc_fd"

    # Subscribe before reading the initial state so a connection transition in
    # between is queued by D-Bus rather than lost.
    sync_watched_state
    while IFS= read -r -u "$monitor_fd" event; do
        is_relevant_bluez_event "$event" || continue
        sync_watched_state
    done

    exec {monitor_fd}<&-
    wait "$monitor_pid" 2>/dev/null || true
}

watch_connection() {
    exec 9>"$runtime_home/sweep-profile.lock"
    flock -n 9 || exit 0
    command -v gdbus >/dev/null 2>&1 || {
        printf 'Sweep profile watcher requires gdbus (provided by GLib).\n' >&2
        exit 1
    }
    while true; do
        monitor_bluez_once
        sleep "$event_reconnect_delay"
    done
}

case "${1:-status}" in
    status) print_status ;;
    toggle) toggle_profile ;;
    on) set_profile 1 ;;
    off) set_profile 0 ;;
    sync) apply_profile ;;
    watch) watch_connection ;;
    *)
        printf 'Usage: %s {status|toggle|on|off|sync|watch}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
