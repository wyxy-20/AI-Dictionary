"""生成 AI Dictionary 应用图标（代码原生绘制，无需 AI 图像工具）。

输出：
  - assets/branding/app_icon.png          （1024x1024 源图）
  - windows/runner/resources/app_icon.ico （多尺寸 ICO）
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024

COLOR_TOP = (74, 92, 255)   # #4A5CFF
COLOR_BOTTOM = (123, 97, 255)  # #7B61FF
WHITE = (255, 255, 255)
PAGE_LINE = (200, 210, 255)


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))  # type: ignore[return-value]


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def gradient_background(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    for y in range(size):
        t = y / (size - 1)
        color = lerp(COLOR_TOP, COLOR_BOTTOM, t)
        ImageDraw.Draw(img).line((0, y, size, y), fill=color)
    return img


def draw_star(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, color: tuple[int, int, int]) -> None:
    """绘制四角星（火花），带内凹角。"""
    pts = [
        (cx, cy - r),
        (cx + r * 0.28, cy - r * 0.28),
        (cx + r, cy),
        (cx + r * 0.28, cy + r * 0.28),
        (cx, cy + r),
        (cx - r * 0.28, cy + r * 0.28),
        (cx - r, cy),
        (cx - r * 0.28, cy - r * 0.28),
    ]
    draw.polygon(pts, fill=color)


def draw_book(draw: ImageDraw.ImageDraw, cx: int, cy: int, w: int, h: int) -> None:
    """绘制一本打开的白色书。"""
    half = w // 2
    top_left = (cx - half, cy - h // 2)
    top_right = (cx + half, cy - h // 2)
    bottom_left = (cx - half + 28, cy + h // 2)
    bottom_right = (cx + half - 28, cy + h // 2)
    spine_top = (cx, cy - h // 2 + 26)
    spine_bottom = (cx, cy + h // 2 + 2)

    # 左右书页
    draw.polygon(
        [top_left, spine_top, spine_bottom, bottom_left],
        fill=WHITE,
    )
    draw.polygon(
        [top_right, spine_top, spine_bottom, bottom_right],
        fill=WHITE,
    )

    # 书脊折线
    draw.line([spine_top, spine_bottom], fill=PAGE_LINE, width=6)

    # 页内文字线（左侧三行、右侧三行）
    for i, t in enumerate((0.32, 0.5, 0.68)):
        y_left = round(spine_top[1] + (spine_bottom[1] - spine_top[1]) * t)
        x_start = round(top_left[0] + (bottom_left[0] - top_left[0]) * t)
        x_spine = spine_top[0] - 12
        draw.line([(x_start + 34, y_left), (x_spine, y_left + 6)], fill=PAGE_LINE, width=14)

        y_right = y_left
        x_spine_r = spine_top[0] + 12
        x_end = round(top_right[0] + (bottom_right[0] - top_right[0]) * t)
        draw.line([(x_spine_r, y_right + 6), (x_end - 34, y_right)], fill=PAGE_LINE, width=14)


def main() -> None:
    radius = round(SIZE * 0.19)
    img = gradient_background(SIZE)

    # 顶部微弱高光
    highlight = Image.new("L", (SIZE, SIZE), 0)
    hd = ImageDraw.Draw(highlight)
    hd.ellipse((-SIZE * 0.3, -SIZE * 0.45, SIZE * 1.3, SIZE * 0.35), fill=38)
    gloss = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    img = Image.composite(gloss, img, highlight)

    draw = ImageDraw.Draw(img)

    # 书本（略偏下，为星星留出空间）
    draw_book(draw, SIZE // 2, 560, 640, 480)

    # 右上角四角星
    draw_star(draw, 720, 330, 130, WHITE)

    # 圆角裁剪
    img.putalpha(rounded_rect_mask(SIZE, radius))

    # 保存源图
    png_dir = ROOT / "assets" / "branding"
    png_dir.mkdir(parents=True, exist_ok=True)
    png_path = png_dir / "app_icon.png"
    img.save(png_path, "PNG")

    # 生成多尺寸 ICO
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    images = [img.resize(size, Image.LANCZOS) for size in ico_sizes]
    images[-1].save(
        ico_path,
        format="ICO",
        sizes=ico_sizes,
        append_images=images[:-1],
    )
    print(f"PNG: {png_path}")
    print(f"ICO: {ico_path}")


if __name__ == "__main__":
    main()
