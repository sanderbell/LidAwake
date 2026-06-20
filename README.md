# Lid Awake

Tiny macOS menu-bar app for choosing what happens when you close your Mac lid.

[Download Lid Awake for macOS](dist/Lid%20Awake.dmg)

Zip fallback: [Lid Awake.zip](dist/Lid%20Awake.zip)

## Install

1. Download and open `Lid Awake.dmg`.
2. Drag `Lid Awake.app` into Applications.
3. Open Lid Awake from Applications.
4. Use the menu-bar item to choose `Keep Awake` or `Allow Sleep`.
5. Optional: enable `Open at Login`.

If macOS blocks the first launch, right-click `Lid Awake.app` and choose `Open`.

## What It Does

- `Keep Awake`: closing the lid keeps the Mac awake.
- `Allow Sleep`: restores normal lid sleep.
- Touch ID is used when available.
- If Touch ID needs one-time setup, Lid Awake asks in plain language during the first toggle.
- That permission is limited to `/usr/bin/pmset -a disablesleep 0|1`.
- `Open at Login` starts Lid Awake automatically when you sign in.

## Menu

- `Keeping awake` / `Normal sleep`
- `Keep Awake` / `Allow Sleep`
- `Refresh`
- `Open at Login`
- `Quit Lid Awake`

## Notes

Lid Awake reads and updates macOS power settings with `pmset`. If you choose to enable Touch ID toggles, it installs `/etc/sudoers.d/lid-awake`, a small rule limited to toggling lid sleep on/off.
