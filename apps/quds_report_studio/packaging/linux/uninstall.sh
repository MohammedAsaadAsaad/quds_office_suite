#!/bin/sh
# Removes Quds Report Studio installed by install.sh (or registered by its
# first run) and the .qrep association. --purge also deletes its settings.
set -eu

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
PREFIX="$HOME/.local/opt/quds-report-studio"
DESKTOP_ID=com.quds.quds_report_studio.desktop

echo "Removing Quds Report Studio"
rm -f "$HOME/.local/bin/quds-report-studio"
rm -f "$DATA/applications/$DESKTOP_ID" "$DATA/mime/packages/quds-report-studio.xml"
for size in 16 24 32 48 64 128 256 512; do
  dir="$DATA/icons/hicolor/${size}x${size}"
  rm -f "$dir/apps/quds-report-studio.png" \
    "$dir/mimetypes/application-vnd.quds.qrep+zip.png"
done
for list in "$CONFIG/mimeapps.list" "$DATA/applications/mimeapps.list"; do
  if [ -f "$list" ]; then
    sed -i '/^application\/vnd\.quds\.qrep+zip=/d' "$list"
  fi
done

update-mime-database "$DATA/mime" >/dev/null 2>&1 || true
update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t "$DATA/icons/hicolor" >/dev/null 2>&1 || true

if [ "${1:-}" = "--purge" ]; then
  rm -rf "$CONFIG/quds_report_studio"
  echo "Settings and recent files deleted."
fi
rm -rf "$PREFIX"
echo "Quds Report Studio was uninstalled."
