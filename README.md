# Le0mo-Archsetup
安装shorin niri

```bash
bash <(curl -L shorin.xyz/archsetup)
```
进入niri后
```bash
sudo pacman -S clang
niri-blur-toggle
```
克隆仓库
```bash
mkdir ~/.Github
cd ~/.Github
git clone https://github.com/Le0mo/Le0mo-Archsetup.git
```
更换配置
```bash
chmod +x ~/.Github/Le0mo-Archsetup/install.sh
bash ~/.Github/Le0mo-Archsetup/install.sh
```
# 灵动岛适配
```bash
mpd
~/.config/waybar/scripts/island/start_island.sh
nohup ~/.config/waybar/scripts/island/mpd_lyrics_watcher.sh >/dev/null 2>&1 &

```