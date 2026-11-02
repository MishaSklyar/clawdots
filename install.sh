#!/bin/sh
# clawdots installer: symlink configs into ~/.config (existing files are moved to *.bak-<date>)
# and report missing dependencies. Safe to re-run.
set -eu
DOTS=$(cd "$(dirname "$0")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
stamp=$(date +%Y%m%d-%H%M%S)

link() {  # link <source in repo> <target>
	src="$DOTS/$1" dst="$2"
	if [ "$(readlink "$dst" 2>/dev/null)" = "$src" ]; then echo "ok    $dst"; return; fi
	mkdir -p "$(dirname "$dst")"
	if [ -e "$dst" ] || [ -L "$dst" ]; then mv "$dst" "$dst.bak-$stamp"; echo "saved $dst.bak-$stamp"; fi
	ln -s "$src" "$dst"
	echo "link  $dst -> $src"
}

link hypr                "$CFG/hypr"
link ghostty/config      "$CFG/ghostty/config"
link kitty/kitty.conf    "$CFG/kitty/kitty.conf"
link fuzzel/fuzzel.ini   "$CFG/fuzzel/fuzzel.ini"
# quickshell runs straight from the repo (qs -p ~/clawdots/quickshell); waybar/ is a legacy fallback bar.

chmod +x "$DOTS/bin/"*
[ -e "$DOTS/wallpaper/current" ] || ln -s "$DOTS/wallpaper/clawd.png" "$DOTS/wallpaper/current"   # hyprpaper reads this

missing=""
for b in Hyprland qs hyprpaper hyprlock hypridle ghostty fuzzel grim slurp wl-copy wl-paste cliphist \
         notify-send playerctl wpctl python3 wf-recorder ffmpeg; do
	command -v "$b" >/dev/null 2>&1 || missing="$missing $b"
done
[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ] || missing="$missing polkit-gnome"
[ -e /usr/lib/libgtk4-layer-shell.so ] || missing="$missing gtk4-layer-shell"
python3 -c 'import gi, cairo' 2>/dev/null || missing="$missing python-gobject/python-cairo"
fc-list | grep -qi 'JetBrains Mono' || missing="$missing ttf-jetbrains-mono"
if [ -n "$missing" ]; then echo "missing:$missing"; else echo "all dependencies found"; fi

# quickshell is the notification daemon; stop other daemons grabbing the bus name first
if command -v swaync >/dev/null && [ "$(systemctl --user is-enabled swaync 2>/dev/null)" != masked ]; then
	echo "note: swaync is installed. quickshell handles notifications; disable it with: systemctl --user mask --now swaync"
fi
