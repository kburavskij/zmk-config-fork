# Sweep BlueZ event watcher

This optional desktop-side package mirrors the watcher shipped by the Hyprdots
repository. It keeps the Sweep keybind profile synchronized from BlueZ D-Bus
events without polling and signals Waybar with `RTMIN+12`.

Install the script and systemd user unit:

```sh
./tools/sweep-profile/install.sh
```

The installer backs up differing destination files and does not start the
service before Hyprland has exported its session environment. Add these lines
to the Hyprland startup configuration:

```ini
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
exec-once = systemctl --user restart sweep-profile.service
```

The existing Hyprland configuration must source
`~/.config/hypr/UserConfigs/ActiveKeybindProfile.conf` and provide the
`Default.conf` and `Sweep.conf` keybind profiles. The Waybar module must execute
`SweepProfile.sh status`, declare `"signal": 12`, and omit `interval`:

```jsonc
"custom/sweep_profile": {
    "return-type": "json",
    "exec": "$HOME/.config/hypr/UserScripts/SweepProfile.sh status",
    "signal": 12,
    "format": "{}",
    "on-click": "$HOME/.config/hypr/UserScripts/SweepProfile.sh toggle",
    "tooltip": true
}
```

Use `./tools/sweep-profile/install.sh --dry-run` to preview installation. The
complete matching Hyprland profiles, Waybar styling, and automated installer
are maintained in `hyprdots-current`.
