#!/bin/bash

STRIIP_REPO="https://github.com/3d3f/striip.git"
TARGET_DIR="$HOME/.cache/striip"

C="\033[0;36m" M="\033[0;35m" R="\033[0m"
GREEN="\033[0;32m" RED="\033[0;31m" GRAY="\033[0;90m" BOLD="\033[1;37m"

show_banner() {
  clear
  echo -e "${C}███████╗████████╗██████╗ ${M}██╗██╗${C}██████╗ "
  echo -e "${C}██╔════╝╚══██╔══╝██╔══██╗${M}╚═╝╚═╝${C}██╔══██╗"
  echo -e "${C}███████╗   ██║   ██████╔╝${M}██╗██╗${C}██████╔╝"
  echo -e "${C}╚════██║   ██║   ██╔══██╗${M}██║██║${C}██╔═══╝ "
  echo -e "${C}███████║   ██║   ██║  ██║${M}██║██║${C}██║     "
  echo -e "${C}╚══════╝   ╚═╝   ╚═╝  ╚═╝${M}╚═╝╚═╝${C}╚═╝     ${R}\n"
}

die() { echo -e "\n${RED}Error: $1${R}\n"; exit 1; }

check_arch() {
  command -v pacman &>/dev/null || die "pacman not found. Only Arch-based distros supported."
}

install_pkg() {
  local pkg=$1
  if ! command -v "$pkg" &>/dev/null; then
    gum log --level warn "Missing dependency: $pkg"
    gum confirm "Install $pkg now?" || die "$pkg is required. Exiting."
    sudo pacman -S --needed --noconfirm "$pkg" || die "$pkg installation failed."
  fi
}

check_gum() {
  if ! command -v gum &>/dev/null; then
    echo -e "This script requires \033[1;34mgum\033[0m (https://github.com/charmbracelet/gum)"
    echo -n "Install gum now? (y/n): "
    read -r response
    [[ "$response" =~ ^[yY] ]] || die "gum is required. Exiting."
    sudo pacman -S --needed --noconfirm gum || die "gum installation failed."
    echo -e "\n${GREEN}✔ gum installed.${R}"; sleep 1
  fi
}

sync_repo() {
  if [ -d "$TARGET_DIR" ]; then
    gum spin --spinner dot --title "Removing $TARGET_DIR..." -- rm -rf "$TARGET_DIR"
    echo -e "${GREEN}✔${R} Removed $TARGET_DIR"
  fi
  gum spin --spinner dot --title "Cloning STRiiP..." -- \
    git clone "$STRIIP_REPO" "$TARGET_DIR" -q --recurse-submodules
  echo -e "${GREEN}✔${R} Cloned STRiiP into $TARGET_DIR"
}

install_dots() {
  show_banner
  gum style --foreground 6 "[ INSTALL STRiiP ]"
  echo -e "\nThis process will:"
  [ -d "$TARGET_DIR" ] && echo -e "${GRAY}•${R} Delete ${BOLD}$TARGET_DIR${R}"
  echo -e "${GRAY}•${R} Clone ${BOLD}$STRIIP_REPO${R} into ${BOLD}$TARGET_DIR${R}"
  echo -e "${GRAY}•${R} Run the ${M}ii${R} setup\n"
  gum confirm --selected.background "6" --selected.foreground "0" --unselected.foreground "7" --unselected.background "" --prompt.foreground "6" "Do you want to proceed?" || return
  show_banner
  gum style --foreground 6 "[ INSTALL STRiiP ]"
  echo ""
  sync_repo || return
  echo ""
  gum style --foreground 5 "Running './setup install'..."
  echo ""
  cd "$TARGET_DIR" && ./setup install
}

# Main
show_banner
check_arch
check_gum
install_pkg git

while true; do
  show_banner
  choice=$(gum choose --header "" --cursor.foreground "6" --item.foreground "7" --selected.foreground "6" "INSTALL STRiiP" "Exit")
  [[ -z "$choice" || "$choice" == "Exit" ]] && clear && exit 0
  [[ "$choice" == "INSTALL STRiiP" ]] && install_dots
done