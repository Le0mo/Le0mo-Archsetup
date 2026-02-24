#!/usr/bin/env python3
import json
import os
import socket
from pathlib import Path

HOST = "127.0.0.1"
PORT = 4090

OUT_FILE = Path(os.environ["HOME"]) / ".config/waybar/scripts/island/dynamic_out.txt"
OUT_FILE.parent.mkdir(parents=True, exist_ok=True)

def write_payload(css_class: str, text: str) -> None:
    payload = {"class": css_class, "text": text}
    OUT_FILE.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")

def main():
    # 初始化一个默认内容，避免 waybar 启动时读到空文件
    write_payload("idle", "")

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((HOST, PORT))
        srv.listen(32)

        while True:
            conn, _addr = srv.accept()
            with conn:
                raw = conn.recv(4096)
                if not raw:
                    continue

                msg = raw.decode("utf-8", errors="replace")
                # 约定：class/text（只切一刀，允许 text 内有 /）
                if "/" not in msg:
                    continue
                css_class, text = msg.split("/", 1)
                css_class = css_class.strip() or "idle"
                text = text.replace("\n", " ").strip()

                write_payload(css_class, text)

if __name__ == "__main__":
    main()
