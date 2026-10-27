#!/usr/bin/env python3
"""把 LA32 小端机器码转为仿真/片上 ROM 使用的 32 位 hex 行。"""
from pathlib import Path
import sys


if len(sys.argv) != 3:
    raise SystemExit("usage: bin2hex.py input.bin output.hex")

data = Path(sys.argv[1]).read_bytes()
if len(data) % 4:
    raise SystemExit("machine code is not word aligned")
words = (int.from_bytes(data[i : i + 4], "little") for i in range(0, len(data), 4))
Path(sys.argv[2]).write_text("".join(f"{word:08x}\n" for word in words))
