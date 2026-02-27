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
mkdir -p ~/.Github
cd ~/.Github
git clone https://github.com/Le0mo/Le0mo-Archsetup.git
cd Le0mo-Archsetup
chmod +x install.sh
./install.sh
```
配置waypaper
```bash
vim .config/waypaper/config.ini
```
删除```post_command```后面调用的脚本，只留下```post_command = $HOME/.config/scripts/matugen-update.sh $wallpaper```

最后打开waypaper，z键调出ui，把swww换成swaybg，切换一张自己喜欢的壁纸

再删除或注释.config/matugen/config.toml中的swayosd相关内容。