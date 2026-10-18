from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SRC = Path(__file__).resolve().parents[5] / "tmp" / "pdfs" / "cs_sj"
OUT = ROOT / "paper-excerpts"
OUT.mkdir(parents=True, exist_ok=True)


def crop(page: int, box: tuple[int, int, int, int], name: str) -> None:
    image = Image.open(SRC / f"page-{page}.png")
    image.crop(box).save(OUT / name, optimize=True)


# Limited excerpts only; the complete IEEE PDF is intentionally not copied.
crop(2, (120, 120, 1580, 700), "paper_fig_1_structure.png")
crop(3, (115, 110, 1580, 940), "paper_fig_2_simulated_characteristics.png")
crop(4, (115, 570, 1580, 1420), "paper_fig_5_measured_characteristics.png")
crop(5, (130, 110, 1580, 640), "paper_fig_6_short_circuit.png")

# Panel-level crops used by the side-by-side comparison figures.
crop(3, (690, 145, 1080, 505), "paper_fig_2b_vth.png")
crop(3, (1130, 145, 1520, 505), "paper_fig_2c_icvc.png")
crop(3, (205, 595, 620, 900), "paper_fig_2d_turn_on.png")
crop(3, (690, 595, 1090, 900), "paper_fig_2e_turn_off.png")
crop(4, (555, 585, 900, 970), "paper_fig_5b_vth.png")
crop(4, (910, 585, 1260, 970), "paper_fig_5c_icvc.png")
crop(5, (165, 115, 520, 545), "paper_fig_6a_short_circuit.png")
