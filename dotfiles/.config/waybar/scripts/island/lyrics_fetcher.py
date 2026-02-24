#!/usr/bin/env python3
# /home/le0mo/.config/waybar/scripts/island/lyrics_fetcher.py

import os
import re
import json
import base64
import hashlib
import urllib.request
import urllib.parse

# ======= 你可能需要改的配置 =======
# ncmpcpp 常用的歌词目录（如果你自己在 ncmpcpp 配了 lyrics_directory，改成你那个）
LYRICS_DIRS = [
    os.path.expanduser("~/.lyrics"),
    os.path.expanduser("~/.ncmpcpp/lyrics"),
]

CACHE_DIR = "/tmp/qs_lyrics_cache"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
}
# =================================


def ensure_dirs():
    os.makedirs(CACHE_DIR, exist_ok=True)
    for d in LYRICS_DIRS:
        os.makedirs(d, exist_ok=True)


def fs_safe(s: str) -> str:
    """文件名安全化（保留中文，但去掉会炸路径的字符）"""
    if s is None:
        return ""
    s = s.strip()
    # 替换 Linux 路径危险字符
    s = re.sub(r"[\/\0]", "_", s)
    s = re.sub(r"[\n\r\t]", " ", s)
    return s


def get_cache_path(title, artist):
    safe_name = f"{title}-{artist}".encode("utf-8", errors="ignore")
    h = hashlib.md5(safe_name).hexdigest()
    return os.path.join(CACHE_DIR, f"{h}.json")


def build_lrc_paths(title, artist):
    """返回可能的歌词文件路径列表（多个目录都看一眼）"""
    t = fs_safe(title)
    a = fs_safe(artist)
    # 你之前遇到过“司南-冬眠.txt”这种命名，这里统一用 "歌手 - 歌名.lrc"
    filename = f"{a} - {t}.txt" if a else f"{t}.lrc"
    return [os.path.join(d, filename) for d in LYRICS_DIRS]


def lrc_exists_anywhere(title, artist) -> bool:
    for p in build_lrc_paths(title, artist):
        if os.path.exists(p) and os.path.getsize(p) > 0:
            return True
    return False


def request_url(url, data=None, headers=None):
    if headers is None:
        headers = HEADERS
    try:
        req = urllib.request.Request(url, data=data, headers=headers)
        with urllib.request.urlopen(req, timeout=4) as r:
            return json.loads(r.read().decode("utf-8", errors="ignore"))
    except Exception:
        return None


def parse_lrc(lrc_text):
    """解析 LRC 文本为 [{time:秒, text:词}, ...]"""
    if not lrc_text:
        return []

    pattern = re.compile(r"\[(\d{2}):(\d{2})[\.:](\d{2,3})\](.*)")
    lrc_text = (
        lrc_text.replace("&apos;", "'")
        .replace("&quot;", '"')
        .replace("&amp;", "&")
    )

    out = []
    for line in lrc_text.split("\n"):
        line = line.strip()
        if not line:
            continue
        m = pattern.match(line)
        if not m:
            continue

        minutes = int(m.group(1))
        seconds = int(m.group(2))
        ms_str = m.group(3)
        ms = int(ms_str) * 10 if len(ms_str) == 2 else int(ms_str)

        total_seconds = minutes * 60 + seconds + ms / 1000.0
        text = m.group(4).strip()

        # 过滤元数据
        if text and not text.lower().startswith(("offset:", "by:", "al:", "ti:", "ar:")):
            out.append({"time": total_seconds, "text": text})

    out.sort(key=lambda x: x["time"])
    return out


def lines_to_lrc(lines):
    """把 [{time,text}] 转成标准 LRC"""
    def fmt(ts: float) -> str:
        if ts < 0:
            ts = 0
        m = int(ts // 60)
        s = int(ts % 60)
        cs = int(round((ts - int(ts)) * 100))  # centiseconds
        if cs >= 100:
            cs = 99
        return f"{m:02d}:{s:02d}.{cs:02d}"

    buf = []
    for it in lines:
        t = it.get("time", 0)
        text = it.get("text", "").strip()
        if text:
            buf.append(f"[{fmt(float(t))}]{text}")
    return "\n".join(buf).strip() + "\n" if buf else ""


# --- 1) QQ 音乐 ---
def fetch_qq(track, artist):
    qq_headers = {
        "User-Agent": HEADERS["User-Agent"],
        "Referer": "https://y.qq.com/",
    }
    try:
        keyword = f"{track} {artist}".strip()
        search_url = (
            "https://c.y.qq.com/soso/fcgi-bin/client_search_cp"
            f"?w={urllib.parse.quote(keyword)}&format=json"
        )
        search_data = request_url(search_url, headers=qq_headers)
        songmid = ""
        if (
            search_data
            and "data" in search_data
            and "song" in search_data["data"]
            and "list" in search_data["data"]["song"]
            and search_data["data"]["song"]["list"]
        ):
            songmid = search_data["data"]["song"]["list"][0].get("songmid", "")

        if not songmid:
            return []

        lyric_url = (
            "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"
            f"?songmid={songmid}&format=json&nobase64=1"
        )
        lyric_data = request_url(lyric_url, headers=qq_headers)
        if lyric_data and "lyric" in lyric_data:
            raw = lyric_data["lyric"]
            try:
                decoded = base64.b64decode(raw).decode("utf-8", errors="ignore")
            except Exception:
                decoded = raw
            return parse_lrc(decoded)
    except Exception:
        pass
    return []


# --- 2) 网易云 ---
def fetch_netease(track, artist):
    search_url = "http://music.163.com/api/search/get/"
    ne_headers = dict(HEADERS)
    ne_headers["Referer"] = "http://music.163.com/"

    post_data = urllib.parse.urlencode(
        {"s": f"{track} {artist}", "type": 1, "offset": 0, "total": "true", "limit": 1}
    ).encode("utf-8")

    try:
        res = request_url(search_url, data=post_data, headers=ne_headers)
        if res and "result" in res and res["result"].get("songs"):
            song_id = res["result"]["songs"][0]["id"]
            lyric_url = (
                "http://music.163.com/api/song/lyric"
                f"?os=pc&id={song_id}&lv=-1&kv=-1&tv=-1"
            )
            lrc_data = request_url(lyric_url, headers=ne_headers)
            if lrc_data and "lrc" in lrc_data and "lyric" in lrc_data["lrc"]:
                return parse_lrc(lrc_data["lrc"]["lyric"])
    except Exception:
        pass
    return []


def mpd_current_song():
    """
    通过 MPD UNIX socket 或 TCP 读取当前歌曲信息。
    这里不引入 python-mpd2 依赖，用最朴素的 MPD 协议走 TCP：127.0.0.1:6600
    """
    import socket

    host = "127.0.0.1"
    port = 6600

    def recv_until(sock, end=b"\n"):
        data = b""
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            data += chunk
            if end in data:
                break
        return data

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(2)
    s.connect((host, port))

    # 读 banner
    banner = recv_until(s)
    if not banner.startswith(b"OK MPD"):
        s.close()
        return ("", "")

    # 发 currentsong
    s.sendall(b"currentsong\n")
    out = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        out += chunk
        if b"\nOK\n" in out or b"\nACK" in out:
            break
    s.close()

    title = ""
    artist = ""
    for line in out.decode("utf-8", errors="ignore").splitlines():
        if line.startswith("Title: "):
            title = line[len("Title: "):].strip()
        elif line.startswith("Artist: "):
            artist = line[len("Artist: "):].strip()

    return (title, artist)


def main():
    ensure_dirs()

    title, artist = mpd_current_song()
    title = title.strip()
    artist = artist.strip()

    # MPD 没歌
    if not title:
        # 你要是给 waybar 用，可以输出空 JSON
        print(json.dumps([{"time": 0, "text": "等待播放..."}], ensure_ascii=False))
        return

    # 1) 如果本地已经有歌词：直接退出（不生成不联网）
    if lrc_exists_anywhere(title, artist):
        # 这里你想要“完全静默”也行：直接 return 不输出
        # 为了方便调试/waybar 展示，我输出一行提示
        print(json.dumps([{"time": 0, "text": "✅ 已有本地歌词，跳过抓取"}], ensure_ascii=False))
        return

    # 2) 先看缓存 JSON（只是为了少联网；但你说“有歌词就不生成”，缓存不算歌词文件）
    cache_file = get_cache_path(title, artist)
    if os.path.exists(cache_file):
        try:
            cached = json.load(open(cache_file, "r", encoding="utf-8"))
            if cached:
                # 如果你希望“缓存命中也要写成 .lrc 文件”，可以在这里写
                lrc_text = lines_to_lrc([x for x in cached if x.get("text") and "来源" not in x["text"]])
                if lrc_text:
                    for p in build_lrc_paths(title, artist):
                        try:
                            with open(p, "w", encoding="utf-8") as f:
                                f.write(lrc_text)
                            break
                        except Exception:
                            continue
                print(json.dumps(cached, ensure_ascii=False))
                return
        except Exception:
            pass

    # 3) 按优先级抓取
    lyrics = fetch_qq(title, artist)
    source = "QQ音乐" if lyrics else ""

    if not lyrics:
        lyrics = fetch_netease(title, artist)
        source = "网易云音乐" if lyrics else ""

    # 4) 处理结果
    if not lyrics:
        print(json.dumps([{"time": 0, "text": "❌ 未找到歌词"}], ensure_ascii=False))
        return

    # 写 .lrc 给 ncmpcpp
    lrc_text = lines_to_lrc(lyrics)
    wrote = False
    for p in build_lrc_paths(title, artist):
        try:
            with open(p, "w", encoding="utf-8") as f:
                f.write(lrc_text)
            wrote = True
            break
        except Exception:
            continue

    # 写缓存 JSON（给你 waybar/脚本用）
    out = [{"time": 0, "text": f"🔍 [来源: {source}]"}] + lyrics
    try:
        with open(cache_file, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False)
    except Exception:
        pass

    # 输出给 waybar 调试
    if wrote:
        print(json.dumps(out, ensure_ascii=False))
    else:
        print(json.dumps([{"time": 0, "text": "❌ 歌词抓到了，但写文件失败（权限/路径）"}], ensure_ascii=False))


if __name__ == "__main__":
    main()