#!/usr/bin/env bash
#
# Flutter SDK XDG-compliant installer
# Usage: ./install-flutter.sh [--force]
#

set -euo pipefail

# XDG directories
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Configuration
FLUTTER_VERSION="3.41.6"
DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
INSTALL_DIR="${XDG_DATA_HOME}/flutter"  # ~/.local/share/flutter
BIN_LINK_DIR="${XDG_BIN_HOME}"
CACHE_FILE="${XDG_CACHE_HOME}/flutter-${FLUTTER_VERSION}.tar.xz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
log_error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
log_step()    { echo -e "${BLUE}→${NC} $*"; }

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
  command -v xz >/dev/null 2>&1 || { log_error "xz is required (for .tar.xz)"; exit 1; }
  
  mkdir -p "$XDG_DATA_HOME" "$XDG_BIN_HOME" "$XDG_CACHE_HOME"
}

# Download with resume support
download() {
  if [[ -f "$CACHE_FILE" && "$FORCE" == "false" ]]; then
    log_info "Using cached archive: $CACHE_FILE"
    return 0
  fi
  
  log_step "Downloading Flutter ${FLUTTER_VERSION}..."
  curl -L -C - -o "$CACHE_FILE" "$DOWNLOAD_URL"
  
  if [[ ! -s "$CACHE_FILE" ]]; then
    log_error "Download failed or empty file"
    rm -f "$CACHE_FILE"
    exit 1
  fi
  log_info "Download complete: $(du -h "$CACHE_FILE" | cut -f1)"
}

# Install or update Flutter SDK
install() {
  if [[ -d "$INSTALL_DIR" && "$FORCE" == "false" ]]; then
    local current_version="$("$INSTALL_DIR/bin/flutter" --version 2>/dev/null | grep 'Flutter ' | awk '{print $2}' || echo 'unknown')"
    log_warn "Flutter ${current_version} already installed at $INSTALL_DIR"
    log_warn "Use --force to reinstall version ${FLUTTER_VERSION}"
    return 0
  fi
  
  log_step "Extracting to $INSTALL_DIR..."
  
  # Backup existing installation
  if [[ -d "$INSTALL_DIR" ]]; then
    local backup="${INSTALL_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    log_warn "Backing up to $backup"
    mv "$INSTALL_DIR" "$backup"
  fi
  
  # Extract (tarball contains flutter/ directory)
  tar -xf "$CACHE_FILE" -C "$XDG_DATA_HOME"
  
  # Verify extraction
  if [[ ! -f "${INSTALL_DIR}/bin/flutter" ]]; then
    log_error "Extraction failed: flutter binary not found"
    exit 1
  fi
  
  log_info "Installed Flutter ${FLUTTER_VERSION}: $INSTALL_DIR"
}

# Create symlinks for flutter/dart commands
create_symlinks() {
  local flutter_bin="${INSTALL_DIR}/bin"
  
  for cmd in flutter dart; do
    local link="${BIN_LINK_DIR}/${cmd}"
    local target="${flutter_bin}/${cmd}"
    
    if [[ -L "$link" && "$(readlink -f "$link")" == "$target" ]]; then
      log_info "Symlink already exists: $link"
      continue
    fi
    
    mkdir -p "$(dirname "$link")"
    ln -sf "$target" "$link"
    chmod +x "$link"
    log_info "Created symlink: $link → $target"
  done
}

# Print environment setup instructions
print_env_setup() {
  echo
  log_info "Environment setup instructions"
  echo
  echo "Add the following to your ~/.bashrc or ~/.zshrc:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo "  export FLUTTER_ROOT=\"${INSTALL_DIR}\""
  echo
  echo "Or for Home Manager (home.nix):"
  echo "  home.sessionVariables = {"
  echo "    FLUTTER_ROOT = \"${INSTALL_DIR}\";"
  echo "    PATH = [ \"\$HOME/.local/bin\" ];  # if not already set"
  echo "  };"
  echo
}

# Run flutter doctor and initial setup
run_setup() {
  echo
  log_step "Running initial Flutter setup..."
  echo
  
  # Disable analytics by default (privacy-friendly)
  "${INSTALL_DIR}/bin/flutter" config --no-analytics
  
  # Run doctor (may prompt for Android licenses)
  "${INSTALL_DIR}/bin/flutter" doctor
  
  echo
  log_warn "If you see 'Android license status unknown', run:"
  echo "  flutter doctor --android-licenses"
  echo
}

# Print post-install summary
post_install() {
  echo
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "Flutter ${FLUTTER_VERSION} installation complete!"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo "Quick start:"
  echo "  1. Reload your shell: exec \$SHELL"
  echo "  2. Verify installation: flutter --version"
  echo "  3. Check setup: flutter doctor"
  echo "  4. Accept Android licenses: flutter doctor --android-licenses"
  echo
  echo "Create a new project:"
  echo "  flutter create my_app"
  echo "  cd my_app"
  echo "  flutter run"
  echo
  echo "Troubleshooting:"
  echo "  • 'flutter' command not found → ensure ~/.local/bin is in PATH"
  echo "  • Android SDK not found → set ANDROID_HOME in home.nix"
  echo "  • Network errors → set SSL_CERT_FILE (see Home Manager config)"
  echo
  echo "Documentation: https://docs.flutter.dev"
  echo
}

# Main
main() {
  echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC} Flutter SDK XDG Installer ${FLUTTER_VERSION} ${BLUE}║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
  echo
  echo "  Install dir: $INSTALL_DIR"
  echo "  Bin dir:     $BIN_LINK_DIR"
  echo "  Cache:       $CACHE_FILE"
  echo
  
  check_prereqs
  download
  install
  create_symlinks
  print_env_setup
  run_setup
  post_install
}

main "$@"
