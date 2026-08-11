#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "Pillow==11.3.0",
# ]
# ///
"""Generate the flattened AgX default-contrast LUT used by Wisdom Shaders.

The LUT input is normalized AgX log RGB after conversion from linear sRGB to
linear Rec. 2020 and application of the AgX inset matrix. Its output is encoded
sRGB. Slices are laid out horizontally as x = blue * size + red, y = green.

The transform follows Godot's MIT-licensed AgX implementation merged in
https://github.com/godotengine/godot/pull/87260 and the BT.2020 workflow in
https://github.com/MrLixm/AgXc/tree/main/luts.

Run from anywhere with:
    uv run tools/generate_agx_lut.py
    uv run tools/generate_agx_lut.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import io
from pathlib import Path
from typing import Iterable

from PIL import Image, PngImagePlugin

LUT_SIZE = 33
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "shaders"
    / "textures"
    / "agx-default-contrast-bt2020-srgb.png"
)

# Combined inverse AgX outset and linear Rec. 2020 -> linear sRGB transform.
# Stored row-major here; Godot's GLSL source lists mat3 values column-major.
AGX_OUTSET_REC2020_TO_SRGB = (
    (1.9648846919172410, -0.8559473746667583, -0.10883731725048387),
    (-0.29937618452442254, 1.3263980951083531, -0.027021910583931123),
    (-0.1644010628067830, -0.23819967517076845, 1.4025007379775505),
)


def default_contrast(x: float) -> float:
    """Godot's sixth-order approximation of the AgX default contrast curve."""
    x2 = x * x
    x4 = x2 * x2
    return (
        -0.20687445 * x
        + 6.80888933 * x2
        - 37.60519607 * x2 * x
        + 93.32681938 * x4
        - 95.2780858 * x4 * x
        + 33.96372259 * x4 * x2
    )


def multiply_matrix(vector: tuple[float, float, float]) -> tuple[float, float, float]:
    return (
        sum(
            AGX_OUTSET_REC2020_TO_SRGB[0][column] * vector[column]
            for column in range(3)
        ),
        sum(
            AGX_OUTSET_REC2020_TO_SRGB[1][column] * vector[column]
            for column in range(3)
        ),
        sum(
            AGX_OUTSET_REC2020_TO_SRGB[2][column] * vector[column]
            for column in range(3)
        ),
    )


def encode_srgb(value: float) -> float:
    value = max(value, 0.0)
    if value <= 0.0031308:
        return 12.92 * value
    return 1.055 * value ** (1.0 / 2.4) - 0.055


def quantize(value: float) -> int:
    return min(255, max(0, int(min(1.0, max(0.0, value)) * 255.0 + 0.5)))


def generate_pixels() -> Iterable[tuple[int, int, int, int]]:
    denominator = float(LUT_SIZE - 1)
    for green in range(LUT_SIZE):
        for blue in range(LUT_SIZE):
            for red in range(LUT_SIZE):
                log_rgb = (red / denominator, green / denominator, blue / denominator)
                display_rec2020 = tuple(
                    max(default_contrast(channel), 0.0) ** 2.4 for channel in log_rgb
                )
                linear_srgb = multiply_matrix(display_rec2020)
                encoded_srgb = tuple(encode_srgb(channel) for channel in linear_srgb)
                red8, green8, blue8 = (quantize(channel) for channel in encoded_srgb)
                yield (red8, green8, blue8, 255)


def render_png() -> bytes:
    image = Image.new("RGBA", (LUT_SIZE * LUT_SIZE, LUT_SIZE))
    image.putdata(list(generate_pixels()))

    metadata = PngImagePlugin.PngInfo()
    metadata.add_text("Title", "AgX Default Contrast, BT.2020 workspace to sRGB")
    metadata.add_text("LUTSize", str(LUT_SIZE))
    metadata.add_text("Input", "Normalized AgX log RGB in the inset BT.2020 workspace")
    metadata.add_text("Output", "Encoded sRGB")
    metadata.add_text("Source", "https://github.com/godotengine/godot/pull/87260")

    output = io.BytesIO()
    image.save(output, format="PNG", pnginfo=metadata, optimize=False, compress_level=9)
    return output.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the committed LUT differs from freshly generated output",
    )
    args = parser.parse_args()

    generated = render_png()
    digest = hashlib.sha256(generated).hexdigest()

    if args.check:
        if not args.output.is_file():
            parser.error(f"LUT does not exist: {args.output}")
        if args.output.read_bytes() != generated:
            parser.error(f"LUT is stale: {args.output}")
        print(f"LUT is current: {args.output} (sha256 {digest})")
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(generated)
    print(f"Wrote {args.output} (sha256 {digest})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
