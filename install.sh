#!/usr/bin/env bash
#
# Acunetix installation and configuration script
# ByCh4n | Cyber Security Expert
#
# To target a new release, change only the BUILD / VERSION_SHORT
# variables below; every path is derived from them.

set -uo pipefail

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
readonly VERSION_SHORT="25.1"
readonly BUILD="250204093"
readonly ARCHIVE_PASSWORD="Pwn3rzs"
readonly DOWNLOAD_BASE="https://pwn3rzs.co/scanner_web/acunetix"

readonly ARCHIVE_NAME="Acunetix-v${VERSION_SHORT}.${BUILD}-Linux-Pwn3rzs-CyberArsenal.7z"
readonly INSTALLER_NAME="acunetix_${VERSION_SHORT}.${BUILD}_x64.sh"
readonly ACUNETIX_HOME="/home/acunetix/.acunetix"
readonly SCANNER_DIR="${ACUNETIX_HOME}/v_${BUILD}/scanner"
readonly LICENSE_DIR="${ACUNETIX_HOME}/data/license"
readonly ACCESS_PORT="3443"

# ----------------------------------------------------------------------
# Colors and logging helpers
# ----------------------------------------------------------------------
if [ -t 1 ]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# Remove downloaded temporary files on exit
cleanup_tmp() {
    rm -f "${ARCHIVE_NAME}" "${INSTALLER_NAME}" install.log \
          license_info.json wa_data.dat wvsc README.txt 2>/dev/null || true
}

usage() {
    cat <<EOF
Usage: sudo ./install.sh [option]

Options:
  -h, --help      Show this help message
  -v, --version   Show the targeted Acunetix version

With no arguments it runs the full installation flow:
  dependencies -> hosts -> download/install -> licensing -> cleanup
EOF
}

# ----------------------------------------------------------------------
# Pre-flight checks
# ----------------------------------------------------------------------
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root! (sudo ./install.sh)"
    fi
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || error "Required command not found: '${cmd}'."
}

banner() {
    clear
    cat << "EOF"
  ___  _  _  ____  _  _  ___  _____  _  _  ____
 / __)( \/ )( ___)( \( )/ __)(  _  )( \( )( ___)
( (__  \  /  )__)  )  (( (_-. )(_)(  )  (  )__)
 \___)  \/  (____)(_)\_)\___/(_____)(_)\_)(____)

      Acunetix Auto Installer & Patcher
      ByCh4n | Cyber Security Expert
------------------------------------------------
EOF
}

# ----------------------------------------------------------------------
# 1. Install dependencies
# ----------------------------------------------------------------------
# Debian 13 / Ubuntu 24.04 renamed several libraries with a "t64" suffix,
# so try the plain name first and fall back to the t64 variant.
install_pkg() {
    local pkg="$1"
    if apt-get install -y "$pkg" >>install.log 2>&1; then
        return 0
    fi
    if apt-get install -y "${pkg}t64" >>install.log 2>&1; then
        return 0
    fi
    return 1
}

install_dependencies() {
    info "Updating the system and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    : > install.log

    if ! apt-get update -qq >>install.log 2>&1; then
        error "apt-get update failed. Check your internet connection / repositories."
    fi

    local dependencies=(
        p7zip-full libxcomposite1 libcups2 libasound2 libatk1.0-0 libgbm1
        libxfixes3 libcairo2 libxrandr2 libxkbcommon0 libatk-bridge2.0-0
        libxdamage1 libatspi2.0-0 wget curl systemd
    )

    local failed=()
    local pkg
    for pkg in "${dependencies[@]}"; do
        if install_pkg "$pkg"; then
            echo -e "   ${GREEN}+${NC} ${pkg}"
        else
            echo -e "   ${RED}-${NC} ${pkg}"
            failed+=("$pkg")
        fi
    done

    if [ "${#failed[@]}" -gt 0 ]; then
        error "Failed to install: ${failed[*]} (details in install.log)"
    fi
    success "All dependencies installed."
}

# ----------------------------------------------------------------------
# 2. Update the hosts file
# ----------------------------------------------------------------------
add_host_entry() {
    local ip="$1"
    local domain="$2"
    if grep -q "[[:space:]]${domain}\$" /etc/hosts 2>/dev/null; then
        echo -e "   ${YELLOW}*${NC} Present: ${domain}"
    else
        echo "${ip}  ${domain}" >> /etc/hosts
        echo -e "   ${GREEN}+${NC} Added: ${domain}"
    fi
}

update_hosts() {
    info "Configuring /etc/hosts..."

    if [ ! -f /etc/hosts.original ]; then
        cp /etc/hosts /etc/hosts.original
        success "Original hosts file backed up (/etc/hosts.original)"
    fi

    echo -e "\n# Acunetix blocks (ByCh4n script)" >> /etc/hosts

    local domains=(
        "erp.acunetix.com"
        "discovery-service.invicti.com"
        "cdn.pendo.io"
        "bxss.me"
        "jwtsigner.invicti.com"
        "sca.acunetix.com"
        "telemetry.invicti.com"
    )

    local domain
    for domain in "${domains[@]}"; do
        if [ "$domain" = "telemetry.invicti.com" ]; then
            add_host_entry "192.178.49.174" "$domain"
        else
            add_host_entry "127.0.0.1" "$domain"
        fi
    done
    for domain in "${domains[@]}"; do
        if [ "$domain" = "telemetry.invicti.com" ]; then
            add_host_entry "2607:f8b0:402a:80a::200e" "$domain"
        else
            add_host_entry "::1" "$domain"
        fi
    done

    success "hosts file updated."
}

# ----------------------------------------------------------------------
# 3. Download and install
# ----------------------------------------------------------------------
install_acunetix() {
    info "Downloading Acunetix (${ARCHIVE_NAME})..."
    if [ ! -f "$ARCHIVE_NAME" ]; then
        if ! wget -q --show-progress "${DOWNLOAD_BASE}/${ARCHIVE_NAME}"; then
            error "Download failed! The link may be broken or there is no internet."
        fi
    else
        warning "Archive already exists, skipping download."
    fi
    [ -f "$ARCHIVE_NAME" ] || error "Archive file not found."

    info "Extracting archive..."
    if ! 7za e -y "$ARCHIVE_NAME" -p"$ARCHIVE_PASSWORD" >>install.log 2>&1; then
        error "Extraction failed. Wrong password or corrupted archive."
    fi
    [ -f "$INSTALLER_NAME" ] || error "Installer file (${INSTALLER_NAME}) not found."

    info "Starting installation... (follow the on-screen prompts)"
    chmod +x "$INSTALLER_NAME"
    ./"$INSTALLER_NAME"
}

# ----------------------------------------------------------------------
# 4. Configure and license
# ----------------------------------------------------------------------
configure_acunetix() {
    info "Starting licensing..."
    systemctl stop acunetix 2>/dev/null || true

    [ -d "$SCANNER_DIR" ] || error "Scanner directory not found (${SCANNER_DIR}). Installation may be incomplete."

    info "Replacing the scanner binary..."
    [ -f wvsc ] || error "'wvsc' file not found! Patch files are missing."
    cp -f wvsc "${SCANNER_DIR}/wvsc"
    chown acunetix:acunetix "${SCANNER_DIR}/wvsc"
    chmod +x "${SCANNER_DIR}/wvsc"

    info "Placing license files..."
    if [ ! -f license_info.json ] || [ ! -f wa_data.dat ]; then
        error "License files (json/dat) not found!"
    fi

    mkdir -p "$LICENSE_DIR"
    chattr -i "${LICENSE_DIR}/license_info.json" 2>/dev/null || true
    chattr -i "${LICENSE_DIR}/wa_data.dat" 2>/dev/null || true
    rm -f "${LICENSE_DIR:?}"/* 2>/dev/null || true

    cp license_info.json "${LICENSE_DIR}/"
    cp wa_data.dat "${LICENSE_DIR}/"
    chown acunetix:acunetix "${LICENSE_DIR}/license_info.json" "${LICENSE_DIR}/wa_data.dat"
    chmod 444 "${LICENSE_DIR}/license_info.json" "${LICENSE_DIR}/wa_data.dat"
    chattr +i "${LICENSE_DIR}/license_info.json"
    chattr +i "${LICENSE_DIR}/wa_data.dat"
    success "License files placed and locked."

    info "Starting the Acunetix service..."
    systemctl start acunetix

    if systemctl is-active --quiet acunetix; then
        success "Acunetix service is ACTIVE and running."
    else
        error "Failed to start the Acunetix service! Check logs with 'systemctl status acunetix'."
    fi
}

# ----------------------------------------------------------------------
# Main flow
# ----------------------------------------------------------------------
main() {
    case "${1:-}" in
        -h|--help)    usage; exit 0 ;;
        -v|--version) echo "Acunetix ${VERSION_SHORT} (build ${BUILD})"; exit 0 ;;
        "")           ;;
        *)            error "Unknown option: $1 (use -h for help)" ;;
    esac

    require_root
    banner
    install_dependencies

    # From here on these tools are required
    require_cmd wget
    require_cmd 7za
    require_cmd systemctl

    trap cleanup_tmp EXIT

    update_hosts
    install_acunetix
    configure_acunetix
    cleanup_tmp
    trap - EXIT

    echo ""
    echo -e "${GREEN}==============================================${NC}"
    echo -e "${GREEN}   INSTALLATION COMPLETED SUCCESSFULLY!   ${NC}"
    echo -e "${GREEN}==============================================${NC}"
    echo -e "Access from a browser: ${YELLOW}https://localhost:${ACCESS_PORT}${NC}"
    echo -e "or connect using your server IP address."
    echo ""
}

main "$@"
