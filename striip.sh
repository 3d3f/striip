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
    printf "███████╗████████╗██████╗ ${STY_CYAN}██╗██╗${STY_RST}██████╗\n"
    printf "██╔════╝╚══██╔══╝██╔══██╗${STY_CYAN}╚═╝╚═╝${STY_RST}██╔══██╗\n"
    printf "███████╗   ██║   ██████╔╝${STY_CYAN}██╗██╗${STY_RST}██████╔╝\n"
    printf "╚════██║   ██║   ██╔══██╗${STY_CYAN}██║██║${STY_RST}██╔═══╝\n"
    printf "███████║   ██║   ██║  ██║${STY_CYAN}██║██║${STY_RST}██║\n"
    printf "╚══════╝   ╚═╝   ╚═╝  ╚═╝${STY_CYAN}╚═╝╚═╝${STY_RST}╚═╝\n"
    printf "\n"
}

function install() {
    printf "This process will execute the setup to install/update the shell.\n"
    printf "Any local changes to the repo will be stashed.\n"
    read -r -p "===> Continue? [y/n]: " p
    case $p in
        y|Y)
            if git stash && git pull; then
                ./setup install
            else
                printf "Repo update failed\n"
                read -r -p "===> Install the shell without the new changes? [y/n]: " p
                case $p in
                    y|Y) ./setup install || {
                            printf "%bInstall failed, aborting...%b\n" "$STY_RED" "$STY_RST"
                            return 1
                    } ;;
                    *) return ;;
                esac
        fi ;;
        *) return ;;
    esac
}

function quick_update() {
    printf "This process will update the repo and copy only the shell files, any local change to the repo will be stashed.\n"
    printf "A full re-install/update of the shell is recommended if some bugs are encountered.\n"
    read -r -p "===> Continue? [y/n]: " p
    case $p in
        y|Y)
            git stash && git pull || {
                printf "%bRepo update failed, aborting...%b\n" "$STY_RED" "$STY_RST"
                return 1
            }
            ./setup install-files --force --skip-allgreeting || {
                printf "%bQuick update failed, aborting...%b\n" "$STY_RED" "$STY_RST"
                return 1
            }
            printf "%bStarting Quickshell...%b\n" "$STY_CYAN" "$STY_RST"
            killall qs 2>/dev/null || true
            qs -c ii > /dev/null 2>&1 & disown $!
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
    read -r -p "===> [1/2/q]: " p
    case $p in
        1) install ;;
        2) quick_update ;;
        q) exit 0 ;;
        *) printf "%bInvalid option%b\n" "$STY_RED" "$STY_RST";;
    esac
done

