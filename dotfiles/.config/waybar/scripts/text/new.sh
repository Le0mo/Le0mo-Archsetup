#!/usr/bin/env python3
import gi
import subprocess
import signal

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell

ACTIONS = [
    ("", "swaylock || hyprlock"),
    ("", "niri msg action quit"),
    ("", "systemctl suspend"),
    ("", "systemctl reboot"),
    ("", "systemctl poweroff"),
]

WIN_W, WIN_H = 160, 520
MARGIN_L, MARGIN_T = 20, 20

# fuzzel 放到本窗口右侧：左边距 + 本窗口宽度 + 间隔
FUZZEL_GAP = 16
FUZZEL_X = MARGIN_L + WIN_W + FUZZEL_GAP
FUZZEL_Y = MARGIN_T

# True=右侧并排(top-left + margin)；False=居中(anchor=center，margin无效)
FUZZEL_SIDE_BY_SIDE = False

# 如果你“从 fuzzel 点回电源窗口”导致 fuzzel 失焦退出：
# 在这个宽限时间内（微秒）不关闭电源窗口
FUZZEL_EXIT_ENTER_GRACE_US = 300_000  # 300ms

CSS = b"""
window {
    background: rgba(20,20,20,0.85);
    border-radius: 24px;
}

.round-btn {
    min-width: 96px;
    min-height: 96px;
    padding: 0;
    border-radius: 999px;

    background: rgba(255,255,255,0.08);
    border: 1px solid rgba(255,255,255,0.10);

    font-size: 30px;
}

.round-btn:hover { background: rgba(255,255,255,0.18); }

.round-btn:focus-visible {
    outline: 2px solid rgba(255,255,255,0.35);
    outline-offset: 2px;
}
"""

class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.mini.wlogout.vertical")
        self.win = None
        self.fuzzel = None

        self._closing = False
        self._kill_timer = None

        # hover 近似代表“电源窗口还在交互中”
        self._hover = False
        self._last_enter_us = 0

    def do_startup(self):
        Gtk.Application.do_startup(self)
        try:
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self._on_unix_signal)
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self._on_unix_signal)
        except Exception:
            pass

    def do_activate(self):
        self.win = Gtk.ApplicationWindow(application=self)
        win = self.win
        win.set_default_size(WIN_W, WIN_H)
        win.set_resizable(False)
        win.set_decorated(False)

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.LEFT, MARGIN_L)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.TOP, MARGIN_T)

        # 不抢键盘：让 fuzzel/其他窗口拿到焦点
        Gtk4LayerShell.set_keyboard_mode(win, Gtk4LayerShell.KeyboardMode.NONE)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        win.connect("close-request", self._on_close_request)

        # 背景层：点空白关闭
        background = Gtk.Box()
        click_bg = Gtk.GestureClick.new()
        click_bg.set_button(0)
        click_bg.connect("released", self._on_blank_click)
        background.add_controller(click_bg)

        # hover 追踪
        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", self._on_enter)
        motion.connect("leave", self._on_leave)
        background.add_controller(motion)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        outer.set_margin_top(24)
        outer.set_margin_bottom(24)
        outer.set_margin_start(24)
        outer.set_margin_end(24)
        outer.set_halign(Gtk.Align.CENTER)
        outer.set_valign(Gtk.Align.CENTER)

        def run(cmd: str):
            # 点按钮：关闭自身+fuzzel，然后执行命令
            self._shutdown()
            subprocess.Popen(["sh", "-lc", cmd])

        for icon, cmd in ACTIONS:
            btn = Gtk.Button(label=icon)
            btn.add_css_class("round-btn")
            btn.connect("clicked", lambda _b, c=cmd: run(c))
            outer.append(btn)

        background.append(outer)
        win.set_child(background)
        win.present()

        self._start_fuzzel()

    def _on_enter(self, *_args):
        self._hover = True
        self._last_enter_us = GLib.get_monotonic_time()

    def _on_leave(self, *_args):
        self._hover = False
        # 不在这里自动关；“同时失焦”由 fuzzel 退出逻辑决定 + 点空白可关

    def _on_blank_click(self, *_args):
        self._shutdown()

    def _on_close_request(self, *_args):
        self._shutdown()
        return False

    def _on_unix_signal(self, *_args):
        self._shutdown()
        return False

    def _start_fuzzel(self):
        self._stop_fuzzel()

        if FUZZEL_SIDE_BY_SIDE:
            cmd = [
                "fuzzel",
                "--keyboard-focus=on-demand",
                "--anchor=top-left",
                f"--x-margin={FUZZEL_X}",
                f"--y-margin={FUZZEL_Y}",
            ]
        else:
            cmd = [
                "fuzzel",
                "--keyboard-focus=on-demand",
                "--anchor=center",
            ]

        self.fuzzel = subprocess.Popen(cmd)
        GLib.child_watch_add(self.fuzzel.pid, self._on_fuzzel_exit)

    def _on_fuzzel_exit(self, _pid, _status):
        # fuzzel 退出：通常应该关电源窗口
        self.fuzzel = None

        now = GLib.get_monotonic_time()
        just_entered = self._hover and (now - self._last_enter_us) <= FUZZEL_EXIT_ENTER_GRACE_US

        # ✅ 如果是“刚点回电源窗口导致 fuzzel 失焦退出”，就保留电源窗口
        # 否则（比如 fuzzel 选中应用后自动退出，或点到别处），关电源窗口
        if not just_entered:
            self._shutdown()

        return False

    def _stop_fuzzel(self):
        # 取消之前的强杀定时器，避免误杀新进程
        if self._kill_timer is not None:
            try:
                GLib.source_remove(self._kill_timer)
            except Exception:
                pass
            self._kill_timer = None

        p = self.fuzzel
        if not p:
            return

        if p.poll() is not None:
            self.fuzzel = None
            return

        try:
            p.terminate()
        except Exception:
            pass

        def _force_kill():
            if self.fuzzel and self.fuzzel.poll() is None:
                try:
                    self.fuzzel.kill()
                except Exception:
                    pass
            self._kill_timer = None
            return False

        self._kill_timer = GLib.timeout_add(250, _force_kill)

    def _shutdown(self):
        if self._closing:
            return
        self._closing = True

        self._stop_fuzzel()

        if self.win is not None:
            try:
                self.win.close()
            except Exception:
                pass
            self.win = None

    def do_shutdown(self):
        self._shutdown()
        Gtk.Application.do_shutdown(self)

if __name__ == "__main__":
    App().run(None)