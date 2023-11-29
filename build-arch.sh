#!/usr/bin/env bash

######################################################################
# @author      : Ruan E. Formigoni (ruanformigoni@gmail.com)
# @file        : build
# @created     : Friday Nov 24, 2023 19:06:13 -03
#
# @description : 
######################################################################

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

build_dir="$SCRIPT_DIR/build"

rm -rf "$build_dir"; mkdir "$build_dir"; cd "$build_dir"

# Fetch latest release
read -r url_pcsx2 < <(wget --header="Accept: application/vnd.github+json" -O - \
  https://api.github.com/repos/PCSX2/pcsx2/releases 2>&1 |
  grep -o "https://.*\.AppImage" | sort -V | tail -n1)
wget "$url_pcsx2"

# Fetched file name
appimage_pcsx2="$(basename "$url_pcsx2")"

# Make executable
chmod +x "$build_dir/$appimage_pcsx2"

# Extract appimage
"$build_dir/$appimage_pcsx2" --appimage-extract

# Fetch container
if ! [ -f "$build_dir/arch.tar.xz" ]; then
  wget "https://gitlab.com/api/v4/projects/43000137/packages/generic/fim/continuous/arch.tar.xz"
fi

# Extract container
[ ! -f "$build_dir/arch.fim" ] || rm "$build_dir/arch.fim"
tar xf arch.tar.xz

# FIM_COMPRESSION_LEVEL
export FIM_COMPRESSION_LEVEL=6

# Resize
"$build_dir"/arch.fim fim-resize 3G

# Update
"$build_dir"/arch.fim fim-root fakechroot pacman -Syu --noconfirm

# Install dependencies
"$build_dir"/arch.fim fim-root fakechroot pacman -S libxkbcommon libxkbcommon-x11 \
  lib32-libxkbcommon lib32-libxkbcommon-x11 libsm lib32-libsm fontconfig \
  lib32-fontconfig noto-fonts --noconfirm

# Install video packages
"$build_dir"/arch.fim fim-root fakechroot pacman -S xorg-server mesa lib32-mesa \
  glxinfo pcre xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon \
  xf86-video-intel vulkan-intel lib32-vulkan-intel vulkan-tools --noconfirm

# Compress main image
"$build_dir"/arch.fim fim-compress

# Compress pcsx2
"$build_dir"/arch.fim fim-exec mkdwarfs -i "$build_dir"/squashfs-root/usr -o "$build_dir/pcsx2.dwarfs"

# Include pcsx2
"$build_dir"/arch.fim fim-include-path "$build_dir"/pcsx2.dwarfs "/pcsx2.dwarfs"

# Include runner script
{ tee "$build_dir"/pcsx2.sh | sed -e "s/^/-- /"; } <<-'EOL'
#!/bin/bash

export LD_LIBRARY_PATH="/pcsx2/lib:$LD_LIBRARY_PATH"

/pcsx2/bin/pcsx2-qt "$@"
EOL
chmod +x "$build_dir"/pcsx2.sh
"$build_dir"/arch.fim fim-root cp "$build_dir"/pcsx2.sh /fim/pcsx2.sh

# Set default command
"$build_dir"/arch.fim fim-cmd /fim/pcsx2.sh

# Set perms
"$build_dir"/arch.fim fim-perms-set wayland,x11,pulseaudio,gpu,session_bus,input,usb

# Set up /usr overlay
"$build_dir"/arch.fim fim-config-set overlay.usr "/usr overlay"
#shellcheck disable=2016
"$build_dir"/arch.fim fim-config-set overlay.usr.host '"$FIM_DIR_BINARY"/."$FIM_FILE_BINARY.config/overlays/usr"'
"$build_dir"/arch.fim fim-config-set overlay.usr.cont '/usr'

# Rename
mv "$build_dir/arch.fim" pcsx2-arch.fim


# // cmd: !./%
