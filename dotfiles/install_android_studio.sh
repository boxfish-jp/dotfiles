#!/usr/bin/env bash
#
# Android Studio XDG-compliant installer
# Usage: ./install-android-studio.sh [--force]
#

set -euo pipefail

# XDG directories
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Configuration
DOWNLOAD_URL="https://edgedl.me.gvt1.com/android/studio/ide-zips/2025.3.3.7/android-studio-panda3-patch1-linux.tar.gz"
INSTALL_DIR="${XDG_DATA_HOME}/android-studio"
SDK_DIR="$HOME/Android/Sdk"  # Flutter convention
BIN_LINK="${XDG_BIN_HOME}/android-studio"
DESKTOP_FILE="${XDG_DATA_HOME}/applications/android-studio.desktop"
CACHE_FILE="${XDG_CACHE_HOME}/android-studio-install.tar.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()    { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
log_error()   { echo -e "${RED}[✗]${NC} $*" >&2; }

# Parse arguments
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
  log_warn "Force mode: will overwrite existing installation"
fi

# Check prerequisites
check_prereqs() {
  command -v curl >/dev/null 2>&1 || { log_error "curl is required"; exit 1; }
  command -v tar >/dev/null 2>&1 || { log_error "tar is required"; exit 1; }
  
  # Create required directories
  mkdir -p "$XDG_DATA_HOME" "$XDG_BIN_HOME" "$XDG_CACHE_HOME" "$(dirname "$SDK_DIR")"
}

# Download with resume support
download() {
  if [[ -f "$CACHE_FILE" && "$FORCE" == "false" ]]; then
    log_info "Using cached archive: $CACHE_FILE"
    return 0
  fi
  
  log_info "Downloading Android Studio..."
  curl -L -C - -o "$CACHE_FILE" "$DOWNLOAD_URL"
  
  # Verify download
  if [[ ! -s "$CACHE_FILE" ]]; then
    log_error "Download failed or empty file"
    rm -f "$CACHE_FILE"
    exit 1
  fi
  log_info "Download complete: $(du -h "$CACHE_FILE" | cut -f1)"
}

# Install or update
install() {
  if [[ -d "$INSTALL_DIR" && "$FORCE" == "false" ]]; then
    log_warn "Android Studio already installed at $INSTALL_DIR"
    log_warn "Use --force to reinstall"
    return 0
  fi
  
  log_info "Extracting to $INSTALL_DIR..."
  
  # Backup existing installation
  if [[ -d "$INSTALL_DIR" ]]; then
    local backup="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    log_warn "Backing up to $backup"
    mv "$INSTALL_DIR" "$backup"
  fi
  
  # Extract (tarball contains android-studio/ directory)
  tar -xzf "$CACHE_FILE" -C "$XDG_DATA_HOME"
  
  # Verify extraction
  if [[ ! -f "${INSTALL_DIR}/bin/studio.sh" ]]; then
    log_error "Extraction failed: studio.sh not found"
    exit 1
  fi
  
  log_info "Installed: $INSTALL_DIR"
}

# Create symlink in PATH
create_symlink() {
  if [[ -L "$BIN_LINK" && "$(readlink -f "$BIN_LINK")" == "${INSTALL_DIR}/bin/studio.sh" ]]; then
    log_info "Symlink already exists: $BIN_LINK"
    return 0
  fi
  
  mkdir -p "$(dirname "$BIN_LINK")"
  ln -sf "${INSTALL_DIR}/bin/studio.sh" "$BIN_LINK"
  chmod +x "$BIN_LINK"
  log_info "Created symlink: $BIN_LINK"
}

# Register desktop entry for KDE/GNOME
create_desktop_entry() {
  cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Comment=The official Android IDE
Exec=${INSTALL_DIR}/bin/studio.sh %F
Icon=${INSTALL_DIR}/bin/studio.png
Categories=Development;IDE;Java;
Keywords=android;development;ide;
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-studio
MimeType=application/x-extension-java;
EOF
  
  # Update desktop database (may require sudo, but usually works for user dirs)
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${XDG_DATA_HOME}/applications" 2>/dev/null || true
  fi
  
  log_info "Desktop entry created: $DESKTOP_FILE"
}

# Print post-install instructions
post_install() {
  echo
  log_info "Installation complete!"
  echo
  echo "Next steps:"
  echo "  1. Ensure ~/.local/bin is in your PATH:"
  echo "     echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
  echo
  echo "  2. Start Android Studio:"
  echo "     android-studio"
  echo
  echo "  3. On first launch, set SDK location to: ${SDK_DIR}"
  echo
  echo "  4. For Flutter integration, add to your home.nix:"
  echo "     home.sessionVariables.ANDROID_HOME = \"${SDK_DIR}\";"
  echo
  echo "Troubleshooting:"
  echo "  • If 'android-studio' command not found: exec \$SHELL or source ~/.bashrc"
  echo "  • If emulator fails: ensure KVM is enabled (sudo usermod -aG kvm \$USER)"
  echo "  • If USB device not detected: sudo apt install android-udev-rules"
  echo
}

# Main
main() {
  log_info "Android Studio XDG Installer"
  echo "  Install dir: $INSTALL_DIR"
  echo "  SDK dir:     $SDK_DIR"
  echo "  Binary:      $BIN_LINK"
  echo
  
  check_prereqs
  download
  install
  create_symlink
  create_desktop_entry
  post_install
}

main "$@"
