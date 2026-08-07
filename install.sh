#!/usr/bin/env bash
#
# Acunetix installation and configuration script
# ByCh4n | Cyber Security Expert
#
# To target a new release, change only the BUILD / VERSION_SHORT
# variables below; every path is derived from them.

set -Eeuo pipefail

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
readonly VERSION_SHORT="25.1"
readonly BUILD="250204093"
readonly ARCHIVE_PASSWORD="Pwn3rzs"
readonly DOWNLOAD_BASE="https://pwn3rzs.co/scanner_web/acunetix"

# SHA256 of the archive. Leave empty to skip verification (not recommended:
# the extracted installer is executed as root). Compute it once from a copy
# you trust with:  sha256sum <archive>
readonly ARCHIVE_SHA256=""

readonly ARCHIVE_NAME="Acunetix-v${VERSION_SHORT}.${BUILD}-Linux-Pwn3rzs-CyberArsenal.7z"
readonly INSTALLER_NAME="acunetix_${VERSION_SHORT}.${BUILD}_x64.sh"
readonly ACUNETIX_HOME="/home/acunetix/.acunetix"
readonly SCANNER_DIR="${ACUNETIX_HOME}/v_${BUILD}/scanner"
readonly LICENSE_DIR="${ACUNETIX_HOME}/data/license"
readonly ACCESS_PORT="3443"

# Rough free-space floor for the install target, in MiB.
readonly MIN_FREE_MIB="3072"

readonly LOG_FILE="${PWD}/install.log"

# Set by --dry-run: report the plan without changing anything.
DRY_RUN=0

# Markers delimiting the block this script owns in /etc/hosts. The whole
# block is rewritten on every run, which keeps the file idempotent.
readonly HOSTS_MARK_BEGIN="# >>> acunetix-installer (ByCh4n) >>>"
readonly HOSTS_MARK_END="# <<< acunetix-installer (ByCh4n) <<<"

# Set to 1 once the run has fully succeeded; controls whether the log is kept.
INSTALL_OK=0

# Resolved by detect_7z() - the 7-Zip CLI available on this system.
SEVENZIP=""

# Resolved by check_platform().
PKG_MANAGER=""
DISTRO_NAME="unknown"

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

# Remove downloaded temporary files on exit. The log is only removed when the
# run succeeded - on failure it is exactly what is needed to diagnose things.
cleanup_tmp() {
    rm -f "${ARCHIVE_NAME}" "${INSTALLER_NAME}" \
          license_info.json wa_data.dat wvsc README.txt 2>/dev/null || true

    if [ "$INSTALL_OK" -eq 1 ]; then
        rm -f "$LOG_FILE" 2>/dev/null || true
    elif [ -s "$LOG_FILE" ]; then
        warning "Log kept for troubleshooting: ${LOG_FILE}"
    fi

    # Never let the trap's own status override the script's exit code.
    return 0
}

usage() {
    cat <<EOF
Usage: sudo ./install.sh [option]

Options:
  -h, --help           Show this help message
  -v, --version        Show the targeted Acunetix version
  -c, --check          Report what this system looks like, then exit
  -n, --dry-run        Print the steps that would run, without changing anything
  -r, --restore-hosts  Remove this script's block from /etc/hosts and exit
  -u, --uninstall      Undo this script's system changes (service + hosts) and exit

With no arguments it runs the full installation flow:
  platform -> preflight -> dependencies -> hosts -> download/verify/install -> licensing -> cleanup

Supported: Debian / Ubuntu / Kali (apt) and Arch (pacman), x86_64, systemd.
EOF
}

# Free space (MiB) on the filesystem that will hold the given path, walking up
# to the nearest existing ancestor since /home/acunetix may not exist yet.
avail_mib() {
    local path="$1"
    while [ ! -d "$path" ] && [ "$path" != "/" ]; do
        path="$(dirname "$path")"
    done
    df -Pm "$path" 2>/dev/null | awk 'NR==2 {print $4}'
}

# Is the access port already taken? Best effort: needs ss or netstat, and is
# only advisory (returns "unknown" when neither is present).
port_state() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q . && echo busy || echo free
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ltn 2>/dev/null | grep -qE "[:.]${port}[[:space:]]" && echo busy || echo free
    else
        echo unknown
    fi
}

# Resource preflight. Warnings only for the advisory checks; a hard failure
# only when there is clearly not enough disk to proceed.
check_resources() {
    info "Checking resources..."

    local free
    free="$(avail_mib "$ACUNETIX_HOME")"
    if [ -n "$free" ]; then
        if [ "$free" -lt "$MIN_FREE_MIB" ]; then
            error "Not enough free space for ${ACUNETIX_HOME%/*/*}: ${free} MiB available, ${MIN_FREE_MIB} MiB needed."
        fi
        success "Free space: ${free} MiB (>= ${MIN_FREE_MIB} MiB)."
    else
        warning "Could not determine free space (df unavailable?)."
    fi

    local state
    state="$(port_state "$ACCESS_PORT")"
    case "$state" in
        busy)    warning "Port ${ACCESS_PORT} is already in use - the web UI may not come up." ;;
        free)    success "Port ${ACCESS_PORT} is free." ;;
        unknown) warning "Could not check port ${ACCESS_PORT} (ss / netstat not found)." ;;
    esac
}

# Non-destructive preflight: run this first on an untested distribution.
check_system() {
    check_platform
    check_resources
    if detect_7z; then
        success "7-Zip CLI found: ${SEVENZIP}"
    else
        warning "No 7-Zip CLI yet (7zz / 7za / 7z) - it will be installed."
    fi
    echo ""
    info "Packages that would be installed:"
    dependency_list | sed 's/^/   /'
}

# --dry-run: describe the flow without touching the system.
dry_run() {
    check_platform
    check_resources
    detect_7z || true
    echo ""
    info "The following steps WOULD run (nothing is being changed):"
    cat <<EOF
   1. install dependencies via ${PKG_MANAGER}
   2. back up /etc/hosts and (re)write the acunetix block
   3. download ${ARCHIVE_NAME}
      from ${DOWNLOAD_BASE}
   4. $([ -n "$ARCHIVE_SHA256" ] && echo "verify SHA256" || echo "SKIP checksum (ARCHIVE_SHA256 is empty)")
   5. extract with ${SEVENZIP:-<none yet>} and run ${INSTALLER_NAME}
   6. place license/patch files and (re)start the acunetix service
EOF
    echo ""
    info "Packages:"
    dependency_list | sed 's/^/   /'
    echo ""
    info "Domains that would be written to /etc/hosts:"
    hosts_domains | sed 's/^/   /'
}

# --uninstall: undo the system-level changes this script makes. It stops and
# disables the service and reverts /etc/hosts; it does not remove the Acunetix
# payload itself, since that was created by the upstream vendor installer.
uninstall() {
    require_root
    info "Reverting changes made by this script..."

    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop acunetix 2>/dev/null || true
        systemctl disable acunetix 2>/dev/null || true
        success "acunetix service stopped and disabled (if it existed)."
    fi

    # Clear immutable flags so nothing is left stuck read-only.
    if command -v chattr >/dev/null 2>&1; then
        chattr -i "${LICENSE_DIR}/license_info.json" 2>/dev/null || true
        chattr -i "${LICENSE_DIR}/wa_data.dat" 2>/dev/null || true
    fi

    restore_hosts

    echo ""
    info "The Acunetix files under ${ACUNETIX_HOME} were installed by the vendor"
    info "installer and are left untouched. Remove them yourself if you want a"
    info "full uninstall (e.g. the vendor's own uninstaller, or 'rm -rf' that path)."
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

detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    else
        return 1
    fi
    return 0
}

# The installer ships an x86_64 binary and registers a systemd unit.
check_platform() {
    local arch
    arch="$(uname -m)"
    if [ "$arch" != "x86_64" ]; then
        error "Only x86_64 is supported (detected: ${arch})."
    fi

    if [ -r /etc/os-release ]; then
        DISTRO_NAME="$(. /etc/os-release && echo "${PRETTY_NAME:-${NAME:-unknown}}")"
    fi

    detect_pkg_manager || \
        error "No supported package manager found (looked for apt-get and pacman)."

    info "Detected: ${DISTRO_NAME} - ${arch}, ${PKG_MANAGER}"

    command -v systemctl >/dev/null 2>&1 || \
        error "systemd is required ('systemctl' not found)."

    if [ "$PKG_MANAGER" != "apt" ]; then
        warning "This script is adapted for ${PKG_MANAGER}, but the upstream payload is not."
        warning "The Pwn3rzs archive is packaged for Debian-based systems and is outside"
        warning "this project's control. Dependencies, hosts and download will work here;"
        warning "the upstream installer step may not, and adapting it is up to you."
    fi
}

# Debian 13 dropped p7zip in favour of the 7zip package, whose binary is 7zz.
detect_7z() {
    local candidate
    for candidate in 7zz 7za 7z; do
        if command -v "$candidate" >/dev/null 2>&1; then
            SEVENZIP="$candidate"
            return 0
        fi
    done
    return 1
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
# One line per dependency; whitespace-separated names on a line are
# alternatives and the first one that installs wins. The 7-Zip line comes
# first because the extraction step depends on it.
dependency_list() {
    case "$PKG_MANAGER" in
        apt)
            # Debian 13 replaced p7zip-full with 7zip (binaries 7za / 7z, and
            # 7zz from 7zip-standalone).
            cat <<'EOF'
p7zip-full 7zip
libxcomposite1
libcups2
libasound2
libatk1.0-0
libgbm1
libxfixes3
libcairo2
libxrandr2
libxkbcommon0
libatk-bridge2.0-0
libxdamage1
libatspi2.0-0
wget
curl
systemd
e2fsprogs
EOF
            ;;
        pacman)
            # Arch splits things differently: mesa carries libgbm, alsa-lib
            # carries libasound, and at-spi2-core absorbed at-spi2-atk.
            cat <<'EOF'
7zip p7zip
libxcomposite
libcups
alsa-lib
atk
mesa
libxfixes
cairo
libxrandr
libxkbcommon
at-spi2-core
libxdamage
wget
curl
systemd
e2fsprogs
EOF
            ;;
    esac
}

pkg_refresh() {
    case "$PKG_MANAGER" in
        apt)
            apt-get update -qq >>"$LOG_FILE" 2>&1
            ;;
        pacman)
            # A bare 'pacman -Sy' leaves the system in a partial-upgrade state,
            # which is the classic way to break an Arch install, so refresh and
            # upgrade in one go.
            warning "Arch: performing a full 'pacman -Syu' (a partial upgrade would break the system)."
            pacman -Syu --noconfirm >>"$LOG_FILE" 2>&1
            ;;
        *)  return 1 ;;
    esac
}

pkg_install() {
    case "$PKG_MANAGER" in
        apt)    apt-get install -y "$1" >>"$LOG_FILE" 2>&1 ;;
        pacman) pacman -S --needed --noconfirm "$1" >>"$LOG_FILE" 2>&1 ;;
        *)      return 1 ;;
    esac
}

# Try each alternative in turn. On apt, every candidate is also retried with a
# "t64" suffix, the rename Debian 13 / Ubuntu 24.04 applied to several libs.
install_pkg() {
    local pkg
    for pkg in "$@"; do
        if pkg_install "$pkg"; then
            return 0
        fi
        if [ "$PKG_MANAGER" = "apt" ] && pkg_install "${pkg}t64"; then
            return 0
        fi
    done
    return 1
}

install_dependencies() {
    info "Updating the system and installing dependencies (${PKG_MANAGER})..."
    export DEBIAN_FRONTEND=noninteractive
    : > "$LOG_FILE"

    if ! pkg_refresh; then
        error "Package database refresh failed. Check your connection / repositories."
    fi

    local failed=()
    local entry alternatives
    while read -r entry; do
        [ -n "$entry" ] || continue
        read -r -a alternatives <<< "$entry"
        if install_pkg "${alternatives[@]}"; then
            echo -e "   ${GREEN}+${NC} ${alternatives[0]}"
        else
            echo -e "   ${RED}-${NC} ${alternatives[0]}"
            failed+=("${alternatives[0]}")
        fi
    done < <(dependency_list)

    if [ "${#failed[@]}" -gt 0 ]; then
        error "Failed to install: ${failed[*]} (details in ${LOG_FILE})"
    fi
    success "All dependencies installed."
}

# ----------------------------------------------------------------------
# 2. Update the hosts file
# ----------------------------------------------------------------------
# Drop any previously written block and any trailing blank lines, so that the
# separator added before the block does not accumulate across runs. Rewriting
# via 'cat >' rather than 'mv' keeps the original inode, ownership and
# permissions of /etc/hosts.
strip_hosts_block() {
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$HOSTS_MARK_BEGIN" -v end="$HOSTS_MARK_END" '
        $0 == begin { skip = 1; next }
        $0 == end   { skip = 0; next }
        skip        { next }
        # Hold blank lines back; they are only emitted once real content
        # follows, which drops the trailing ones entirely.
        /^[[:space:]]*$/ { held = held $0 "\n"; next }
        { printf "%s", held; held = ""; print }
    ' /etc/hosts > "$tmp"

    cat "$tmp" > /etc/hosts
    rm -f "$tmp"
}

hosts_domains() {
    cat <<'EOF'
erp.acunetix.com
discovery-service.invicti.com
cdn.pendo.io
bxss.me
jwtsigner.invicti.com
sca.acunetix.com
telemetry.invicti.com
EOF
}

update_hosts() {
    info "Configuring /etc/hosts..."

    if [ ! -f /etc/hosts.original ]; then
        cp /etc/hosts /etc/hosts.original
        success "Original hosts file backed up (/etc/hosts.original)"
    fi

    strip_hosts_block

    local domain ipv4 ipv6
    {
        echo ""
        echo "$HOSTS_MARK_BEGIN"
        while read -r domain; do
            [ -n "$domain" ] || continue
            if [ "$domain" = "telemetry.invicti.com" ]; then
                ipv4="192.178.49.174"
                ipv6="2607:f8b0:402a:80a::200e"
            else
                ipv4="127.0.0.1"
                ipv6="::1"
            fi
            printf '%s  %s\n' "$ipv4" "$domain"
            printf '%s  %s\n' "$ipv6" "$domain"
            echo -e "   ${GREEN}+${NC} ${domain} (${ipv4} / ${ipv6})" >&2
        done < <(hosts_domains)
        echo "$HOSTS_MARK_END"
    } >> /etc/hosts

    success "hosts file updated (block rewritten, IPv4 + IPv6)."
}

restore_hosts() {
    require_root
    if grep -qF "$HOSTS_MARK_BEGIN" /etc/hosts 2>/dev/null; then
        strip_hosts_block
        success "Removed this script's block from /etc/hosts."
    else
        warning "No block written by this script was found in /etc/hosts."
    fi
    if [ -f /etc/hosts.original ]; then
        info "An untouched backup is still available at /etc/hosts.original"
    fi
}

# ----------------------------------------------------------------------
# 3. Download, verify and install
# ----------------------------------------------------------------------
verify_archive() {
    if [ -z "$ARCHIVE_SHA256" ]; then
        warning "ARCHIVE_SHA256 is empty - integrity of the archive is NOT verified."
        warning "Its contents run as root; pin a known-good checksum before trusting it."
        return 0
    fi

    require_cmd sha256sum
    info "Verifying archive checksum..."

    local actual
    actual="$(sha256sum "$ARCHIVE_NAME" | awk '{print $1}')"
    if [ "$actual" != "$ARCHIVE_SHA256" ]; then
        rm -f "$ARCHIVE_NAME"
        error "Checksum mismatch! expected ${ARCHIVE_SHA256}, got ${actual}. Archive deleted."
    fi
    success "Checksum verified."
}

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

    verify_archive

    info "Extracting archive with '${SEVENZIP}'..."
    if ! "$SEVENZIP" e -y "$ARCHIVE_NAME" -p"$ARCHIVE_PASSWORD" >>"$LOG_FILE" 2>&1; then
        error "Extraction failed. Wrong password or corrupted archive."
    fi
    [ -f "$INSTALLER_NAME" ] || error "Installer file (${INSTALLER_NAME}) not found."

    info "Starting installation... (follow the on-screen prompts)"
    chmod +x "$INSTALLER_NAME"
    ./"$INSTALLER_NAME" || error "The Acunetix installer exited with an error."
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
    cp -f wvsc "${SCANNER_DIR}/wvsc" || error "Could not write ${SCANNER_DIR}/wvsc"
    chown acunetix:acunetix "${SCANNER_DIR}/wvsc" || error "Could not chown ${SCANNER_DIR}/wvsc"
    chmod +x "${SCANNER_DIR}/wvsc"

    info "Placing license files..."
    if [ ! -f license_info.json ] || [ ! -f wa_data.dat ]; then
        error "License files (json/dat) not found!"
    fi

    mkdir -p "$LICENSE_DIR"
    chattr -i "${LICENSE_DIR}/license_info.json" 2>/dev/null || true
    chattr -i "${LICENSE_DIR}/wa_data.dat" 2>/dev/null || true
    rm -f "${LICENSE_DIR:?}"/* 2>/dev/null || true

    cp license_info.json "${LICENSE_DIR}/" || error "Could not copy license_info.json"
    cp wa_data.dat "${LICENSE_DIR}/" || error "Could not copy wa_data.dat"
    chown acunetix:acunetix "${LICENSE_DIR}/license_info.json" "${LICENSE_DIR}/wa_data.dat"
    chmod 444 "${LICENSE_DIR}/license_info.json" "${LICENSE_DIR}/wa_data.dat"

    # chattr needs a filesystem that supports it (ext*/xfs); don't abort if not.
    if ! chattr +i "${LICENSE_DIR}/license_info.json" 2>>"$LOG_FILE" || \
       ! chattr +i "${LICENSE_DIR}/wa_data.dat" 2>>"$LOG_FILE"; then
        warning "Could not set the immutable flag (unsupported filesystem?)."
    else
        success "License files placed and locked."
    fi

    info "Starting the Acunetix service..."
    systemctl start acunetix || true

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
        -h|--help)          usage; exit 0 ;;
        -v|--version)       echo "Acunetix ${VERSION_SHORT} (build ${BUILD})"; exit 0 ;;
        -c|--check)         check_system; exit 0 ;;
        -n|--dry-run)       dry_run; exit 0 ;;
        -u|--uninstall)     uninstall; exit 0 ;;
        -r|--restore-hosts) restore_hosts; exit 0 ;;
        "")                 ;;
        *)                  error "Unknown option: $1 (use -h for help)" ;;
    esac

    require_root
    check_platform
    check_resources
    banner

    trap cleanup_tmp EXIT

    install_dependencies

    # From here on these tools are required.
    require_cmd wget
    require_cmd systemctl
    detect_7z || error "No 7-Zip CLI found (looked for 7zz, 7za, 7z)."

    update_hosts
    install_acunetix
    configure_acunetix

    INSTALL_OK=1
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
