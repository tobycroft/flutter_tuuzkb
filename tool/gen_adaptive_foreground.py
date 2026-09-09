#!/usr/bin/env python3
"""把黑底版前景图抠成透明背景，供 Android 自适应图标使用。

背景：自适应图标由 background + foreground 合成。如果 foreground 是
「自带黑底的不透明方图」，它会把 background 完全盖住，导致
pubspec.yaml 里配置的品牌背景色根本看不见。所以必须先抠掉黑底。

做法：
  1. 以亮度 max(R,G,B) 估算 alpha：
     - 亮度 <= DARK 视为纯背景，alpha = 0
     - 亮度 >= LIT  视为纯前景，alpha = 255
     - 中间线性过渡，保留抗锯齿边缘
  2. 反预乘去黑边：半透明像素是「前景色 + 黑色背景」混合的结果，
     用 color * 255 / alpha 还原成未混黑前的颜色，避免 Logo 边缘
     在新背景色上出现一圈暗边。

用法（换了 assets/icon/app_icon_foreground.png 之后需要重跑）：
    python3 tool/gen_adaptive_foreground.py
    dart run flutter_launcher_icons
    python3 tool/gen_round_launcher_icon.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SRC = PROJECT_ROOT / "assets" / "icon" / "app_icon_foreground.png"
DST = PROJECT_ROOT / "assets" / "icon" / "app_icon_foreground_transparent.png"

# alpha 羽化阈值（0-255 亮度）
DARK = 18
LIT = 56


def main() -> int:
    if not SRC.exists():
        print(f"源图不存在：{SRC}")
        return 1

    im = Image.open(SRC).convert("RGB")
    width, height = im.size

    out = []
    for r, g, b in im.getdata():
        lum = max(r, g, b)
        if lum <= DARK:
            out.append((0, 0, 0, 0))
            continue
        alpha = 255 if lum >= LIT else round((lum - DARK) / (LIT - DARK) * 255)
        if alpha <= 0:
            out.append((0, 0, 0, 0))
            continue
        k = 255 / alpha  # 反预乘：还原被黑色污染的颜色
        out.append(
            (
                min(255, round(r * k)),
                min(255, round(g * k)),
                min(255, round(b * k)),
                alpha,
            )
        )

    dst = Image.new("RGBA", (width, height))
    dst.putdata(out)
    dst.save(DST, "PNG")

    opaque = sum(1 for p in out if p[3] == 255)
    clear = sum(1 for p in out if p[3] == 0)
    total = width * height
    print(f"已生成 {DST.relative_to(PROJECT_ROOT)} ({width}x{height})")
    print(f"  完全不透明 {opaque / total * 100:.2f}% / 完全透明 {clear / total * 100:.2f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
