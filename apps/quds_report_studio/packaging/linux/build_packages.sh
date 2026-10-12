#!/usr/bin/env bash
# Runs `flutter build linux --release` and packages the bundle as
#   quds-report-studio_<version>_<arch>.deb   (apt install / apt remove)
#   QudsReportStudio-<version>-linux-<arch>.tar.gz (install.sh / uninstall.sh)
#
# Usage: packaging/linux/build_packages.sh [out-dir]   (from apps/quds_report_studio)
# Set SKIP_FLUTTER_BUILD=1 to package the existing bundle as is.
set -euo pipefail

APP="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="$APP/packaging/linux"
VERSION=$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' "$APP/pubspec.yaml")
case "$(uname -m)" in
  x86_64) FLUTTER_ARCH=x64; DEB_ARCH=amd64 ;;
  aarch64) FLUTTER_ARCH=arm64; DEB_ARCH=arm64 ;;
  *) echo "unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac
BUNDLE="$APP/build/linux/$FLUTTER_ARCH/release/bundle"
OUT="$(mkdir -p "${1:-$APP/build/dist}" && cd "${1:-$APP/build/dist}" && pwd)"
if [ "${SKIP_FLUTTER_BUILD:-0}" != 1 ]; then
  (cd "$APP" && flutter build linux --release)
fi
[ -x "$BUNDLE/quds_report_studio" ] || {
  echo "missing $BUNDLE; run: flutter build linux --release" >&2
  exit 1
}
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- .deb ------------------------------------------------------------------
ROOT="$WORK/deb"
OPT="$ROOT/opt/quds-report-studio"
mkdir -p "$OPT" "$ROOT/usr/bin" "$ROOT/usr/share/applications" \
  "$ROOT/usr/share/mime/packages" "$ROOT/usr/share/doc/quds-report-studio" \
  "$ROOT/DEBIAN"
cp -a "$BUNDLE/." "$OPT/"
ln -s /opt/quds-report-studio/quds_report_studio "$ROOT/usr/bin/quds-report-studio"
sed 's|@EXEC@|/opt/quds-report-studio/quds_report_studio|' \
  "$PKG/com.quds.quds_report_studio.desktop.in" \
  > "$ROOT/usr/share/applications/com.quds.quds_report_studio.desktop"
cp "$PKG/quds-report-studio.xml" "$ROOT/usr/share/mime/packages/"
for size in 16 24 32 48 64 128 256 512; do
  dir="$ROOT/usr/share/icons/hicolor/${size}x${size}"
  mkdir -p "$dir/apps" "$dir/mimetypes"
  cp "$PKG/icons/apps/$size.png" "$dir/apps/quds-report-studio.png"
  cp "$PKG/icons/mimetypes/$size.png" \
    "$dir/mimetypes/application-vnd.quds.qrep+zip.png"
done
cp "$APP/../../packages/quds_office_engine/LICENSE" \
  "$ROOT/usr/share/doc/quds-report-studio/copyright"

find "$ROOT" -type d -exec chmod 755 {} +
find "$ROOT" -type f -exec chmod 644 {} +
chmod 755 "$OPT/quds_report_studio"
find "$OPT/lib" -name '*.so' -exec chmod 755 {} +

cat > "$ROOT/DEBIAN/control" <<EOF
Package: quds-report-studio
Version: $VERSION
Architecture: $DEB_ARCH
Maintainer: Mohammed Asaad Asaad <mohammed.asaad.asaad@users.noreply.github.com>
Installed-Size: $(du -sk "$ROOT" --exclude=DEBIAN | cut -f1)
Depends: libgtk-3-0t64 | libgtk-3-0, libglib2.0-0t64 | libglib2.0-0, libepoxy0, libstdc++6, libc6
Recommends: zenity | kdialog, xdg-utils, shared-mime-info, desktop-file-utils
Section: office
Priority: optional
Homepage: https://github.com/MohammedAsaadAsaad/quds_office_suite/tree/main/apps/quds_report_studio
Description: Desktop designer for .qrep band reports
 Quds Report Studio designs, previews and exports .qrep band reports (PDF,
 XLSX, DOCX) with Arabic RTL support, ready-made bilingual templates, embedded
 images and fonts, and a data explorer. Opens .qrep files from the file
 manager.
EOF
cat > "$ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
update-mime-database /usr/share/mime >/dev/null 2>&1 || true
update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
exit 0
EOF
cp "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"
chmod 755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"
DEB="$OUT/quds-report-studio_${VERSION}_${DEB_ARCH}.deb"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$DEB" >/dev/null
echo "built $DEB"

# --- portable .tar.gz ----------------------------------------------------------
NAME="QudsReportStudio-$VERSION-linux-$FLUTTER_ARCH"
TAR_ROOT="$WORK/$NAME"
mkdir -p "$TAR_ROOT/app" "$TAR_ROOT/share/icons"
cp -a "$BUNDLE/." "$TAR_ROOT/app/"
cp "$PKG/install.sh" "$PKG/uninstall.sh" "$TAR_ROOT/"
cp "$PKG/com.quds.quds_report_studio.desktop.in" "$PKG/quds-report-studio.xml" \
  "$TAR_ROOT/share/"
cp -a "$PKG/icons/apps" "$PKG/icons/mimetypes" "$TAR_ROOT/share/icons/"
cat > "$TAR_ROOT/README.txt" <<EOF
Quds Report Studio $VERSION for Linux ($FLUTTER_ARCH)

Install for the current user (no root needed):   ./install.sh
Uninstall:                                       ./uninstall.sh  (add --purge to delete settings)

Or run it in place: ./app/quds_report_studio
On its first run the studio becomes the default app for .qrep files.
EOF
chmod 755 "$TAR_ROOT/install.sh" "$TAR_ROOT/uninstall.sh" "$TAR_ROOT/app/quds_report_studio"
TAR="$OUT/$NAME.tar.gz"
tar -C "$WORK" -czf "$TAR" "$NAME"
echo "built $TAR"
