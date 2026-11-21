"""Draw the model equation as an image for the report and slides.

Word and Google Docs often can't display Unicode subscripts (y with a
subscript i, and so on), so the equation is typeset with matplotlib instead.

Usage (from the repository root):
    python scripts/10_make_equation.py

Output: outputs/report_figs/eq_model.png        (white background, for the report)
        outputs/report_figs/eq_model_slide.png  (light blue background, for the slides)
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")  # draw to files, no window
import matplotlib.pyplot as plt

OUTPUT_DIR = Path("outputs/report_figs")
INK = "#14213D"
EQUATION_LINES = [
    r"$y_i \sim \mathrm{NegBin}(\mu_i,\ \phi)$",
    r"$\log \mu_i = \beta_0 + \mathbf{x}_i^{\top}\beta + \gamma_{\mathrm{device}(i)} + u_{s(i)} + v_{c(i)}$",
    r"$u_s \sim \mathcal{N}(0,\ \sigma_s^2), \qquad v_c \sim \mathcal{N}(0,\ \sigma_c^2)$",
]


def draw_equation(path, background):
    """Save the three equation lines, centred, as a 300-dpi PNG at `path`."""
    matplotlib.rcParams["mathtext.fontset"] = "cm"   # Computer Modern, the LaTeX look
    fig = plt.figure(figsize=(8, 1.9), dpi=300)
    fig.patch.set_facecolor(background)
    for row, line in enumerate(EQUATION_LINES):
        fig.text(0.5, 0.80 - row * 0.31, line, ha="center", va="center", fontsize=20, color=INK)
    fig.savefig(path, facecolor=background, bbox_inches="tight", pad_inches=0.15)
    plt.close(fig)
    print(f"Wrote {path}")


if __name__ == "__main__":
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    draw_equation(OUTPUT_DIR / "eq_model.png", "white")
    draw_equation(OUTPUT_DIR / "eq_model_slide.png", "#C9D6E8")
