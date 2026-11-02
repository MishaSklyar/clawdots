# clawdots

Hyprland (Lua config), black and flat, with one orange accent (Clawd, `#da7756`).

- **hypr/**: `hyprland.lua`, `hyprlock.conf` (clock + Clawd), `hypridle.conf` (lock after 5 min, screens off after 6), `hyprpaper.conf`
- **quickshell/**: bar, launcher with calculator (`SUPER+space`, try `2^10` or `15% of 80`), notification daemon + toasts,
  volume OSD, now-playing, popups for cpu / mem / vol / net / calendar. The bar's Clawd blinks, hops on workspace switch and runs when the cpu is busy.
- **pet/**: Clawd walks the bottom of the screen and the tops of windows, jumps up onto windows, falls when they close,
  hops when you switch workspace, shouts `!` at new windows, and falls asleep (z z z) after 40 s of quiet
- **motion**: springy window pop-in, sliding workspaces, an orange border gradient that slowly rotates around the focused window, soft orange glow, dimmed unfocused windows
- **bin/shot**: screenshots. **bin/rec**: screen recording (wf-recorder, NVENC). **bin/wall** `<image>`: set wallpaper (remembered via `wallpaper/current`)
- **ghostty/**, **kitty/**, **fuzzel/**: matching terminals and dmenu
- **wallpaper/make.py**: renders the Clawd wallpapers (`clawd`, `-plain`, `-inverted`, `-corner`, `-army`) and `clawd-lock.png`.
  The picker also lists `~/Pictures/Wallpapers` and `~/Pictures/wallpapers`.
- **waybar/**: legacy fallback bar (not started)

Install: `./install.sh` (symlinks into `~/.config`, backs up what was there, lists missing packages).

## keys

| keys | action |
|---|---|
| `SUPER+Return` | ghostty |
| `SUPER+space` | app search |
| `SUPER+E` | nautilus |
| `SUPER+V` | clipboard history |
| `SUPER+SHIFT+W` | wallpaper picker (arrows / `hl` browse, enter set, esc close) |
| hold `SUPER` + mouse into bottom-right corner | claude menu: claude.ai, claude code in wezterm, Claude app (`1`-`3` or arrows + enter) |
| `Print` / `SUPER+SHIFT+S` | screenshot region (copied + saved to `~/Pictures/Screenshots`) |
| `SHIFT+Print` | screenshot whole screen |
| `SUPER+R` / `SUPER+SHIFT+R` / `SUPER+ALT+R` | record region / screen / screen + desktop audio (press again, or click `rec` in the bar, to stop; saved to `~/Videos/Screencasts`) |
| `SUPER+N` / `SUPER+SHIFT+N` | clear notifications / toggle do-not-disturb |
| `SUPER+Q` / `SUPER+SHIFT+Q` | close window / force kill it |
| `SUPER+F` / `SUPER+SHIFT+F` | maximize / fullscreen |
| `SUPER+SHIFT+T` | float |
| `SUPER+T` | flip split direction |
| `SUPER+C` | center floating window |
| `SUPER+arrows` or `hjkl` | focus |
| `SUPER+SHIFT+arrows` or `hjkl` | move window |
| `SUPER+CTRL+arrows` or `hjkl` | resize |
| `SUPER+drag` (left / right button) | move / resize |
| `SUPER+1..0` / `SUPER+SHIFT+1..0` | workspace / send window to workspace |
| `SUPER+scroll`, `SUPER+PgUp/PgDn` | previous / next workspace |
| `SUPER+grave` / `SUPER+SHIFT+grave` | scratchpad / send to scratchpad |
| `SUPER+W`, `SUPER+[` `]` | group windows as tabs, flip tabs |
| `ALT+Tab` | cycle windows |
| `ALT+SHIFT` | switch keyboard layout (us / ru) |
| `SUPER+ALT+L` | lock (also relaunches hyprlock on the "lockscreen died" screen) |
| `SUPER+CTRL+ALT+L` | summon the "lockscreen died" screen on purpose (`SUPER+ALT+L` to recover) |
| `SUPER+SHIFT+P` | pet on / off |
| `SUPER+SHIFT+E` | quit Hyprland |

Bar: click now-playing to play/pause (right-click next, middle previous), scroll over workspaces to switch, scroll over `vol` to change volume, click the clock for a calendar,
click the layout tag to switch layout, right-click tray icons for their menu.
