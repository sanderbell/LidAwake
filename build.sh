#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${SCRIPT_DIR}/Lid Awake.app"
EXECUTABLE="${APP_DIR}/Contents/MacOS/Lid Awake"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
ICONSET_DIR="${SCRIPT_DIR}/LidAwake.iconset"
ICON_FILE="${RESOURCES_DIR}/LidAwake.icns"

mkdir -p "${APP_DIR}/Contents/MacOS" "${RESOURCES_DIR}"

/usr/bin/xcrun swiftc \
  "${SCRIPT_DIR}/src/main.swift" \
  -o "${EXECUTABLE}" \
  -framework AppKit \
  -framework LocalAuthentication

/usr/bin/swift "${SCRIPT_DIR}/tools/make_icon.swift" "${SCRIPT_DIR}" >/dev/null
/usr/bin/iconutil -c icns "${ICONSET_DIR}" -o "${ICON_FILE}"

cp "${SCRIPT_DIR}/Info.plist" "${APP_DIR}/Contents/Info.plist"
chmod +x "${EXECUTABLE}"

echo "${APP_DIR}"
