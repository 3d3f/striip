#!/usr/bin/env bash
set -euo pipefail

# Constants 

readonly THEME_NAME="striip-sddm"

readonly SDDM_THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
readonly SDDM_CONF_DROP_IN="/etc/sddm.conf.d/${THEME_NAME}.conf"

readonly SYNC_FILES_DEST="${HOME}/.local/share/${THEME_NAME}"

readonly MATUGEN_TEMPLATE_SECTION="striipsddm"

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

log_ok() { printf '  [OK]   %s\n' "$*"; }
log_warn() { printf '  [WARN] %s\n' "$*" >&2; }
log_section() { printf '\n-- %s\n' "$*"; }

# SDDM theme 

remove_theme() {
    log_section "Removing SDDM theme"

    if [[ -d "${SDDM_THEME_DIR}" ]]; then
        sudo rm -rf "${SDDM_THEME_DIR}"
        log_ok "Removed ${SDDM_THEME_DIR}"
    else
        log_warn "${SDDM_THEME_DIR} not found, skipping"
    fi
}

# SDDM configuration 

remove_sddm_conf() {
    log_section "Removing SDDM configuration"

    if [[ -f "${SDDM_CONF_DROP_IN}" ]]; then
        sudo rm -f "${SDDM_CONF_DROP_IN}"
        log_ok "Removed ${SDDM_CONF_DROP_IN}"

        if [[ -d "/etc/sddm.conf.d" ]] && [[ -z "$(sudo ls -A /etc/sddm.conf.d)" ]]; then
            sudo rmdir "/etc/sddm.conf.d"
            log_ok "Removed empty /etc/sddm.conf.d"
        fi
    else
        log_warn "${SDDM_CONF_DROP_IN} not found, skipping"
    fi
}

# Sync files

remove_sync_files() {
    log_section "Removing sync files"

    if [[ -d "${SYNC_FILES_DEST}" ]]; then
        rm -rf "${SYNC_FILES_DEST}"
        log_ok "Removed ${SYNC_FILES_DEST}"
    else
        log_warn "${SYNC_FILES_DEST} not found, skipping"
    fi
}

# Matugen configuration

remove_matugen_conf() {
    log_section "Removing matugen configuration"

    local sddm_toml="${HOME}/.config/matugen/conf.d/sddm.toml"

    if [[ -f "${sddm_toml}" ]]; then
        rm -f "${sddm_toml}"
        log_ok "Removed ${sddm_toml}"
    else
        log_warn "${sddm_toml} not found, skipping"
    fi
}

# Sudoers

remove_sudoers() {
    log_section "Removing sudoers rule"

    if sudo test -f "${SUDOERS_FILE}"; then
        sudo rm -f "${SUDOERS_FILE}"
        log_ok "Removed ${SUDOERS_FILE}"
    else
        log_warn "${SUDOERS_FILE} not found, skipping"
    fi
}

# Main

main() {
    printf '%s\n' 'STRiiP-sddm uninstaller'

    remove_theme
    remove_sddm_conf
    remove_sync_files
    remove_matugen_conf
    remove_sudoers

    printf '\nUninstall complete.\n'
}

main "$@"
