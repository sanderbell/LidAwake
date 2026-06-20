#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="${SCRIPT_DIR}/Lid Awake.app"
DIST_DIR="${SCRIPT_DIR}/dist"
ZIP_PATH="${DIST_DIR}/Lid Awake.zip"
DMG_PATH="${DIST_DIR}/Lid Awake.dmg"
DMG_ROOT="${DIST_DIR}/dmg-root"

"${SCRIPT_DIR}/build.sh" >/dev/null

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

/usr/bin/codesign --force --deep --sign - "${APP_PATH}" >/dev/null
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

mkdir -p "${DMG_ROOT}"
/usr/bin/ditto "${APP_PATH}" "${DMG_ROOT}/Lid Awake.app"
ln -s /Applications "${DMG_ROOT}/Applications"
/usr/bin/hdiutil create -volname "Lid Awake" -srcfolder "${DMG_ROOT}" -ov -format UDZO "${DMG_PATH}" >/dev/null
rm -rf "${DMG_ROOT}"

echo "${ZIP_PATH}"
echo "${DMG_PATH}"
