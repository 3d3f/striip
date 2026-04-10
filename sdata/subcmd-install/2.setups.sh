# This script is meant to be sourced.
# It's not for directly running.

function setup_user_group(){
  if [[ -z $(getent group i2c) ]]; then
    x sudo groupadd i2c
  fi
  x sudo usermod -aG video,i2c,input "$(whoami)"
}
#####################################################################################
# These python packages are installed using uv into the venv (virtual environment). Once the folder of the venv gets deleted, they are all gone cleanly. So it's considered as setups, not dependencies.
showfun install-python-packages
v install-python-packages

showfun setup_user_group
v setup_user_group

if [[ ! -z $(systemctl --version) ]]; then
  v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  # When $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR are empty, it commonly means that the current user has been logged in with `su - user` or `ssh user@hostname`. In such case `systemctl --user enable <service>` is not usable. It should be `sudo systemctl --machine=$(whoami)@.host --user enable <service>` instead.
  if [[ ! -z "${DBUS_SESSION_BUS_ADDRESS}" ]]; then
    v systemctl --user enable ydotool --now
  else
    v sudo systemctl --machine=$(whoami)@.host --user enable ydotool --now
  fi
  v sudo systemctl enable bluetooth --now
else
  printf "${STY_RED}"
  printf "====================INIT SYSTEM NOT FOUND====================\n"
  printf "${STY_RST}"
  pause
fi

v gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500'
v gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
v kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly
