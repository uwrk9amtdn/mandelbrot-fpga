"""Palettes for the colouring shader (PC_APP_PLAN.md, "Colouring"). Milestone 2 has escape-time
colouring only; smooth, histogram and the gradient editor come with milestone 3.

A palette is a list of control points (position in [0, 1), RGB in [0, 1]) on a cycle: the colour
after the last point blends back into the first. It is baked into a 1024-entry texture.
"""

import numpy as np

PALETTE_SIZE = 1024

PRESETS: dict[str, list[tuple[float, tuple[float, float, float]]]] = {
    "ultra": [  # the classic dark blue - white - orange cycle
        (0.0, (0.0, 0.03, 0.39)),
        (0.16, (0.13, 0.42, 0.80)),
        (0.42, (0.93, 1.0, 1.0)),
        (0.64, (1.0, 0.67, 0.0)),
        (0.86, (0.0, 0.01, 0.0)),
    ],
    "fire": [
        (0.0, (0.0, 0.0, 0.0)),
        (0.3, (0.7, 0.05, 0.0)),
        (0.6, (1.0, 0.7, 0.1)),
        (0.8, (1.0, 1.0, 0.8)),
    ],
    "ice": [
        (0.0, (0.02, 0.02, 0.1)),
        (0.4, (0.1, 0.5, 0.8)),
        (0.7, (0.8, 0.95, 1.0)),
    ],
    "grey": [
        (0.0, (0.0, 0.0, 0.0)),
        (0.5, (1.0, 1.0, 1.0)),
    ],
}


def bake(points, size: int = PALETTE_SIZE) -> np.ndarray:
    """RGB u8 of shape (size, 3), linear between the control points, wrapping around."""
    pos = np.array([pt[0] for pt in points] + [points[0][0] + 1.0])
    rgb = np.array([pt[1] for pt in points] + [points[0][1]], dtype=np.float64)
    t = (np.arange(size) + 0.5) / size
    t = np.where(t < pos[0], t + 1.0, t)
    out = np.stack([np.interp(t, pos, rgb[:, c]) for c in range(3)], axis=1)
    return (np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
