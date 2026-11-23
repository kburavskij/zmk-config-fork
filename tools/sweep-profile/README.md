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

The watcher updates both selectors in `~/.config/hypr/UserConfigs`. Native Lua
loads `ActiveKeybindProfile.lua` from `hyprlua/binds.lua`. The legacy
configuration sources `ActiveKeybindProfile.conf`, which selects
`KeybindProfiles/Default.conf` or `KeybindProfiles/Sweep.conf`. The Waybar module must execute
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

## Sweep firmware shortcuts in Hyprland

If your desktop already switches to the Sweep profile on Bluetooth connect,
keep its installed watcher. Apply `hyprland-keybinds.patch` from this
repository to the Hyprland config directory. It adds the firmware shortcuts to
`hyprlua/binds_sweep.lua` and `UserConfigs/KeybindProfiles/Sweep.conf`, and updates
the shared workspace and dropdown terminal helpers for both formats.

```sh
patch --forward --dry-run -p1 -d "$HOME/.config/hypr" < tools/sweep-profile/hyprland-keybinds.patch
patch --forward -p1 -d "$HOME/.config/hypr" < tools/sweep-profile/hyprland-keybinds.patch
hyprctl reload
```

Hold the Space thumb for arrows on H, J, K, and L. Hold Backspace for numbers
and symbols. While the Sweep profile is active, Space with N returns to the
last window, M toggles the dropdown Kitty terminal, and comma opens a new
terminal. For directional window controls, hold Space and D for Super, then
press an arrow to focus. Add F for Shift to move, or A for Control to resize.
Super with a number opens a workspace slot, and adding Shift moves a window
to it.

Hold Space and Backspace together to reach the function layer. J selects Linux,
K selects macOS, and L selects Windows. The firmware starts in Linux mode and
the choice applies to the current power cycle. On macOS and Windows, Space with
N sends the native app-switch shortcut. The desktop's Bluetooth profile
switcher operates separately.
