#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import time as t
import socket
import mpd

from datetime_island import now_text

HOST = "127.0.0.1"
PORT = 4090
LYRICS_DIR = os.path.join(os.environ["HOME"], ".lyrics")

client = mpd.MPDClient()
client.timeout = 10
client.idletimeout = None
client.connect("localhost", 6600)


class Time:
    def __init__(self, minute: int, second: int, millisecond: int):
        self.min = minute
        self.sec = second
        self.ms = millisecond

    def total_ms(self) -> int:
        return self.min * 60000 + self.sec * 1000 + self.ms

    def __lt__(self, b):
        return self.total_ms() < b.total_ms()


class TimeMaker:
    def from_list(self, li):
        mm, ss, frac = li[0], li[1], li[2]
        frac = (str(frac) + "000")[:3]
        return Time(int(mm), int(ss), int(frac))


class Lyrics:
    def __init__(self, lyrics_text: str):
        maker = TimeMaker()
        self.data = []

        for tag, text in re.findall(r"(\[\d{2}:\d{2}\.\d{1,3}\])\s*(.*)", lyrics_text):
            m = re.findall(r"\[(\d{2}):(\d{2})\.(\d{1,3})\]", tag)
            if not m:
                continue
            mm, ss, frac = m[0]
            self.data.append({"time": maker.from_list([mm, ss, frac]), "text": text.strip()})

        self.data.sort(key=lambda x: x["time"].total_ms())

    def get_lyrics(self, time_obj: Time):
        if not self.data:
            return None

        if time_obj < self.data[0]["time"]:
            return self.data[0]["text"]

        for i in range(len(self.data) - 1):
            cur = self.data[i]["time"]
            nxt = self.data[i + 1]["time"]
            if cur < time_obj and time_obj.total_ms() <= nxt.total_ms():
                return self.data[i]["text"]

        return self.data[-1]["text"]


def mpd_time_obj() -> Time:
    st = client.status()
    cur_sec = int(st.get("time", "0:0").split(":")[0])
    return Time(cur_sec // 60, cur_sec % 60, 0)


def send_to_island(css_class: str, text: str):
    msg = f"{css_class}/{text}".encode("utf-8", errors="replace")
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((HOST, PORT))
        s.send(msg)


def find_lyrics_file(artist: str, title: str) -> str | None:
    candidates = [
        f"{artist} - {title}.txt",
        f"{artist}-{title}.txt",
        f"{artist} - {title}.lrc",
        f"{artist}-{title}.lrc",
        f"{title} - {artist}.txt",
        f"{title}-{artist}.txt",
        f"{title} - {artist}.lrc",
        f"{title}-{artist}.lrc",
    ]
    for name in candidates:
        path = os.path.join(LYRICS_DIR, name)
        if os.path.exists(path):
            return path
    return None


last_song_key = ""
ly = None

idle_since = None   # 进入非 play 的时间点（monotonic 秒）
last_out = ""       # 上次真正发送出去的整段文本
last_cls = ""       # 上次发送的 class（play/idle）

while True:
    try:
        song = client.currentsong()
        st = client.status()
        state = st.get("state", "stop")

        artist = song.get("artist", "")
        title = song.get("title", "")
        song_key = f"{artist}::{title}"

        message = ""

        # 切歌：加载歌词 & 重置 3s 计时
        if song_key != last_song_key:
            last_song_key = song_key
            ly = None
            idle_since = None

            if artist and title:
                path = find_lyrics_file(artist, title)
                if path:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        ly = Lyrics(f.read())

        # 播放中：优先显示歌词
        if state == "play" and ly is not None:
            line = ly.get_lyrics(mpd_time_obj())
            if line:
                message = line

        # 没歌词/暂停/停止：显示歌名
        if not message:
            if title or artist:
                message = f"{title} - {artist}".strip(" -")
            else:
                message = ""

        clean = message.replace("&", "と").strip()
        has_track = bool(title or artist)

        # ===== 你的显示逻辑 =====
        if state == "play":
            idle_since = None
            out = clean
            cls = "play"
        else:
            cls = "idle"

            # 没歌：直接显示时间
            if not has_track:
                out = now_text()
            else:
                # 有歌：先显示歌名 3 秒，再显示时间
                if idle_since is None:
                    idle_since = t.monotonic()

                if t.monotonic() - idle_since < 3.0:
                    out = "    " + clean
                else:
                    out = now_text()

        # 只要最终输出变了才推送
        if out != last_out or cls != last_cls:
            send_to_island(cls, out)
            last_out = out
            last_cls = cls

    except Exception:
        pass

    t.sleep(0.2)