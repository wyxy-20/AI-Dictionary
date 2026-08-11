"""Regenerate the app icon ICO files from the master PNG.

The master icon asset is assets/branding/app_icon.png (1024x1024, generated
from an AI design with the watermark removed). This helper re-derives the
multi-size ICO files used by the Windows exe and the system tray:

  - assets/branding/app_icon.ico           (tray icon)
  - windows/runner/resources/app_icon.ico  (exe icon)

Usage:
    python tool/generate_icon.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PNG_PATH = ROOT / "assets" / "branding" / "app_icon.png"
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def make_size(img: Image.Image, size: int) -> Image.Image:
    """Downscale with LANCZOS and sharpen the small sizes for crispness."""
    im = img.resize((size, size), Image.LANCZOS)
    if size <= 48:
        im = im.filter(ImageFilter.UnsharpMask(radius=1.0, percent=140, threshold=2))
    elif size <= 96:
        im = im.filter(ImageFilter.UnsharpMask(radius=1.0, percent=90, threshold=2))
    return im


def main() -> None:
    if not PNG_PATH.exists():
        raise SystemExit(f"master PNG not found: {PNG_PATH}")
    img = Image.open(PNG_PATH).convert("RGBA")
    images = [make_size(img, size) for (size, _) in ICO_SIZES]

    ico_paths = [
        ROOT / "assets" / "branding" / "app_icon.ico",
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
    ]
    for ico_path in ico_paths:
        ico_path.parent.mkdir(parents=True, exist_ok=True)
        images[-1].save(
            ico_path,
            format="ICO",
            sizes=ICO_SIZES,
            append_images=images[:-1],
        )
        print(f"ICO: {ico_path}")


if __name__ == "__main__":
    main()
