#!/usr/bin/env bash

cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"

STY_CYAN='\e[36m'
STY_RED='\e[31m'
STY_RST='\e[00m'

if [ "$(id -u)" -eq 0 ]; then
    printf "%bError: [%s] must not be run as root%b\n" "$STY_RED" "$0" "$STY_RST"
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    printf "%bError: only Arch Linux or an Arch-based distro supported%b\n" "$STY_RED" "$STY_RST"
    exit 1
fi

set -e

function show_banner {
    printf "███████╗████████╗██████╗${STY_CYAN} ██╗██╗${STY_RST}██████╗\n"
    printf "██╔════╝╚══██╔══╝██╔══██╗${STY_CYAN}╚═╝╚═╝${STY_RST}██╔══██╗\n"
    printf "███████╗   ██║   ██████╔╝${STY_CYAN}██╗██╗${STY_RST}██████╔╝\n"
    printf "╚════██║   ██║   ██╔══██╗${STY_CYAN}██║██║${STY_RST}██╔═══╝\n"
    printf "███████║   ██║   ██║  ██║${STY_CYAN}██║██║${STY_RST}██║\n"
    printf "╚══════╝   ╚═╝   ╚═╝  ╚═╝${STY_CYAN}╚═╝╚═╝${STY_RST}╚═╝\n"
    printf "\n"
}

function install() {
    printf "This option will execute the ii setup\n"
    printf "You can also use it to fully update the shell\n"
    read -r -p "===> Continue? [y/n]: " p
    case $p in
        y|Y)
            git stash && git pull || {
                printf "Repo update failed, install the shell without new changes?\n"
                read -r -p "===> Press Enter to continue..."
            }
            ./setup install
        ;;
        *) return ;;
    esac
}

function quick_update() {
    printf "This option will update the repo and only copy the files\n"
    printf "A full re-install/update of the shell is recommended if some bugs are encountered\n"
    read -r -p "===> Continue? [y/n]: " p
    case $p in
        y|Y)
            git stash && git pull || {
                printf "%bRepo update failed, aborting%b\n" "$STY_RED" "$STY_RST"
                return 1
            }
            ./setup install-files --force --skip-allgreeting
            killall qs 2>/dev/null; qs -c ii > /dev/null 2>&1 & disown
        ;;
        *) return ;;
    esac
}

while true; do
    show_banner
    printf "1 = Install.\n"
    printf "2 = Quick update.\n"
    printf "a = Abort.\n"
    read -r -p "===> [1/2/a]: " p
    case $p in
        1) install ;;
        2) quick_update ;;
        a) exit 0 ;;
        *) printf "%bInvalid option%b\n" "$STY_RED" "$STY_RST";;
    esac
done

