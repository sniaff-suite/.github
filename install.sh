#!/usr/bin/env bash
################################################################################
# Sniaff Static MCP - System-Wide Installation Script
################################################################################
# Installs all static analysis tools system-wide
#
# Usage:
#   sudo bash install.sh
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

TMP_DIR="/tmp/sniaff-install-$$"

# Specific versions for custom installations
APKTOOL_VERSION="2.9.3"
JADX_VERSION="1.5.0"

################################################################################
# Logging Functions
################################################################################

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log_section() {
    echo ""
    echo "============================================"
    echo "  $*"
    echo "============================================"
}

log_error() {
    echo "[ERROR] $*" >&2
}

################################################################################
# APT Installation
################################################################################

install_apt_packages() {
    log_section "Installing Base Tools via APT"

    log "Updating package list..."
    sudo apt-get update -qq

    log "Installing base tools and dependencies..."
    # Set DEBIAN_FRONTEND to avoid interactive prompts
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        openjdk-17-jdk-headless \
        python3 python3-pip \
        wget curl unzip zip \
        binutils file \
        jq \
        protobuf-compiler \
        git build-essential pkg-config \
        meson ninja-build \
        patch \
        zlib1g-dev \
        ripgrep \
        tshark \
        mitmproxy

    log "✓ Base tools installed via apt"
}

################################################################################
# Python Global Packages (for both CLI and import)
################################################################################

install_python_packages() {
    log_section "Installing Python Packages Globally"

    log "Installing r2pipe (Python library for radare2)..."
    pip3 install --break-system-packages --ignore-installed r2pipe

    log "Installing pyshark (Python wrapper for tshark)..."
    pip3 install --break-system-packages --ignore-installed pyshark

    log "✓ r2pipe installed (Python module)"
    log "✓ pyshark installed (Python module)"
    log "✓ Python modules available for scripting"
}

################################################################################
# radare2 Installation
################################################################################

install_radare2() {
    log_section "Installing radare2 from Source"

    log "Cloning radare2 repository..."
    cd /tmp
    rm -rf radare2
    git clone --depth 1 https://github.com/radareorg/radare2

    log "Running radare2 installation script (this will take 5-10 minutes)..."
    log "Note: sys/install.sh will ask for sudo password when needed"
    cd /tmp/radare2
    sys/install.sh

    log "✓ radare2 installed"
}

################################################################################
# r2ghidra Plugin Installation
################################################################################

install_r2ghidra() {
    log_section "Installing r2ghidra Plugin"

    log "Updating r2pm package database..."
    r2pm -U || true

    log "Installing r2ghidra plugin (with global flag, may take a few minutes)..."
    r2pm -g -ci r2ghidra || true

    log "Installing r2ghidra-sleigh decompiler..."
    r2pm -g -ci r2ghidra-sleigh || true

    log "✓ r2ghidra and r2ghidra-sleigh plugins installed"
}

################################################################################
# Custom Tool Installations
################################################################################

install_apktool() {
    log_section "Installing apktool v${APKTOOL_VERSION}"

    sudo wget -q https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar \
        -O /usr/local/bin/apktool.jar

    sudo tee /usr/local/bin/apktool > /dev/null <<'EOF'
#!/bin/bash
java -jar /usr/local/bin/apktool.jar "$@"
EOF

    sudo chmod +x /usr/local/bin/apktool
    log "✓ apktool installed"
}

install_jadx() {
    log_section "Installing jadx v${JADX_VERSION}"

    wget -q https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip \
        -O "$TMP_DIR/jadx.zip"

    sudo mkdir -p /opt/jadx
    sudo unzip -q "$TMP_DIR/jadx.zip" -d /opt/jadx

    sudo tee /usr/local/bin/jadx > /dev/null <<'EOF'
#!/bin/bash
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
else
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
fi
exec /opt/jadx/bin/jadx "$@"
EOF

    sudo chmod +x /usr/local/bin/jadx
    log "✓ jadx installed"
}

install_apksigner() {
    log_section "Installing apksigner"

    wget -q https://dl.google.com/android/repository/build-tools_r34-linux.zip \
        -O "$TMP_DIR/build-tools.zip"

    unzip -q "$TMP_DIR/build-tools.zip" -d "$TMP_DIR/build-tools-tmp"

    sudo mkdir -p /opt/android-tools
    sudo cp "$TMP_DIR/build-tools-tmp/android-14/lib/apksigner.jar" \
        /opt/android-tools/ 2>/dev/null || true

    sudo tee /usr/local/bin/apksigner > /dev/null <<'EOF'
#!/bin/bash
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
else
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
fi
java -jar /opt/android-tools/apksigner.jar "$@"
EOF

    sudo chmod +x /usr/local/bin/apksigner
    log "✓ apksigner installed"
}

################################################################################
# Verification
################################################################################

verify_installation() {
    log_section "Verifying Installation"

    local failed=0

    verify_tool() {
        local tool=$1
        local version_cmd=$2

        if ! command -v "$tool" &>/dev/null; then
            log_error "✗ $tool: NOT FOUND"
            ((failed++))
            return 1
        fi

        local version=$($version_cmd 2>&1 | head -1 || echo "installed")
        log "✓ $tool: $version"
    }

    verify_tool "rg" "rg --version"
    verify_tool "apktool" "apktool --version"
    verify_tool "jadx" "jadx --version"
    verify_tool "r2" "r2 -v"
    verify_tool "radare2" "radare2 -v"
    verify_tool "apksigner" "apksigner --version"
    verify_tool "jq" "jq --version"
    verify_tool "java" "java -version"
    verify_tool "python3" "python3 --version"
    verify_tool "tshark" "tshark --version"
    verify_tool "mitmproxy" "mitmproxy --version"
    verify_tool "mitmdump" "mitmdump --version"

    # Verify Python modules
    log "Checking Python modules..."
    if python3 -c "import r2pipe" 2>/dev/null; then
        log "✓ r2pipe: module available"
    else
        log_error "✗ r2pipe: module NOT found"
        ((failed++))
    fi


    if python3 -c "import pyshark" 2>/dev/null; then
        log "✓ pyshark: module available"
    else
        log_error "✗ pyshark: module NOT found"
        ((failed++))
    fi

    if python3 -c "import mitmproxy" 2>/dev/null; then
        log "✓ mitmproxy: module available"
    else
        log_error "✗ mitmproxy: module NOT found"
        ((failed++))
    fi

    # Check r2ghidra plugins
    if r2pm -l 2>/dev/null | grep -q r2ghidra; then
        log "✓ r2ghidra plugin: installed"
    else
        log "⚠ r2ghidra plugin: NOT FOUND (optional)"
    fi

    if r2pm -l 2>/dev/null | grep -q r2ghidra-sleigh; then
        log "✓ r2ghidra-sleigh plugin: installed"
    else
        log "⚠ r2ghidra-sleigh plugin: NOT FOUND (optional)"
    fi

    echo ""
    if [ $failed -eq 0 ]; then
        log "✓✓✓ All tools verified successfully"
        return 0
    else
        log_error "✗✗✗ $failed tool(s) failed verification"
        return 1
    fi
}

################################################################################
# Cleanup
################################################################################

cleanup() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

################################################################################
# Main Installation Flow
################################################################################

main() {
    log_section "Sniaff Static MCP - System-Wide Installation"

    mkdir -p "$TMP_DIR"

    # Install base tools via apt
    install_apt_packages

    # Install radare2 from source (must be before r2pipe)
    install_radare2

    # Install Python packages globally
    install_python_packages

    # Install r2ghidra plugin
    install_r2ghidra

    # Install custom tools
    install_apktool
    install_jadx
    install_apksigner

    # Verify everything works
    verify_installation

    log_section "Installation Complete!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ All tools installed system-wide!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Installed tools (available globally):"
    echo "  - radare2 (from git)"
    echo "  - r2ghidra + r2ghidra-sleigh plugins"
    echo "  - mitmproxy, mitmdump, mitmweb (via pip)"
    echo "  - tshark (Wireshark CLI, from apt)"
    echo "  - ripgrep (from apt)"
    echo "  - apktool v${APKTOOL_VERSION}"
    echo "  - jadx v${JADX_VERSION}"
    echo "  - apksigner (Android build-tools r34)"
    echo "  - jq, protobuf-compiler"
    echo ""
    echo "All tools are in PATH and ready to use!"
    echo ""
    echo "Python modules available for scripting:"
    echo "  - import r2pipe     (radare2 Python bindings)"
    echo "  - import mitmproxy  (mitmproxy addons/scripts)"
    echo "  - import pyshark    (tshark/Wireshark Python wrapper)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
