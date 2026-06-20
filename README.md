# Lid Awake

Tiny macOS menu-bar app for choosing what happens when you close your Mac lid.

[Download Lid Awake for macOS](dist/Lid%20Awake.dmg)

Zip fallback: [Lid Awake.zip](dist/Lid%20Awake.zip)

## Install

1. Download and open `Lid Awake.dmg`.
2. Drag `Lid Awake.app` into Applications.
3. Open Lid Awake from Applications.
4. Use the menu-bar item to choose `Keep Awake` or `Allow Sleep`.

If macOS blocks the first launch, right-click `Lid Awake.app` and choose `Open`.

## What It Does

- `Keep Awake`: closing the lid keeps the Mac awake.
- `Allow Sleep`: restores normal lid sleep.
- Touch ID is used when available.
- The helper permission is limited to toggling lid sleep on/off.

## Menu

- `Keeping awake` / `Normal sleep`
- `Keep Awake` / `Allow Sleep`
- `Refresh`
- `Set Up Helper...`
- `Quit Lid Awake`

## Notes

Lid Awake reads and updates macOS power settings with `pmset`. On first setup it may ask for permission so future toggles can use Touch ID instead of a password.
