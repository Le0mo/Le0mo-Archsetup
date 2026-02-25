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
mkdir Github
cd Github
git clone https://github.com/Le0mo/Le0mo-Archsetup.git
```
更换配置
```bash
SRC="$HOME/Github/Le0mo-Archsetup/dotfiles/.config"
DST="$HOME/.local/share/shorin-niri/dotfiles/.config"
shopt -s dotglob nullglob
for src in "$SRC"/* "$SRC"/.[!.]* "$SRC"/..?*; do
  [ -e "$src" ] || continue
  name="${src#$SRC/}"
  target="$DST/$name"
  echo "rm -rf \"$target\""
  echo "ln -s \"$src\" \"$target\""
done
```