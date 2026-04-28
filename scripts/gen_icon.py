#!/usr/bin/env python3
"""生成 CCSwitch 应用图标，输出到 CCSwitch/Assets.xcassets/AppIcon.appiconset/ 和 icon.png"""
import math
import os
import struct
import zlib
from pathlib import Path

# ─── 纯 Python PNG 写入（不依赖 PIL 的保存路径，直接控制像素） ────────────────
def write_png(path: str, pixels: list[list[tuple[int,int,int,int]]], size: int):
    """将 RGBA 像素矩阵写入 PNG 文件"""
    def png_chunk(tag: bytes, data: bytes) -> bytes:
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b''
    for row in pixels:
        raw += b'\x00'  # filter type none
        for r, g, b, a in row:
            raw += bytes([r, g, b, a])

    ihdr = struct.pack('>IIBBBBB', size, size, 8, 2 | 4, 0, 0, 0)  # RGBA
    # Recalc: bit depth=8, colortype=6 (RGBA)
    ihdr = struct.pack('>II', size, size) + bytes([8, 6, 0, 0, 0])

    sig = b'\x89PNG\r\n\x1a\n'
    body = (
        sig
        + png_chunk(b'IHDR', ihdr)
        + png_chunk(b'IDAT', zlib.compress(raw, 9))
        + png_chunk(b'IEND', b'')
    )
    with open(path, 'wb') as f:
        f.write(body)


# ─── 使用 PIL 绘制图标 ────────────────────────────────────────────────────────
from PIL import Image, ImageDraw, ImageFont
import math

def make_icon(size: int) -> Image.Image:
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size

    # ── 背景：深色圆角方形 ──
    radius = int(s * 0.22)
    bg_color = (28, 28, 35, 255)        # 近黑深蓝
    accent   = (99, 179, 237, 255)      # 浅蓝高亮
    accent2  = (154, 230, 180, 255)     # 浅绿高亮

    # 圆角矩形背景
    draw.rounded_rectangle([0, 0, s-1, s-1], radius=radius, fill=bg_color)

    # ── 渐变光晕（叠加半透明圆，模拟顶部光泽） ──
    glow = Image.new('RGBA', (s, s), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    for i in range(12):
        alpha = int(30 * (1 - i/12))
        gd.ellipse([s*0.1 - i*2, s*0.05 - i*2, s*0.9 + i*2, s*0.55 + i*2],
                   fill=(255, 255, 255, alpha))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # ── 两个弧形箭头（切换图标） ──
    cx, cy = s * 0.5, s * 0.5
    r = s * 0.285
    stroke = max(2, int(s * 0.072))
    arrow_head = max(3, int(s * 0.10))

    def draw_arc_arrow(start_deg, end_deg, color, flip_head=False):
        # 画弧线（用短线段近似）
        segs = 40
        pts = []
        for i in range(segs + 1):
            t = start_deg + (end_deg - start_deg) * i / segs
            rad = math.radians(t)
            x = cx + r * math.cos(rad)
            y = cy + r * math.sin(rad)
            pts.append((x, y))
        for i in range(len(pts) - 1):
            draw.line([pts[i], pts[i+1]], fill=color, width=stroke)

        # 箭头头部
        tip_idx = 0 if flip_head else -1
        prev_idx = 1 if flip_head else -2
        tip = pts[tip_idx]
        prev = pts[prev_idx]
        dx = tip[0] - prev[0]
        dy = tip[1] - prev[1]
        length = math.sqrt(dx*dx + dy*dy) or 1
        dx, dy = dx/length, dy/length
        # 垂直方向
        px, py = -dy, dx
        ah = arrow_head
        p1 = (tip[0] - dx*ah + px*ah*0.5, tip[1] - dy*ah + py*ah*0.5)
        p2 = (tip[0] - dx*ah - px*ah*0.5, tip[1] - dy*ah - py*ah*0.5)
        draw.polygon([tip, p1, p2], fill=color)

    # 上方弧（蓝色，从左到右 210° → 330°）
    draw_arc_arrow(210, 330, accent, flip_head=False)
    # 下方弧（绿色，从右到左 30° → 150°）
    draw_arc_arrow(30, 150, accent2, flip_head=False)

    # ── 中心字母 "CC" ──
    font_size = max(8, int(s * 0.24))
    try:
        # 尝试加载系统等宽字体
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", font_size)
    except Exception:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Monaco.dfont", font_size)
        except Exception:
            font = ImageFont.load_default()

    text = "CC"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = cx - tw / 2 - bbox[0]
    ty = cy - th / 2 - bbox[1]

    # 文字阴影
    draw.text((tx+max(1,s//64), ty+max(1,s//64)), text, font=font, fill=(0,0,0,120))
    # 文字本体（白色）
    draw.text((tx, ty), text, font=font, fill=(255, 255, 255, 230))

    return img


def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent

    # 输出目录
    iconset_dir = project_dir / "CCSwitch" / "Assets.xcassets" / "AppIcon.appiconset"
    iconset_dir.mkdir(parents=True, exist_ok=True)

    icon_src_dir = project_dir / "CCSwitch" / "Assets.xcassets" / "AppIcon.appiconset"

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    print("Generating icon sizes:", sizes)
    for sz in sizes:
        img = make_icon(sz)
        out = iconset_dir / f"icon_{sz}x{sz}.png"
        img.save(str(out), 'PNG')
        print(f"  ✔ {out.name}")
        # @2x variants (half size label)
        if sz <= 512:
            out2x = iconset_dir / f"icon_{sz//2}x{sz//2}@2x.png"
            img.save(str(out2x), 'PNG')

    # 1024 用作原始图标预览
    preview = project_dir / "CCSwitch" / "Assets.xcassets" / "AppIcon.appiconset" / "icon_1024x1024.png"
    print(f"\n✔ Preview icon: {preview}")

    # Contents.json for Xcode
    contents = '''{
  "images" : [
    { "idiom": "mac", "scale": "1x", "size": "16x16",   "filename": "icon_16x16.png" },
    { "idiom": "mac", "scale": "2x", "size": "16x16",   "filename": "icon_16x16@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "32x32",   "filename": "icon_32x32.png" },
    { "idiom": "mac", "scale": "2x", "size": "32x32",   "filename": "icon_32x32@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128x128.png" },
    { "idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128x128@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256x256.png" },
    { "idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256x256@2x.png" },
    { "idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512x512.png" },
    { "idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512x512@2x.png" }
  ],
  "info" : { "author": "xcode", "version": 1 }
}
'''
    (iconset_dir / "Contents.json").write_text(contents)
    print("✔ Contents.json written")

    # 用 iconutil 生成 .icns（需要先建 .iconset 目录）
    iconset_tmp = project_dir / "dist" / "AppIcon.iconset"
    iconset_tmp.mkdir(parents=True, exist_ok=True)

    # iconutil 需要特定命名规范
    iconutil_map = {
        "icon_16x16.png":    "icon_16x16.png",
        "icon_16x16@2x.png": "icon_16x16@2x.png",
        "icon_32x32.png":    "icon_32x32.png",
        "icon_32x32@2x.png": "icon_32x32@2x.png",
        "icon_128x128.png":  "icon_128x128.png",
        "icon_128x128@2x.png": "icon_128x128@2x.png",
        "icon_256x256.png":  "icon_256x256.png",
        "icon_256x256@2x.png": "icon_256x256@2x.png",
        "icon_512x512.png":  "icon_512x512.png",
        "icon_512x512@2x.png": "icon_512x512@2x.png",
    }
    import shutil
    for src_name, dst_name in iconutil_map.items():
        src = iconset_dir / src_name
        if src.exists():
            shutil.copy2(src, iconset_tmp / dst_name)

    icns_path = project_dir / "CCSwitch" / "AppIcon.icns"
    import subprocess
    result = subprocess.run(
        ["iconutil", "-c", "icns", str(iconset_tmp), "-o", str(icns_path)],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"✔ .icns generated: {icns_path}")
    else:
        print(f"✘ iconutil failed: {result.stderr}")

    print("\nDone!")


if __name__ == "__main__":
    main()
