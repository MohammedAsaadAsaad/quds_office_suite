#!/bin/sh
# Installs Quds Report Studio for the current user (no root needed) and makes
# it the default app for .qrep files. Remove it with uninstall.sh.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
PREFIX="$HOME/.local/opt/quds-report-studio"
BIN="$HOME/.local/bin"
DESKTOP_ID=com.quds.quds_report_studio.desktop
MIME=application/vnd.quds.qrep+zip

echo "Installing Quds Report Studio to $PREFIX"
rm -rf "$PREFIX"
mkdir -p "$PREFIX" "$BIN" "$DATA/applications" "$DATA/mime/packages"
cp -a "$HERE/app/." "$PREFIX/"
cp "$HERE/uninstall.sh" "$PREFIX/uninstall.sh"
chmod 755 "$PREFIX/quds_report_studio" "$PREFIX/uninstall.sh"
ln -sf "$PREFIX/quds_report_studio" "$BIN/quds-report-studio"

sed "s|@EXEC@|\"$PREFIX/quds_report_studio\"|" \
  "$HERE/share/com.quds.quds_report_studio.desktop.in" \
  > "$DATA/applications/$DESKTOP_ID"
cp "$HERE/share/quds-report-studio.xml" "$DATA/mime/packages/"
for size in 16 24 32 48 64 128 256 512; do
  dir="$DATA/icons/hicolor/${size}x${size}"
  mkdir -p "$dir/apps" "$dir/mimetypes"
  cp "$HERE/share/icons/apps/$size.png" "$dir/apps/quds-report-studio.png"
  cp "$HERE/share/icons/mimetypes/$size.png" \
    "$dir/mimetypes/application-vnd.quds.qrep+zip.png"
done

update-mime-database "$DATA/mime" >/dev/null 2>&1 || true
update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t "$DATA/icons/hicolor" >/dev/null 2>&1 || true
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$CONFIG" && touch "$CONFIG/mimeapps.list"
xdg-mime default "$DESKTOP_ID" "$MIME" >/dev/null 2>&1 || true

echo "Done. Start it from the app menu, run quds-report-studio, or open any .qrep file."
echo "Uninstall: $PREFIX/uninstall.sh"
