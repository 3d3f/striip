#!/usr/bin/env bash
set -euo pipefail

# Constants

readonly THEME_NAME="striip-sddm"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly SDDM_THEME_SRC="${SCRIPT_DIR}/striip-sddm"
readonly SDDM_THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
readonly SDDM_CONF_DROP_IN="/etc/sddm.conf.d/${THEME_NAME}.conf"

readonly SYNC_FILES_SRC="${SCRIPT_DIR}/sync-files"
readonly SYNC_FILES_DEST="${HOME}/.local/share/${THEME_NAME}"

readonly MATUGEN_TEMPLATE_SECTION="striipsddm"
readonly MATUGEN_INPUT="${SYNC_FILES_DEST}/SddmColors.qml"
readonly MATUGEN_OUTPUT="${SYNC_FILES_DEST}/Colors.qml"
readonly MATUGEN_POST_HOOK="bash -c 'python3 ${SYNC_FILES_DEST}/generate_settings.py && sudo ${SYNC_FILES_DEST}/sddm-theme-apply.sh'"

readonly APPLY_SCRIPT="${SYNC_FILES_DEST}/sddm-theme-apply.sh"
readonly SUDOERS_FILE="/etc/sudoers.d/${THEME_NAME}-${USER}"

# Guards 

if [[ "$(id -u)" -eq 0 ]]; then
    printf 'ERROR: Do not run this script as root. It uses sudo internally.\n' >&2
    exit 1
fi

if ! sudo -v; then
    printf 'ERROR: sudo authentication failed.\n' >&2
    exit 1
fi

# Logging

log_info() { printf '  [INFO] %s\n' "$*"; }
log_ok() { printf '  [OK]   %s\n' "$*"; }
log_warn() { printf '  [WARN] %s\n' "$*" >&2; }
log_error() { printf '  [ERR]  %s\n' "$*" >&2; }
log_section() { printf '\n-- %s\n' "$*"; }

# Dependency check

check_dependencies() {
    log_section "Checking dependencies"

    local missing=()
    local deps=(sddm qt6-declarative qt6-5compat qt6-svg qt6-multimedia-ffmpeg python)

    for dep in "${deps[@]}"; do
        if ! pacman -Qs "^${dep}$" > /dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing packages: ${missing[*]}"
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    fi

    log_ok "All dependencies satisfied"
}

# Scripts installation

install_sync_files() {
    log_section "Installing sync-files to ${SYNC_FILES_DEST}"

    if [[ ! -d "${SYNC_FILES_SRC}" ]]; then
        log_error "sync-files/ directory not found in ${SCRIPT_DIR}"
        exit 1
    fi

    if [[ -d "${SYNC_FILES_DEST}" ]]; then
        log_warn "Existing installation found at ${SYNC_FILES_DEST}, removing"
        rm -rf "${SYNC_FILES_DEST}"
    fi

    mkdir -p "${SYNC_FILES_DEST}"
    cp -r "${SYNC_FILES_SRC}/." "${SYNC_FILES_DEST}/"
    chmod +x "${SYNC_FILES_DEST}/sddm-theme-apply.sh"

    log_ok "Sync files installed to ${SYNC_FILES_DEST}"
}

# SDDM theme installation 

install_theme() {
    log_section "Installing SDDM theme to ${SDDM_THEME_DIR}"

    if [[ -d "${SDDM_THEME_DIR}" ]]; then
        log_warn "Existing SDDM theme found, removing"
        sudo rm -rf "${SDDM_THEME_DIR}"
    fi

    sudo mkdir -p "${SDDM_THEME_DIR}"
    sudo cp -r "${SDDM_THEME_SRC}/." "${SDDM_THEME_DIR}/"

    sudo chown -R root:root "${SDDM_THEME_DIR}"
    sudo find "${SDDM_THEME_DIR}" -type d -exec chmod 755 {} \;
    sudo find "${SDDM_THEME_DIR}" -type f -exec chmod 644 {} \;

    log_ok "SDDM theme installed"
}

# SDDM configuration 

configure_sddm() {
    log_section "Configuring SDDM"

    sudo mkdir -p "$(dirname "${SDDM_CONF_DROP_IN}")"

    sudo tee "${SDDM_CONF_DROP_IN}" > /dev/null <<EOF
[General]
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/${THEME_NAME}/Components/

[Theme]
Current=${THEME_NAME}
EOF

    log_ok "Drop-in written to ${SDDM_CONF_DROP_IN}"
}

# Matugen configuration

configure_matugen() {
    log_section "Configuring matugen"

    local sddm_toml="${HOME}/.config/matugen/conf.d/sddm.toml"
    mkdir -p "$(dirname "${sddm_toml}")"

    cat > "${sddm_toml}" <<EOF
[templates.${MATUGEN_TEMPLATE_SECTION}]
input_path = '${MATUGEN_INPUT}'
output_path = '${MATUGEN_OUTPUT}'
post_hook = "${MATUGEN_POST_HOOK}"
EOF

    log_ok "Matugen block written to ${sddm_toml}"
}

# Sudoers configuration

configure_sudoers() {
    log_section "Configuring sudoers"

    if [[ ! -f "${APPLY_SCRIPT}" ]]; then
        log_error "Apply script not found at ${APPLY_SCRIPT}"
        exit 1
    fi

    local rule="${USER} ALL=(ALL) NOPASSWD: ${APPLY_SCRIPT}"
    local tmp
    tmp="$(mktemp)"
    printf '%s\n' "${rule}" > "${tmp}"

    if ! visudo -c -f "${tmp}" > /dev/null 2>&1; then
        log_error "Generated sudoers rule failed validation"
        rm -f "${tmp}"
        exit 1
    fi

    sudo cp "${tmp}" "${SUDOERS_FILE}"
    sudo chmod 0440 "${SUDOERS_FILE}"
    rm -f "${tmp}"

    log_ok "Sudoers rule written to ${SUDOERS_FILE}"
}

# Initial matugen run

initial_matugen() {
    log_section "Running initial matugen"

    local shell_config="${HOME}/.config/illogical-impulse/config.json"
    local default_wallpaper
    default_wallpaper="$(realpath "${SCRIPT_DIR}/../../dots/.config/quickshell/ii/assets/images/default_wallpaper.png")"

    local wallpaper_path=""

    if [[ -f "${shell_config}" ]]; then
        wallpaper_path="$(jq -r '.background.wallpaperPath // empty' "${shell_config}" 2>/dev/null || true)"
    fi

    if [[ -z "${wallpaper_path}" || ! -f "${wallpaper_path}" ]]; then
        log_warn "No wallpaper found in config, using default"
        wallpaper_path="${default_wallpaper}"
    fi

    if [[ ! -f "${wallpaper_path}" ]]; then
        log_warn "Default wallpaper not found at ${wallpaper_path}, skipping matugen"
        log_warn "Run 'matugen image <path>' manually to complete setup"
        return
    fi

    log_info "Using wallpaper: ${wallpaper_path}"

    if matugen image "${wallpaper_path}" --source-color-index 0; then
        log_ok "matugen completed successfully"
    else
        log_warn "matugen failed, run 'matugen image <path>' manually to complete setup"
    fi
}

# Main

main() {
    printf '%s\n' 'STRiiP-sddm installer'

    check_dependencies
    install_sync_files
    install_theme
    configure_sddm
    configure_matugen
    configure_sudoers
    initial_matugen

    printf '\nInstallation complete.\n'
}

main "$@"
