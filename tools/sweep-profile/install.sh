#!/usr/bin/env bash
set -euo pipefail

readonly source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly target_home="${HOME:?HOME must be set}"
readonly config_home="${XDG_CONFIG_HOME:-$target_home/.config}"
readonly script_target="$config_home/hypr/UserScripts/SweepProfile.sh"
readonly unit_target="$config_home/systemd/user/sweep-profile.service"
readonly timestamp="$(date +%Y%m%d-%H%M%S)"
dry_run=0

case "${1:-}" in
    "") ;;
    --dry-run) dry_run=1 ;;
    -h|--help)
        printf 'Usage: %s [--dry-run]\n' "${0##*/}"
        exit 0
        ;;
    *)
        printf 'Unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

run() {
    if (( dry_run )); then
        printf '  '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

backup_if_changed() {
    local target="$1"
    [[ -e "$target" ]] || return 0
    cmp -s -- "$source_dir/$(basename -- "$target")" "$target" && return 0
    run cp -a -- "$target" "$target.backup-$timestamp"
}

for command_name in bluetoothctl flock gdbus hyprctl pkill systemctl timeout; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    }
done

backup_if_changed "$script_target"
backup_if_changed "$unit_target"
run mkdir -p "$(dirname -- "$script_target")" "$(dirname -- "$unit_target")"
run install -m 0755 "$source_dir/SweepProfile.sh" "$script_target"
run install -m 0644 "$source_dir/sweep-profile.service" "$unit_target"
run systemctl --user daemon-reload

if (( dry_run )); then
    printf '\nDry run complete; no files were changed.\n'
else
    printf '\nInstalled the Sweep BlueZ event watcher.\n'
fi
printf 'Add the Hyprland startup lines and signal-only Waybar module documented in %s.\n' \
    "$source_dir/README.md"
