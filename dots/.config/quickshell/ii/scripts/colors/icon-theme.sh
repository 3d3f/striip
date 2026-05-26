#!/usr/bin/env bash

case "$1" in
list)
    for d in /usr/share/icons/*/ ~/.local/share/icons/*/; do
        [ -d "$d" ] || continue
        [ -f "${d}index.theme" ] || continue
        [ -d "${d}cursors" ] && ! ([ -d "${d}scalable" ] || [ -d "${d}32x32" ] || [ -d "${d}48x48" ]) && continue
        name=$(basename "$d")
        case "$name" in
            hicolor|default|locolor|HighContrast) continue ;;
        esac
        echo "$name"
    done | sort -u
    ;;

    get)
        gsettings get org.gnome.desktop.interface icon-theme | tr -d "'"
        ;;

    set)
        theme="$2"
        if [ -n "$theme" ]; then
            gsettings set org.gnome.desktop.interface icon-theme "$theme"
            [ -x /usr/lib/plasma-changeicons ] && /usr/lib/plasma-changeicons "$theme"
            quickshell -c ii ipc call iconservice refresh 2>/dev/null || true
        fi
        ;;
esac