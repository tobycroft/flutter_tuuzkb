#!/usr/bin/env python3
"""生成 Android 圆形版桌面图标 ic_launcher_round.png。

背景：Android 8.0+ 的桌面 Launcher 会优先使用自适应图标
(mipmap-anydpi-v26/ic_launcher.xml)。但对于只请求圆形图标、或者不支持
自适应图标的 Launcher，系统会回退到 android:roundIcon / mipmap-*/ic_launcher.png。
如果没有提供圆形版，Launcher 会自行把方形图再裁一次，导致桌面图标
和安装时看到的图标不一致（被放大、被裁边）。

本脚本只负责「补一张圆形版」：
  - 源图 mipmap-*/ic_launcher.png 保持不变（即安装时看到的那张图）
  - 生成的 mipmap-*/ic_launcher_round.png 内容与源图一致，仅做圆形遮罩，
    圆外区域透明，边缘使用 4 倍超采样保证平滑

用法（修改了 assets/icon 并重新生成方形图标后，需要再跑一次本脚本）：
    dart run flutter_launcher_icons
    python3 tool/gen_round_launcher_icon.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

PROJECT_ROOT = Path(__file__).resolve().parents[1]
RES_DIR = PROJECT_ROOT / "android" / "app" / "src" / "main" / "res"

SOURCE_NAME = "ic_launcher.png"
TARGET_NAME = "ic_launcher_round.png"
# 遮罩超采样倍数：先画大图再缩小，避免圆边锯齿
MASK_SCALE = 4


def circle_mask(size: int) -> Image.Image:
    """生成 size x size 的圆形 alpha 遮罩（圆内 255，圆外 0）。"""
    big = size * MASK_SCALE
    mask = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, big - 1, big - 1), fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def main() -> int:
    sources = sorted(RES_DIR.glob(f"mipmap-*/{SOURCE_NAME}"))
    if not sources:
        print(f"未找到任何 mipmap-*/{SOURCE_NAME}，请检查路径：{RES_DIR}")
        return 1

    for source in sources:
        with Image.open(source) as img:
            icon = img.convert("RGBA")
        size = icon.width

        rounded = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        rounded.paste(icon, (0, 0), circle_mask(size))

        target = source.with_name(TARGET_NAME)
        rounded.save(target, "PNG")
        print(f"已生成 {target.relative_to(PROJECT_ROOT)} ({size}x{size})")

    print(f"完成：共 {len(sources)} 个密度的 {TARGET_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
