#!/usr/bin/env python3
"""앱의 창 하나를 뒤 화면 없이 찍는다. 창에 떠 있는 시트도 함께 담긴다.

사용: mac_window_shot.py <pid> <out.png>
`screencapture -l` 은 그 창(과 붙은 시트)만 그림자 없이 찍어, 뒤에 무엇이 있든 담기지 않는다.
"""
import subprocess, sys
import Quartz
from PIL import Image

pid, out = int(sys.argv[1]), sys.argv[2]
info = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID)
wins = [w for w in info if w["kCGWindowOwnerPID"] == pid and w["kCGWindowLayer"] == 0]
if not wins:
    sys.exit("창을 못 찾음")
main = max(wins, key=lambda w: w["kCGWindowBounds"]["Width"] * w["kCGWindowBounds"]["Height"])
subprocess.run(["screencapture", "-x", "-o", f"-l{main['kCGWindowNumber']}", out], check=True)
# 둥근 모서리 바깥은 흰 바탕으로 채운다 — 스토어 그림은 투명을 받지 않는다.
im = Image.open(out).convert("RGBA")
bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
bg.alpha_composite(im)
bg.convert("RGB").save(out)
print(out.rsplit("/", 1)[-1], bg.size)
