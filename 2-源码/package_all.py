#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打包 K103 猫猫字体管理完整分发包 zip（正斜杠条目名，UTF-8 flag）。"""
import os, zipfile

ROOT = r"E:\telework\k103字体模块"
TOP = os.path.join(ROOT, ".temp_pkg", "K103_FontManager_完整包_v1.0")
OUT = os.path.join(ROOT, "K103_FontManager_完整包_v1.0.zip")
PREFIX = "K103_FontManager_完整包_v1.0"

def main():
    if os.path.exists(OUT):
        os.remove(OUT)
    n = 0
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, dirs, files in os.walk(ROOT):
            # 跳过临时打包目录
            if ".temp_pkg" in dirpath:
                continue
            rel = os.path.relpath(dirpath, ROOT).replace("\\", "/")
            for fn in files:
                if fn == "K103_FontManager_完整包_v1.0.zip":
                    continue
                full = os.path.join(dirpath, fn)
                arc = (PREFIX + "/" + rel + "/" + fn) if rel != "." else (PREFIX + "/" + fn)
                z.write(full, arc)
                n += 1
    print("entries:", n)
    print("size  :", os.path.getsize(OUT), "bytes")
    with zipfile.ZipFile(OUT) as z:
        for i in z.namelist():
            print("  ", i)

if __name__ == "__main__":
    main()
