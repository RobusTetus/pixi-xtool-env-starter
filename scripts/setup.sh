#!/usr/bin/env bash
# Downloads the Swift toolchain and xtool into .pixi/tools (gitignored).
# Versions are pinned here, so the setup is reproducible from git.
# Run with: pixi run setup
set -euo pipefail

SWIFT_VERSION="6.4.2"
SWIFT_PLATFORM="ubi9"        # RHEL 9 build, works on Fedora
XTOOL_VERSION="latest"       # for full reproducibility, set a specific tag from GitHub Releases

TOOLS="$PIXI_PROJECT_ROOT/.pixi/tools"
SWIFT_DIR="$TOOLS/swift"
XTOOL_DIR="$TOOLS/xtool"
BIN="$TOOLS/bin"
mkdir -p "$TOOLS" "$BIN"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------- Swift ----------
if [[ -f "$SWIFT_DIR/.version" && "$(cat "$SWIFT_DIR/.version")" == "$SWIFT_VERSION" ]]; then
  echo "Swift $SWIFT_VERSION is already installed."
else
  NAME="swift-${SWIFT_VERSION}-RELEASE-${SWIFT_PLATFORM}"
  URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/${SWIFT_PLATFORM}/swift-${SWIFT_VERSION}-RELEASE/${NAME}.tar.gz"
  echo "Downloading $URL"
  curl -fL --progress-bar "$URL" -o "$TMP/swift.tar.gz"
  curl -fsSL "$URL.sig" -o "$TMP/swift.tar.gz.sig"

  export GNUPGHOME="$TMP/gnupg"; mkdir -m 700 "$GNUPGHOME"
  curl -fsSL --compressed https://www.swift.org/keys/all-keys.asc | gpg --quiet --import -
  gpg --verify "$TMP/swift.tar.gz.sig" "$TMP/swift.tar.gz"

  rm -rf "$SWIFT_DIR"; mkdir -p "$SWIFT_DIR"
  tar -xzf "$TMP/swift.tar.gz" -C "$SWIFT_DIR" --strip-components=1
  echo "$SWIFT_VERSION" > "$SWIFT_DIR/.version"
fi

# ---------- xtool ----------
if [[ -f "$XTOOL_DIR/.version" && "$(cat "$XTOOL_DIR/.version")" == "$XTOOL_VERSION" && "$XTOOL_VERSION" != "latest" ]] \
   || [[ "$XTOOL_VERSION" == "latest" && -x "$XTOOL_DIR/AppRun" && "${FORCE_XTOOL:-0}" != 1 ]]; then
  echo "xtool is already installed."
else
  if [[ "$XTOOL_VERSION" == "latest" ]]; then
    URL="https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage"
  else
    URL="https://github.com/xtool-org/xtool/releases/download/${XTOOL_VERSION}/xtool-$(uname -m).AppImage"
  fi
  echo "Downloading $URL"
  curl -fL --progress-bar "$URL" -o "$TMP/xtool.AppImage"
  chmod +x "$TMP/xtool.AppImage"
  (cd "$TMP" && ./xtool.AppImage --appimage-extract >/dev/null)   # no FUSE required
  rm -rf "$XTOOL_DIR"; mv "$TMP/squashfs-root" "$XTOOL_DIR"
  echo "$XTOOL_VERSION" > "$XTOOL_DIR/.version"
fi

cat > "$BIN/xtool" <<EOF
#!/usr/bin/env bash
exec "$XTOOL_DIR/AppRun" "\$@"
EOF
chmod +x "$BIN/xtool"

# re-source activation so symlinks to the freshly downloaded toolchain get created
source "$PIXI_PROJECT_ROOT/scripts/activate.sh"

swift --version
echo "Done."
