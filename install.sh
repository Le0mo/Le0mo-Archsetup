#!/bin/bash
for item in "$HOME/.Github/Le0mo-Archsetup/dotfiles/.config/"*; do
    name=$(basename "$item")
    if [ -e "$HOME/.local/share/shorin-niri/dotfiles/.config/$name" ] || [ -L "$HOME/.local/share/shorin-niri/dotfiles/.config/$name" ]; then
        rm -rf "$HOME/.local/share/shorin-niri/dotfiles/.config/$name"
        ln -s "$HOME/.Github/Le0mo-Archsetup/dotfiles/.config/$name" "$HOME/.local/share/shorin-niri/dotfiles/.config/$name"
    else
        ln -sf "$HOME/.Github/Le0mo-Archsetup/dotfiles/.config/$name" "$HOME/.config/$name"
    fi
done

rm -rf "$HOME/.local/share/shorin-niri/dotfiles/.config/waybar-niri-Win11Like"

ln -sf "$HOME/.Github/Le0mo-Archsetup/dotfiles/.local/bin/"* "$HOME/.local/share/shorin-niri/dotfiles/.local/bin/"

rm -rf "$HOME/.local/share/shorin-niri/wallpapers"
ln -s "$HOME/.Github/Le0mo-Archsetup/wallpapers" "$HOME/.local/share/shorin-niri/wallpapers"

chmod +x "$HOME/.config/waybar/scripts/island/"*

cd $HOME/.local/bin/
chmod +x $HOME/.local/bin/Le0mo-update

mv "$HOME/.Github/Le0mo-Archsetup/冬眠-司南.flac" "$HOME/Music/"
mkdir -p "$HOME/.lyrics"

sudo pacman -S mpd mpc ncmpcpp yad aria2 python-mpd2

