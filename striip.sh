#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1
REPO_ROOT="$(pwd)"

STY_CYAN='\e[36m'
STY_GREEN='\e[32m'
STY_YELLOW='\e[33m'
STY_RED='\e[31m'
STY_RST='\e[0m'

log_info()  { printf "  [INFO] %s\n" "$*"; }
log_ok()    { printf "  ${STY_GREEN}[OK]   %s${STY_RST}\n" "$*"; }
log_warn()  { printf "  ${STY_YELLOW}[WARN] %s${STY_RST}\n" "$*"; }
log_error() { printf "  ${STY_RED}[ERR]  %s${STY_RST}\n" "$*" >&2; }
log_step()  { printf "\n-- %s\n" "$*"; }

if [ "$(id -u)" -eq 0 ]; then
    log_error "This script must not be run as root"
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    log_error "Only Arch Linux or an Arch-based distro supported"
    exit 1
fi

function show_banner {
    printf "███████╗████████╗██████╗ ${STY_CYAN}██╗██╗${STY_RST}██████╗\n"
    printf "██╔════╝╚══██╔══╝██╔══██╗${STY_CYAN}╚═╝╚═╝${STY_RST}██╔══██╗\n"
    printf "███████╗   ██║   ██████╔╝${STY_CYAN}██╗██╗${STY_RST}██████╔╝\n"
    printf "╚════██║   ██║   ██╔══██╗${STY_CYAN}██║██║${STY_RST}██╔═══╝\n"
    printf "███████║   ██║   ██║  ██║${STY_CYAN}██║██║${STY_RST}██║\n"
    printf "╚══════╝   ╚═╝   ╚═╝  ╚═╝${STY_CYAN}╚═╝╚═╝${STY_RST}╚═╝\n"
    printf "\n"
}

function install() {
    log_step "SHELL INSTALLATION"
    log_info "This process will execute the setup to install/update the shell."
    log_info "Any local changes to the repo will be stashed."
    
    read -r -p "===> Continue? [y/n]: " p
    case $p in
        y|Y)
            log_info "Updating repository..."
            if git stash && git pull; then
                ./setup install
            else
                log_warn "Repo update failed"
                read -r -p "===> Install the shell without the new changes? [y/n]: " p
                case $p in
                    y|Y) 
                        ./setup install || {
                            log_error "Install failed, aborting..."
                            return 1
                        } 
                        ;;
                    *) return ;;
                esac
            fi 
            ;;
        *) return ;;
    esac
}

function quick_update() {
    log_step "QUICK UPDATE"
    log_info "Updating files and stashing local changes..."
    
    read -r -p "===> Continue? [y/n]: " p
    case $p in
        y|Y)
            if git stash && git pull; then
                log_ok "Repository updated."
            else
                log_error "Repo update failed, aborting..."
                return 1
            fi

            if ./setup install-files --force --skip-allgreeting; then
                log_ok "Files copied successfully."
            else
                log_error "Quick update failed, aborting..."
                return 1
            fi

            log_info "Reload Quickshell"
            killall qs 2>/dev/null || true
            sleep 0.2 
            qs -c ii > /dev/null 2>&1 & disown
            
            log_ok "Update complete."
            read -r -p "===> Press Enter to return to the menu..."
        ;;
        *) return ;;
    esac
}

while true; do
    show_banner
    printf "1 = Install.\n"
    printf "2 = Quick update.\n"
    printf "q = Quit.\n"
    printf "\n"
    read -r -p "===> [1/2/q]: " p
    case $p in
        1) install ;;
        2) quick_update ;;
        q) exit 0 ;;
        *) log_error "Invalid option: $p" ;;
    esac
done