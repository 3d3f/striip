#!/bin/bash

# Variables
STRIIP_REPO="https://github.com/3d3f/striip.git"

# UI
show_banner() {
  clear
  local C="\033[0;36m" 
  local M="\033[0;35m" 
  local R="\033[0m"    

  echo -e "${C}███████╗████████╗██████╗ ${M}██╗██╗${C}██████╗ "
  echo -e "${C}██╔════╝╚══██╔══╝██╔══██╗${M}╚═╝╚═╝${C}██╔══██╗"
  echo -e "${C}███████╗   ██║   ██████╔╝${M}██╗██╗${C}██████╔╝"
  echo -e "${C}╚════██║   ██║   ██╔══██╗${M}██║██║${C}██╔═══╝ "
  echo -e "${C}███████║   ██║   ██║  ██║${M}██║██║${C}██║     "
  echo -e "${C}╚══════╝   ╚═╝   ╚═╝  ╚═╝${M}╚═╝╚═╝${C}╚═╝     ${R}"
  echo -e "\033[0m"
  echo ""
}

# Checks
check_arch() {
  if ! command -v pacman &>/dev/null; then
    echo ""
    gum log --level error "pacman not found. Only Arch Linux or Arch-based distros supported."
    echo ""
    exit 1
  fi
}

check_git() {
  if ! command -v git &>/dev/null; then
    gum log --level warn "Missing dependency: git"
    echo -n "Do you want to install git now? (y/n): "
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo ""
      sudo pacman -S --needed git
      if [ $? -ne 0 ]; then
        echo ""
        gum log --level error "Git installation failed. Exiting."
        echo ""
        exit 1
      fi
    else
      echo ""
      gum log --level error "Git is required to continue. Exiting."
      echo ""
      exit 1
    fi
  fi
}

check_gum() {
  if ! command -v gum &>/dev/null; then
    echo -e "This install script requires \033[1;34mgum\033[0m for its TUI."
    echo -e "Check \033[0;90mhttps://github.com/charmbracelet/gum\033[0m for more info."
    echo ""
    echo -n "Do you want to install gum now? (y/n): "
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo ""
      sudo pacman -S --needed gum
      if [ $? -ne 0 ]; then
        echo ""
        gum log --level error "Gum installation failed. Exiting."
        echo ""
        exit 1
      fi
      echo ""
      gum log --level info "Gum installed. Starting manager..."
      sleep 1
    else
      echo ""
      gum log --level error "Gum is required to run this script. Exiting."
      echo ""
      exit 1
    fi
  fi
}

# Functions
install_dots() {
  show_banner
  gum style --foreground 2 " [ INSTALL STRiiP ]"
  echo ""
  echo -e "\033[0m This process will:"
  echo -e " \033[0;90m-\033[0m Clone \033[1;37m$STRIIP_REPO\033[0m into \033[1;37m~/.cache/striip\033[0m"
  echo -e " \033[0;90m-\033[0m Run the \033[1;35mii\033[0m setup"
  echo ""
  if ! gum confirm "Do you want to proceed?"; then
    return
  fi
  show_banner
  local TARGET_DIR="$HOME/.cache/striip"
  local git_exit=0
  gum style "Checking repository..."
  echo ""
  if [ -d "$TARGET_DIR/.git" ]; then
    local current_url
    current_url=$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null)
    if [ "$current_url" != "$STRIIP_REPO" ]; then
      gum log --level error "Directory exists but belongs to a different repo."
      sleep 2
      return
    fi
    local REPO_MODE
    REPO_MODE=$(gum choose --header "Existing repository found at $(gum style --foreground 4 "$TARGET_DIR")" \
      "Force remote sync (overwrites local repo)" \
      "Skip sync (use existing repo)" \
      "Cancel")
    if [[ -z "$REPO_MODE" || "$REPO_MODE" == "Cancel" ]]; then
      gum log --level warn "Operation cancelled by user."
      sleep 1
      return
    fi
    show_banner
    case "$REPO_MODE" in
      "Force remote sync"*)
      gum spin --spinner dot --title "Syncing repository from remote..." -- bash -c "
        git -C '$TARGET_DIR' fetch origin -q &&
        git -C '$TARGET_DIR' reset --hard origin/main -q &&
        git -C '$TARGET_DIR' clean -fd -q &&
        git -C '$TARGET_DIR' submodule update --init --recursive -q
      "
        git_exit=$?
        ;;
      "Skip sync"*)
        gum log --level info "Using existing repository."
        echo ""
        ;;
    esac
  else
    if [ -d "$TARGET_DIR" ]; then
      gum log --level error "Directory exists but is not a valid git repository."
      gum log --level info "Cleaning up and preparing fresh clone..."
      rm -rf "$TARGET_DIR"
    fi
    gum spin --spinner dot --title "Cloning repository..." -- \
      git clone "$STRIIP_REPO" "$TARGET_DIR" -q --recurse-submodules
    git_exit=$?
  fi
  if [ "$git_exit" -ne 0 ]; then
    gum log --level error "Repository sync failed. Check your connection or git status."
    sleep 2
    return
  fi
  gum style --foreground 2 "✔ Repository ready."
  echo ""
  gum style --foreground 5 "[ SETUP ] Ready to install."
  echo ""
  if gum confirm "Do you want to run './setup install' now?"; then
    cd "$TARGET_DIR" || exit
    ./setup install
  fi
}

# Initialization
show_banner
check_arch
check_git
check_gum

# Main loop
while true; do
  show_banner
  choice=$(gum choose --header "" "Install STRiiP" "Exit")
  [[ -z "$choice" || "$choice" == "Exit" ]] && clear && exit 0

  case "$choice" in
    "Install STRiiP")
      install_dots
      ;;
  esac
done