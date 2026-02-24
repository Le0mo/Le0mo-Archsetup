#!/usr/bin/env python3
import os
import json
import socket

HOST = "127.0.0.1"
PORT = 4090

OUT = os.path.join(os.environ["HOME"], ".config/waybar/scripts/island/dynamic_out.txt")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind((HOST, PORT))
srv.listen(20)

while True:
    cli, _ = srv.accept()
    try:
        raw = cli.recv(4096)
        if not raw:
            continue
        msg = raw.decode("utf-8", errors="replace")
        # 约定：class/text（只按第一个 / 分割）
        if "/" not in msg:
            continue
        cls, text = msg.split("/", 1)

        payload = {"class": cls.strip(), "text": text.strip()}
        with open(OUT, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
    finally:
        cli.close()
