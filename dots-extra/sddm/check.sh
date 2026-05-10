#!/usr/bin/env bash

# Constants

readonly THEME_NAME="striip-sddm"

readonly SDDM_THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
readonly SDDM_CONF_DROP_IN="/etc/sddm.conf.d/${THEME_NAME}.conf"

readonly SYNC_FILES_DEST="${HOME}/.local/share/${THEME_NAME}"

readonly MATUGEN_CONF="${HOME}/.config/matugen/config.toml"
readonly MATUGEN_TEMPLATE_SECTION="striipsddm"

readonly SUDOERS_FILE="/etc/sudoers.d/${THEME_NAME}-${USER}"
readonly APPLY_SCRIPT="${SYNC_FILES_DEST}/sddm-theme-apply.sh"

# Logging

failures=0
warnings=0

ok() { printf '  [OK]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf '  [FAIL] %s\n' "$*"; failures=$((failures + 1)); }
section() { printf '\n-- %s\n' "$*"; }

# Checks

check_sddm_theme() {
    section "SDDM theme"

    if [[ -d "${SDDM_THEME_DIR}" ]]; then
        ok "Theme directory exists: ${SDDM_THEME_DIR}"
    else
        fail "Theme directory missing: ${SDDM_THEME_DIR}"
    fi

    for f in Main.qml metadata.desktop; do
        if [[ -f "${SDDM_THEME_DIR}/${f}" ]]; then
            ok "${f} present"
        else
            fail "${f} missing in ${SDDM_THEME_DIR}"
        fi
    done

    if find "${SDDM_THEME_DIR}/Backgrounds/" -maxdepth 1 -name 'background.*' | grep -q .; then
        ok "Background file present"
    else
        warn "No background file found in ${SDDM_THEME_DIR}/Backgrounds/"
    fi

    for f in Components/Colors.qml Components/Settings.qml Themes/striip-sddm.conf; do
        if [[ -f "${SDDM_THEME_DIR}/${f}" ]]; then
            ok "${f} present"
        else
            fail "${f} missing"
        fi
    done
}

check_sddm_conf() {
    section "SDDM configuration"

    if [[ -f "${SDDM_CONF_DROP_IN}" ]]; then
        ok "Drop-in exists: ${SDDM_CONF_DROP_IN}"
    else
        fail "Drop-in missing: ${SDDM_CONF_DROP_IN}"
        return
    fi

    if grep -q "^Current=${THEME_NAME}$" "${SDDM_CONF_DROP_IN}"; then
        ok "Current=${THEME_NAME} set"
    else
        fail "Current=${THEME_NAME} not set in ${SDDM_CONF_DROP_IN}"
    fi
}

check_sync_files() {
    section "Sync files"

    if [[ -d "${SYNC_FILES_DEST}" ]]; then
        ok "Sync files directory exists: ${SYNC_FILES_DEST}"
    else
        fail "Sync files directory missing: ${SYNC_FILES_DEST}"
        return
    fi

    for f in SddmColors.qml Colors.qml Settings.qml striip-sddm.conf generate_settings.py sddm-theme-apply.sh; do
        if [[ -f "${SYNC_FILES_DEST}/${f}" ]]; then
            ok "${f} present"
        else
            fail "${f} missing in ${SYNC_FILES_DEST}"
        fi
    done

    if [[ -x "${APPLY_SCRIPT}" ]]; then
        ok "sddm-theme-apply.sh is executable"
    else
        fail "sddm-theme-apply.sh is not executable"
    fi
}

check_matugen() {
    section "Matugen configuration"

    if [[ ! -f "${MATUGEN_CONF}" ]]; then
        fail "Matugen config not found: ${MATUGEN_CONF}"
        return
    fi

    if grep -q "^\[templates\.${MATUGEN_TEMPLATE_SECTION}\]" "${MATUGEN_CONF}"; then
        ok "[templates.${MATUGEN_TEMPLATE_SECTION}] block present"
    else
        fail "[templates.${MATUGEN_TEMPLATE_SECTION}] block missing in ${MATUGEN_CONF}"
    fi
}

check_sudoers() {
    section "Sudoers"

    if sudo test -f "${SUDOERS_FILE}"; then
        ok "Sudoers rule exists: ${SUDOERS_FILE}"
    else
        fail "Sudoers rule missing: ${SUDOERS_FILE}"
        return
    fi

    if sudo visudo -c -f "${SUDOERS_FILE}" > /dev/null 2>&1; then
        ok "Sudoers rule is valid"
    else
        fail "Sudoers rule failed validation"
    fi
}

check_dependencies() {
    section "Dependencies"

    for pkg in sddm qt6-declarative qt6-5compat qt6-svg qt6-multimedia-ffmpeg; do
        if pacman -Q "${pkg}" > /dev/null 2>&1; then
            ok "${pkg} installed"
        else
            fail "${pkg} missing"
        fi
    done

    if command -v matugen > /dev/null 2>&1; then
        ok "matugen found"
    else
        fail "matugen not found"
    fi

    if command -v python3 > /dev/null 2>&1; then
        ok "python3 found"
    else
        fail "python3 not found"
    fi
}

# Main

main() {
    printf '%s\n' 'STRiiP-sddm check'

    check_dependencies
    check_sddm_theme
    check_sddm_conf
    check_sync_files
    check_matugen
    check_sudoers

    printf '\n-- Result\n'
    printf '  Failures: %d\n' "${failures}"
    printf '  Warnings: %d\n' "${warnings}"

    if [[ "${failures}" -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
