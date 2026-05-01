#!/usr/bin/env bash

STY_CYAN='\e[36m'
STY_RED='\e[31m'
STY_RST='\e[00m'
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}

if [ "$(id -u)" -eq 0 ]; then
    printf "%bError: [%s] must not be run as root%b\n" "$STY_RED" "$0" "$STY_RST"
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    printf "%bError: Arch Linux or an Arch-based distro required%b\n" "$STY_RED" "$STY_RST"
    exit 1
fi

set -e

printf "███████╗████████╗██████╗${STY_CYAN} ██╗██╗${STY_RST}██████╗\n"
printf "██╔════╝╚══██╔══╝██╔══██╗${STY_CYAN}╚═╝╚═╝${STY_RST}██╔══██╗\n"
printf "███████╗   ██║   ██████╔╝${STY_CYAN}██╗██╗${STY_RST}██████╔╝\n"
printf "╚════██║   ██║   ██╔══██╗${STY_CYAN}██║██║${STY_RST}██╔═══╝\n"
printf "███████║   ██║   ██║  ██║${STY_CYAN}██║██║${STY_RST}██║\n"
printf "╚══════╝   ╚═╝   ╚═╝  ╚═╝${STY_CYAN}╚═╝╚═╝${STY_RST}╚═╝\n"
printf "\n"
