#!/usr/bin/env bash

set -euo pipefail

# --- Security: Validate and sanitize paths ---
validate_path() {
    local path="$1"
    local description="$2"

    if [ ! -e "$path" ]; then
        echo "Error: $description not found: $path" >&2
        return 1
    fi

    if [ -L "$path" ]; then
        echo "Error: $description is a symbolic link (not allowed): $path" >&2
        return 1
    fi

    realpath "$path"
}

# --- Local user name ---
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME="$(eval echo "~$REAL_USER")"

if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    echo "Error: invalid user home directory" >&2
    exit 1
fi

# --- Directories ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="/usr/share/sddm/themes/striip-sddm"

# --- QML and Config Sources ---
COLORS_QML_SOURCE="$SCRIPT_DIR/Colors.qml"
SETTINGS_QML_SOURCE="$SCRIPT_DIR/Settings.qml"
CONF_FILE="$SCRIPT_DIR/striip-sddm.conf"

# Validate destination parent directory
if [ ! -d "$(dirname "$(dirname "$DEST")")" ]; then
    echo "Error: invalid destination directory: $DEST" >&2
    exit 2
fi

# --- Extract wallpaper path ---
WALLPAPER_PATH=""

# Extract wallpaper path from generated Settings.qml
if [ -f "$SETTINGS_QML_SOURCE" ]; then
    WALLPAPER_PATH=$(grep "background_wallpaperPath:" "$SETTINGS_QML_SOURCE" | cut -d '"' -f 2 || true)
fi

# Fallback from Colors.qml
if [ -z "$WALLPAPER_PATH" ]; then
    if [ -f "$COLORS_QML_SOURCE" ]; then
        echo "Warning: wallpaper path not found in Settings.qml, using fallback from Colors.qml" >&2
        WALLPAPER_PATH=$(sed -n '5p' "$COLORS_QML_SOURCE" | sed 's/^\/\/ *//' | xargs || true)
    fi
fi

if [ -z "$WALLPAPER_PATH" ]; then
    echo "Error: Could not extract wallpaper path from Settings.qml or Colors.qml." >&2
    exit 4
fi

# Expand ~ to home dir
WALLPAPER_PATH="${WALLPAPER_PATH/#\~/$USER_HOME}"

# Convert relative to absolute if needed
if [[ "$WALLPAPER_PATH" != /* ]]; then
    WALLPAPER_PATH="$SCRIPT_DIR/$WALLPAPER_PATH"
fi

# Validate wallpaper file
if ! WALLPAPER_PATH=$(validate_path "$WALLPAPER_PATH" "wallpaper"); then
    exit 5
fi

if [ ! -f "$WALLPAPER_PATH" ]; then
    echo "Error: wallpaper is not a regular file: $WALLPAPER_PATH" >&2
    exit 5
fi

# --- Determine type and extension ---
WALLPAPER_BASENAME="$(basename "$WALLPAPER_PATH")"
WALLPAPER_EXT="${WALLPAPER_BASENAME##*.}"
WALLPAPER_EXT_LOWER=$(echo "$WALLPAPER_EXT" | tr '[:upper:]' '[:lower:]')
BACKGROUND_FILENAME="background.${WALLPAPER_EXT_LOWER}"

IMAGE_EXTS=("png" "jpg" "jpeg" "webp" "gif")
VIDEO_EXTS=("avi" "mp4" "mov" "mkv" "m4v" "webm")

IS_IMAGE=false
IS_VIDEO=false
for ext in "${IMAGE_EXTS[@]}"; do
    [[ "$WALLPAPER_EXT_LOWER" == "$ext" ]] && IS_IMAGE=true
done
for ext in "${VIDEO_EXTS[@]}"; do
    [[ "$WALLPAPER_EXT_LOWER" == "$ext" ]] && IS_VIDEO=true
done

if [ "$IS_IMAGE" = false ] && [ "$IS_VIDEO" = false ]; then
    echo "Error: unsupported wallpaper type: .$WALLPAPER_EXT_LOWER" >&2
    exit 6
fi

# --- Modify striip-sddm.conf dynamically ---
if [ ! -f "$CONF_FILE" ]; then
    echo "Error: striip-sddm.conf not found in $SCRIPT_DIR" >&2
    exit 9
fi

if [ "$IS_IMAGE" = true ]; then
    sed -i -E \
        -e "s|^BackgroundPlaceholder=\"[^\"]*\"|BackgroundPlaceholder=\"\"|" \
        -e "s|^Background=\"Backgrounds/background\.[^\"]+\"|Background=\"Backgrounds/${BACKGROUND_FILENAME}\"|" \
        "$CONF_FILE"
else
    PLACEHOLDER_FILENAME="placeholder.png"
    PLACEHOLDER_TEMP="/tmp/sddm_placeholder_$$.png"
    ffmpeg -y -i "$WALLPAPER_PATH" -ss 00:00:01.000 -vframes 1 "$PLACEHOLDER_TEMP" >/dev/null 2>&1 || {
        echo "Error: failed to generate thumbnail with ffmpeg" >&2
        exit 10
    }
    sed -i -E \
        -e "s|^BackgroundPlaceholder=\"[^\"]*\"|BackgroundPlaceholder=\"Backgrounds/${PLACEHOLDER_FILENAME}\"|" \
        -e "s|^Background=\"Backgrounds/background\.[^\"]+\"|Background=\"Backgrounds/${BACKGROUND_FILENAME}\"|" \
        "$CONF_FILE"
fi

# --- Validate required files ---
REQUIRED_FILES=(
    "$COLORS_QML_SOURCE"
    "$CONF_FILE"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ] || [ -L "$file" ]; then
        echo "Error: required file missing or invalid: $file" >&2
        exit 7
    fi
done

# --- Copy to destination ---
sudo mkdir -p -m 755 "$DEST/Components" "$DEST/Backgrounds" "$DEST/Themes"

sudo cp --no-dereference --preserve=mode,timestamps "$COLORS_QML_SOURCE" "$DEST/Components/Colors.qml"
if [ -f "$SETTINGS_QML_SOURCE" ]; then
    sudo cp --no-dereference --preserve=mode,timestamps "$SETTINGS_QML_SOURCE" "$DEST/Components/Settings.qml"
    sudo chmod 644 "$DEST/Components/Settings.qml"
fi
sudo cp --no-dereference --preserve=mode,timestamps "$WALLPAPER_PATH" "$DEST/Backgrounds/$BACKGROUND_FILENAME"
sudo cp --no-dereference --preserve=mode,timestamps "$CONF_FILE" "$DEST/Themes/striip-sddm.conf"

if [ "$IS_VIDEO" = true ]; then
    sudo cp --no-dereference --preserve=mode,timestamps "$PLACEHOLDER_TEMP" "$DEST/Backgrounds/$PLACEHOLDER_FILENAME"
    rm -f "$PLACEHOLDER_TEMP"
    sudo chmod 644 "$DEST/Backgrounds/$PLACEHOLDER_FILENAME"
fi

sudo chmod 644 \
    "$DEST/Components/Colors.qml" \
    "$DEST/Backgrounds/$BACKGROUND_FILENAME" \
    "$DEST/Themes/striip-sddm.conf"