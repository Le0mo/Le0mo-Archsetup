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

chmod +x ~/.config/waybar/scripts/island/*.sh
chmod +x ~/.config/waybar/scripts/island/*.py
chmod +x ~/.local/bin/Le0mo-update

mv "$HOME/.Github/Le0mo-Archsetup/冬眠-司南.flac" "$HOME/Music/"
mkdir -p "$HOME/.lyrics"

sudo pacman -S --noconfirm mpd mpc ncmpcpp yad aria2 python-mpd2

pkill waybar || true
waybar -c $HOME/.config/waybar/config.jsonc -s $HOME/.config/waybar/style.css &

mpd
~/.config/waybar/scripts/island/start_island.sh &
nohup ~/.config/waybar/scripts/island/mpd_lyrics_watcher.sh >/dev/null 2>&1 &

