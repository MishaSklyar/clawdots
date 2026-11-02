#!/usr/bin/env python3
"""Clawd desktop pet: a click-through Wayland overlay.

Walks along the bottom of the screen and across the tops of Hyprland windows,
jumps up onto windows, falls when the window under it goes away, hops when you
switch workspace or open a window, and falls asleep (z z z) when nothing happens.
Run with LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so (see hyprland.lua).
"""
import json
import math
import os
import random
import socket
import subprocess
import time
import cairo
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, GLib, Gtk4LayerShell as LS  # noqa: E402

ORANGE = (0xDA / 255, 0x77 / 255, 0x56 / 255)
LIGHT = (0xF4 / 255, 0xB3 / 255, 0x9A / 255)
BLACK = (0, 0, 0)
U = 4                      # one sprite pixel = 4 screen px
SW, SH = 12 * U, 8 * U     # sprite is a 12x8 grid
HEAD = 7 * U               # room above the sprite for z's and "!"
W, H = SW + 2 * U, SH + HEAD
SPEED = 45.0               # px/s walking
GRAVITY = 1400.0
MAX_JUMP = 260             # px: highest ledge it will try to jump onto
SLEEP_AFTER = 40.0         # s without anything happening
TICK_MS = 16

# sprite grid (row, col): body, arms, legs. eyes are drawn black on top.
BODY = (
    [(r, c) for r in (0, 1, 4, 5) for c in range(2, 10)]
    + [(r, c) for r in (2, 3) for c in range(12)]
)
LEGS = (2, 4, 7, 9)
Z_GLYPH = ((0, 0), (0, 1), (0, 2), (1, 1), (2, 0), (2, 1), (2, 2))   # 3x3 "z"
BANG = ((0, 0), (1, 0), (2, 0), (4, 0))                               # "!"


def hyprctl(*args):
    try:
        return json.loads(subprocess.run(["hyprctl", "-j", *args], capture_output=True, text=True, timeout=1).stdout)
    except Exception:
        return None


class Pet(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        mon = (hyprctl("monitors") or [{"width": 1920, "height": 1080}])[0]
        self.sw, self.sh = mon["width"], mon["height"]
        self.x = random.uniform(100, self.sw - 200)   # sprite left
        self.y = 0.0                    # feet y
        self.vx = 0.0
        self.vy = 0.0
        self.dir = 1
        self.state = "idle"             # idle | walk | sleep
        self.timer = 1.0
        self.frame = 0
        self.frame_t = 0.0
        self.blink = 0.0
        self.bang = 0.0                 # seconds left showing "!"
        self.quiet = 0.0                # seconds since anything happened
        self.t = 0.0
        self.platforms = []             # (x0, x1, top_y)
        self.floor_y = self.sh
        self.grounded = False
        self.last_pos = None
        self.last_look = None

        LS.init_for_window(self)
        LS.set_layer(self, LS.Layer.OVERLAY)
        # tiny window pinned top-left; we move it with margins (absolute screen coords)
        LS.set_anchor(self, LS.Edge.TOP, True)
        LS.set_anchor(self, LS.Edge.LEFT, True)
        LS.set_anchor(self, LS.Edge.BOTTOM, False)
        LS.set_anchor(self, LS.Edge.RIGHT, False)
        self.set_default_size(W, H)
        LS.set_exclusive_zone(self, -1)
        LS.set_keyboard_mode(self, LS.KeyboardMode.NONE)
        LS.set_namespace(self, "clawd-pet")

        self.set_decorated(False)
        css = Gtk.CssProvider()
        css.load_from_string("window, window.background { background: transparent; }")
        Gtk.StyleContext.add_provider_for_display(self.get_display(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.area = Gtk.DrawingArea()
        self.area.set_content_width(W)
        self.area.set_content_height(H)
        self.area.set_draw_func(self.draw)
        self.set_child(self.area)
        self.connect("realize", self.on_realize)

        self.refresh_platforms()
        GLib.timeout_add(1500, self.refresh_platforms)   # fallback; events refresh sooner
        GLib.timeout_add(TICK_MS, self.tick)
        self.listen_events()

    def on_realize(self, _w):
        surface = self.get_native().get_surface()
        surface.set_input_region(cairo.Region())    # click-through

    # hyprland events ---------------------------------------------------
    def listen_events(self):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        run = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        if not sig:
            return
        try:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(f"{run}/hypr/{sig}/.socket2.sock")
        except OSError:
            return
        self.buf = b""
        GLib.io_add_watch(self.sock.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, self.on_socket)

    def on_socket(self, _fd, cond):
        if cond & GLib.IO_HUP:
            return False
        data = self.sock.recv(65536)
        if not data:
            return False
        self.buf += data
        *lines, self.buf = self.buf.split(b"\n")
        for line in lines:
            ev = line.split(b">>", 1)[0].decode(errors="ignore")
            if ev in ("workspacev2", "openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen"):
                GLib.timeout_add(120, self.refresh_once)   # let the layout settle
            if ev == "workspacev2":
                self.react(bang=False)
            elif ev == "openwindow":
                self.react(bang=True)
        return True

    def react(self, bang):
        was_asleep = self.state == "sleep"
        self.quiet = 0
        if bang or was_asleep:
            self.bang = 1.0
        if was_asleep:
            self.state, self.timer = "idle", 0.6
        if self.grounded:
            self.vy = -360 if not was_asleep else -460
            self.vx = 0
            self.grounded = False

    # world ---------------------------------------------------------
    def refresh_once(self):
        self.refresh_platforms()
        return False

    def refresh_platforms(self):
        ws = hyprctl("activeworkspace")
        clients = hyprctl("clients") or []
        plats = []
        if ws:
            for c in clients:
                if c.get("workspace", {}).get("id") != ws["id"] or not c.get("mapped") or c.get("hidden"):
                    continue
                if c.get("fullscreen"):
                    continue
                x, y = c["at"]
                w, _h = c["size"]
                if y > 40:                      # skip things pinned under the bar
                    plats.append((x, x + w, y))
        self.platforms = plats
        return True

    def support_y(self, cx, feet):
        """Highest surface at or below feet that covers x=cx."""
        best = self.floor_y
        for x0, x1, top in self.platforms:
            if x0 + 4 <= cx <= x1 - 4 and top >= feet - 3 and top < best:
                best = top
        return best

    def pick_jump(self):
        """A ledge above us within reach, or None. Returns (target_cx, top)."""
        cx = self.x + SW / 2
        options = []
        for x0, x1, top in self.platforms:
            rise = self.y - top
            if 24 < rise <= MAX_JUMP and x1 - x0 > SW + 16:
                tx = min(max(cx, x0 + SW), x1 - SW)    # nearest point on the ledge
                if abs(tx - cx) < 320:
                    options.append((tx, top))
        return random.choice(options) if options else None

    def jump_to(self, tx, top):
        rise = self.y - top + 40                        # clear the edge by 40px
        vy = math.sqrt(2 * GRAVITY * rise)
        t = vy / GRAVITY + math.sqrt(2 * 40 / GRAVITY)   # up to apex, then down 40px
        self.vy = -vy
        self.vx = (tx - (self.x + SW / 2)) / t
        self.dir = 1 if self.vx >= 0 else -1
        self.grounded = False
        self.state = "idle"

    # logic ---------------------------------------------------------
    def tick(self):
        dt = TICK_MS / 1000.0
        self.t += dt
        self.quiet += dt
        self.bang = max(0.0, self.bang - dt)
        cx = self.x + SW / 2
        ground = self.support_y(cx, self.y)

        if self.y < ground - 0.5 or self.vy < 0:
            self.vy += GRAVITY * dt
            self.x = max(0, min(self.x + self.vx * dt, self.sw - SW))
            ground = self.support_y(self.x + SW / 2, self.y)
            self.y = min(self.y + self.vy * dt, ground)
            self.grounded = self.y >= ground
            if self.grounded:
                self.vy = self.vx = 0
        else:
            self.y = ground
            self.vy = self.vx = 0
            self.grounded = True

        if self.grounded and self.state != "sleep":
            self.timer -= dt
            if self.state == "walk":
                self.x += self.dir * SPEED * dt
                self.frame_t += dt
                if self.frame_t > 0.18:
                    self.frame_t = 0
                    self.frame ^= 1
                nx = self.x + SW / 2
                # at the end of a platform: turn around, or sometimes step off
                if self.support_y(nx + self.dir * 6, self.y) > self.y + 2 and random.random() < 0.7:
                    self.dir *= -1
                if self.x < 0 or self.x > self.sw - SW:
                    self.dir *= -1
                    self.x = max(0, min(self.x, self.sw - SW))
            if self.timer <= 0:
                if self.quiet > SLEEP_AFTER:
                    self.state, self.frame = "sleep", 0
                elif self.state == "idle":
                    target = self.pick_jump() if random.random() < 0.35 else None
                    if target:
                        self.jump_to(*target)
                        self.timer = random.uniform(1, 2)
                    else:
                        self.state = "walk"
                        self.dir = random.choice((-1, 1))
                        self.timer = random.uniform(2, 6)
                else:
                    self.state = "idle"
                    self.frame = 0
                    self.timer = random.uniform(1.5, 4)

        self.blink -= dt
        if self.blink < -3 and random.random() < 0.02:
            self.blink = 0.12
        if self.blink < -3:
            self.blink = -3

        # move the window only when the pixel position changes
        pos = (round(self.x) - U, round(self.y) - H)
        if pos != self.last_pos:
            self.last_pos = pos
            LS.set_margin(self, LS.Edge.LEFT, max(0, pos[0]))
            LS.set_margin(self, LS.Edge.TOP, max(0, pos[1]))
        # redraw only when the sprite itself changes
        zphase = int(self.t * 3) if self.state == "sleep" else 0
        look = (self.state, self.frame, self.blink <= 0, self.dir, self.grounded, self.bang > 0, zphase)
        if look != self.last_look:
            self.last_look = look
            self.area.queue_draw()
        return True

    # draw ----------------------------------------------------------
    def draw(self, _area, cr, _w, _h):
        cr.set_antialias(cairo.ANTIALIAS_NONE)
        ox, oy = U, HEAD
        asleep = self.state == "sleep"
        airborne = not self.grounded
        squash = 1 if asleep else 0      # asleep: body sits one pixel lower, legs tucked

        cr.set_source_rgb(*ORANGE)
        for r, c in BODY:
            cr.rectangle(ox + c * U, oy + (r + squash) * U, U, U)
        walking = self.state == "walk" and self.grounded
        down = (2, 7) if self.frame == 0 else (4, 9)
        for c in LEGS:
            for r in (6, 7):
                if r == 7 and (asleep or (walking and c not in down) or (airborne and c in (4, 7))):
                    continue
                cr.rectangle(ox + c * U, oy + (r + (squash if r == 6 else 0)) * U, U, U)
        cr.fill()

        # eyes: look where we're going; closed lines when asleep or blinking
        cr.set_source_rgb(*BLACK)
        shift = 0 if self.state == "idle" and self.grounded else self.dir
        for c in (3, 8):
            ex = ox + (c + shift) * U
            if asleep or self.blink > 0:
                cr.rectangle(ex, oy + (1 + squash) * U + U // 2, U, U // 2)
            else:
                cr.rectangle(ex, oy + (1 + squash) * U, U, U)
        cr.fill()

        if asleep:   # three z's drifting up and to the right
            cr.set_source_rgb(*LIGHT)
            p = int(self.t * 3) % 3
            for i in range(3):
                if (i + p) % 3 == 2:
                    continue
                zx = ox + (8 + i * 1.5) * U
                zy = oy - (1.5 + i * 2.2) * U
                for r, c in Z_GLYPH:
                    cr.rectangle(zx + c * U / 2, zy + r * U / 2, U / 2, U / 2)
            cr.fill()
        elif self.bang > 0:
            cr.set_source_rgb(*LIGHT)
            for r, c in BANG:
                cr.rectangle(ox + 5.5 * U, oy - 6 * U + r * U, U, U)
            cr.fill()


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.clawdots.pet")

    def do_activate(self):
        Pet(self).present()


if __name__ == "__main__":
    App().run()
