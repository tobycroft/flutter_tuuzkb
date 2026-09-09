#!/usr/bin/env python3
"""合成「品牌色底 + tuuz logo」的方形图标，用作 flutter_launcher_icons 的 image_path。

为什么需要它：flutter_launcher_icons 只会按原样缩放 image_path，不会给普通
方形图标自动铺背景色。而系统安装器、设置-应用信息里显示的就是这张方形图；
如果它还是黑底，就会出现「桌面是品牌绿底、安装预览是黑底」两个样子。

做法：
  1. 背景色从 pubspec.yaml 的 adaptive_icon_background 读取（单一数据源，
     保证方形图底色与桌面自适应图标底色永远一致）
  2. 把透明前景（tool/gen_adaptive_foreground.py 的产物）等比放大，使 Logo
     宽度占整图 LOGO_RATIO，居中贴到背景上
  3. LOGO_RATIO 取桌面可见区中 Logo 的占比：前景铺满 108dp、可见区 72dp，
     Logo 占前景 51.5% → 51.5% / (72/108) = 77%，这样安装预览与桌面大小一致

用法（换了 app_icon_foreground.png 或改了背景色后按顺序跑）：
    python3 tool/gen_adaptive_foreground.py
    python3 tool/gen_square_icon_with_bg.py
    flutter pub run flutter_launcher_icons
    python3 tool/gen_round_launcher_icon.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image, ImageChops

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = PROJECT_ROOT / "pubspec.yaml"
SRC_FOREGROUND = PROJECT_ROOT / "assets" / "icon" / "app_icon_foreground_transparent.png"
DST = PROJECT_ROOT / "assets" / "icon" / "icon_brand_bg.png"

# Logo 宽度占整图的比例，与桌面自适应图标可见区中的占比保持一致
LOGO_RATIO = 0.77


def read_background_color() -> tuple[int, int, int]:
    """从 pubspec.yaml 读取 adaptive_icon_background（#RRGGBB 或颜色资源名）。"""
    text = PUBSPEC.read_text(encoding="utf-8")
    match = re.search(r"adaptive_icon_background:\s*\"?(#[0-9A-Fa-f]{6})\"?", text)
    if not match:
        print("pubspec.yaml 中未找到 adaptive_icon_background 颜色值")
        sys.exit(1)
    hex_color = match.group(1)
    return (
        int(hex_color[1:3], 16),
        int(hex_color[3:5], 16),
        int(hex_color[5:7], 16),
    )


def main() -> int:
    if not SRC_FOREGROUND.exists():
        print(f"透明前景不存在，请先运行 tool/gen_adaptive_foreground.py：{SRC_FOREGROUND}")
        return 1

    bg = read_background_color()
    foreground = Image.open(SRC_FOREGROUND).convert("RGBA")
    size = foreground.width

    # Logo 实际包围盒（alpha > 0 的区域）
    bbox = foreground.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not bbox:
        print("前景图全透明，无法合成")
        return 1
    logo_width = bbox[2] - bbox[0]

    scale = (size * LOGO_RATIO) / logo_width
    scaled = foreground.resize((round(size * scale), round(size * scale)), Image.LANCZOS)
    offset = ((size - scaled.width) // 2, (size - scaled.height) // 2)

    canvas = Image.new("RGBA", (size, size), bg + (255,))
    canvas.paste(scaled, offset, scaled)
    canvas.save(DST, "PNG")

    print(f"已生成 {DST.relative_to(PROJECT_ROOT)} ({size}x{size})")
    print(f"  背景色 rgb{bg}  缩放 {scale:.3f}x")

    # 校验：合成图是不透明的，只能按「与背景色不同的像素」计算 Logo 占比
    diff = ImageChops.difference(canvas.convert("RGB"), Image.new("RGB", canvas.size, bg))
    mask = diff.convert("L").point(lambda v: 255 if v > 8 else 0)
    new_bbox = mask.getbbox()
    if new_bbox:
        print(f"  Logo 占宽 {(new_bbox[2] - new_bbox[0]) / size * 100:.1f}%（目标 {LOGO_RATIO * 100:.0f}%）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
