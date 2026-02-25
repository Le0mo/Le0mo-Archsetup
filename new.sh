#!/bin/bash
for item in "$HOME/.Github/Le0mo-Archsetup/dotfiles/.config/"*; do
    name=$(basename "$item")
    rm -rf "$HOME/.local/share/shorin-niri/dotfiles/.config/$name"
    ln -s "$HOME/.Github/Le0mo-Archsetup/dotfiles/.config/$name" "$HOME/.local/share/shorin-niri/dotfiles/.config/$name"
done

for item in "$HOME/.Github/Le0mo-Archsetup/dotfiles/.local/bin/"*; do
    name=$(basename "$item")
    rm -rf "$HOME/.local/share/shorin-niri/dotfiles/.local/bin/$name"
    ln -s "$HOME/.Github/Le0mo-Archsetup/dotfiles/.local/bin/$name" "$HOME/.local/share/shorin-niri/dotfiles/.local/bin/$name"
done

rm -rf "$HOME/.local/share/shorin-niri/wallpapers"
ln -s "$HOME/.Github/Le0mo-Archsetup/wallpapers" "$HOME/.local/share/shorin-niri/wallpapers"
