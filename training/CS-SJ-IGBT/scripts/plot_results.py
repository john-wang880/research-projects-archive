from __future__ import annotations

import csv
import re
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Rectangle
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "results" / "raw"
CSV = ROOT / "results" / "csv"
FIG = ROOT / "figures"
PAPER = ROOT / "paper-excerpts"
CSV.mkdir(parents=True, exist_ok=True)
FIG.mkdir(parents=True, exist_ok=True)

BLUE = "#2767c5"
RED = "#d63c35"
GREEN = "#2ca25f"
INK = "#222222"
GRID = "#d9d9d9"

plt.rcParams.update({
    "font.family": "DejaVu Serif",
    "font.size": 10,
    "axes.linewidth": 1.0,
    "xtick.direction": "in",
    "ytick.direction": "in",
    "xtick.top": True,
    "ytick.right": True,
    "figure.facecolor": "white",
    "axes.facecolor": "white",
})


def read_dfise(path: Path) -> dict[str, np.ndarray]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    info, data = text.split("Data {", 1)
    block = re.search(r"datasets\s*=\s*\[(.*?)\]", info, re.S)
    if not block:
        raise ValueError(f"No datasets in {path}")
    names = re.findall(r'"([^"]+)"', block.group(1))
    values = np.asarray([float(x) for x in re.findall(r"[-+]?\d*\.?\d+(?:[Ee][-+]?\d+)?", data)])
    values = values[: (len(values) // len(names)) * len(names)].reshape(-1, len(names))
    return {name: values[:, i] for i, name in enumerate(names)}


def interp_x_at_y(x: np.ndarray, y: np.ndarray, target: float) -> float:
    order = np.argsort(y)
    ys, xs = y[order], x[order]
    keep = np.r_[True, np.diff(ys) > 0]
    return float(np.interp(target, ys[keep], xs[keep]))


def save(fig: plt.Figure, stem: str) -> None:
    fig.savefig(FIG / f"{stem}.png", dpi=240, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def paper_and_chart(paper_file: str, figsize=(11.4, 4.6)):
    fig, (left, right) = plt.subplots(1, 2, figsize=figsize, gridspec_kw={"width_ratios": [1, 1.12]})
    left.imshow(Image.open(PAPER / paper_file))
    left.axis("off")
    left.set_title("Paper excerpt", fontsize=12, weight="bold")
    right.set_title("This TCAD project", fontsize=12, weight="bold")
    return fig, left, right


def crossing_time(t, y, level, rising=True):
    if rising:
        idx = np.where((y[:-1] < level) & (y[1:] >= level))[0]
    else:
        idx = np.where((y[:-1] > level) & (y[1:] <= level))[0]
    return float(t[idx[-1]]) if len(idx) else float(t[np.argmax(np.abs(np.gradient(y, t)))])


nd_vg = read_dfise(RAW / "dc" / "IcVg_n10_des.plt")
sj_vg = read_dfise(RAW / "dc" / "IcVg_n11_des.plt")
nd_vc = read_dfise(RAW / "dc" / "IcVc_n12_des.plt")
sj_vc = read_dfise(RAW / "dc" / "IcVc_n13_des.plt")
nd_bv = read_dfise(RAW / "dc" / "BV_n14_des.plt")
sj_bv = read_dfise(RAW / "dc" / "BV_n15_des.plt")

vth_nd = interp_x_at_y(nd_vg["gate OuterVoltage"], np.abs(nd_vg["collector TotalCurrent"]), 250e-6)
vth_sj = interp_x_at_y(sj_vg["gate OuterVoltage"], np.abs(sj_vg["collector TotalCurrent"]), 250e-6)
vcesat_nd = interp_x_at_y(nd_vc["collector OuterVoltage"], np.abs(nd_vc["collector TotalCurrent"]), 30.0)
vcesat_sj = interp_x_at_y(sj_vc["collector OuterVoltage"], np.abs(sj_vc["collector TotalCurrent"]), 30.0)


# 00 - structure
fig, left, right = paper_and_chart("paper_fig_1_structure.png", (12.5, 4.8))
right.set_xlim(0, 12); right.set_ylim(51, -2); right.set_aspect("auto")
right.add_patch(Rectangle((0, 0), 12, 51, facecolor="#dfff00", edgecolor=INK))
for x in (0, 6):
    right.add_patch(Rectangle((x, 5), 3, 43.5, facecolor="#8fd14f", edgecolor="none"))
right.add_patch(Rectangle((0, 0), 12, 5, facecolor="#c8f000", edgecolor="none"))
right.add_patch(Rectangle((0, 48.5), 12, 1.0, facecolor="#f6de49", edgecolor="none"))
right.add_patch(Rectangle((0, 49.5), 12, 1.5, facecolor="#ef6f8e", edgecolor="none"))
for xc in (3, 9):
    right.add_patch(Rectangle((xc-.48, 0), .96, 2.8, facecolor="#39a2db", edgecolor=INK, lw=.8))
right.text(6, 2.2, "P-body / N-CS", ha="center")
right.text(1.5, 27, "P-pillar", rotation=90, ha="center", va="center")
right.text(4.5, 27, "N-pillar", rotation=90, ha="center", va="center")
right.text(6, 50.5, "FS / P-collector", ha="center", va="center")
right.set_xlabel("12 µm SJ pitch (schematic)"); right.set_ylabel("Depth (µm)")
right.grid(False)
fig.suptitle("Structure comparison - 650 V trench-FS CS-SJBT", y=1.02, weight="bold")
save(fig, "fig_00_structure_comparison")


# 01 - Vth
fig, _, ax = paper_and_chart("paper_fig_2b_vth.png")
for data, label, color, ls in ((nd_vg, "NDBT", INK, "--"), (sj_vg, "SJ-2N", RED, "-")):
    ax.semilogy(data["gate OuterVoltage"], np.abs(data["collector TotalCurrent"]), label=label, color=color, ls=ls, lw=2)
ax.axhline(250e-6, color=BLUE, ls=":", lw=1.3, label="250 µA criterion")
ax.scatter([vth_nd, vth_sj], [250e-6, 250e-6], c=[INK, RED], zorder=5)
ax.annotate(f"{vth_nd:.2f} V", (vth_nd, 250e-6), xytext=(-42, 13), textcoords="offset points")
ax.annotate(f"{vth_sj:.2f} V", (vth_sj, 250e-6), xytext=(8, -18), textcoords="offset points", color=RED)
ax.set(xlabel="$V_{GE}$ (V)", ylabel="$|I_C|$ (A)", xlim=(0, 8), ylim=(1e-8, 1e2))
ax.grid(True, which="both", color=GRID, lw=.5); ax.legend(frameon=True, fontsize=9)
fig.suptitle("Threshold-voltage comparison ($V_{CE}=5$ V)", y=1.02, weight="bold")
save(fig, "fig_01_icvg_vth_comparison")


# 02 - IcVc/VCEsat
fig, _, ax = paper_and_chart("paper_fig_2c_icvc.png")
for data, label, color, ls in ((nd_vc, "NDBT", INK, "--"), (sj_vc, "SJ-2N", RED, "-")):
    ax.plot(data["collector OuterVoltage"], np.abs(data["collector TotalCurrent"]), label=label, color=color, ls=ls, lw=2)
ax.axhline(30, color=BLUE, ls=":", lw=1.3)
ax.scatter([vcesat_nd, vcesat_sj], [30, 30], c=[INK, RED], zorder=5)
ax.annotate(f"NDBT {vcesat_nd:.3f} V", (vcesat_nd, 30), xytext=(1.75, 78), textcoords="data")
ax.annotate(f"SJ-2N {vcesat_sj:.3f} V", (vcesat_sj, 30), xytext=(1.75, 48), textcoords="data", color=RED)
ax.set(xlabel="$V_{CE}$ (V)", ylabel="$|I_C|$ (A)", xlim=(0, 5), ylim=(0, max(75, np.max(np.abs(nd_vc["collector TotalCurrent"]))*1.04)))
ax.grid(True, color=GRID, lw=.6); ax.legend(frameon=True)
fig.suptitle("Output characteristics and $V_{CE(sat)}$ at 30 A", y=1.02, weight="bold")
save(fig, "fig_02_icvc_vcesat_comparison")


# 03 - BV partial
fig, ax = plt.subplots(figsize=(7.6, 4.8))
for data, label, color in ((nd_bv, "NDBT (BreakCriteria at 308.7 V)", INK), (sj_bv, "SJ-2N (nonconverged; last PLT 325 V)", RED)):
    ax.semilogy(data["collector OuterVoltage"], np.maximum(np.abs(data["collector TotalCurrent"]), 1e-15), label=label, color=color, lw=2)
ax.set(xlabel="$V_{CE}$ (V)", ylabel="$|I_C|$ (A)", xlim=(0, 360))
ax.grid(True, which="both", color=GRID, lw=.5); ax.legend(frameon=True, fontsize=9, loc="lower right")
ax.set_title("BV comparison - partial/nonconverged", weight="bold")
ax.text(.02, .96, "Paper target: cell 750 V; terminal 805 V\nProject result is not a successful BV reproduction.", transform=ax.transAxes, va="top", bbox=dict(fc="white", ec="#bbbbbb", alpha=.92))
save(fig, "fig_03_bv_comparison_partial")


def switching_plot(paper_file, files, rising, stem, title):
    fig, _, ax = paper_and_chart(paper_file, (11.8, 4.6))
    ax2 = ax.twinx()
    for path, label, color in files:
        d = read_dfise(path)
        # Align on the midpoint of the VCE switching transition. This keeps the
        # complete 250 V edge visible even when the internal gate crosses 7.5 V late.
        t0 = crossing_time(d["time"], d["v(collector)"], 125.0, rising=not rising)
        x = (d["time"] - t0) * 1e6
        mask = (x >= -0.22) & (x <= 0.65)
        ax.plot(x[mask], d["v(gate)"][mask], color=color, lw=1.6, ls="--", label=f"$V_{{GE}}$ {label}")
        ax.plot(x[mask], np.abs(d["i(DUT,collector)"][mask]), color=color, lw=2.0, label=f"$I_C$ {label}")
        ax2.plot(x[mask], d["v(collector)"][mask], color=color, lw=1.6, ls=":", label=f"$V_{{CE}}$ {label}")
    ax.set(xlabel="Time from $V_{CE}$ midpoint (µs)", ylabel="$V_{GE}$ (V) or $|I_C|$ (A)")
    ax2.set_ylabel("$V_{CE}$ (V)")
    ax.grid(True, color=GRID, lw=.5)
    h1, l1 = ax.get_legend_handles_labels(); h2, l2 = ax2.get_legend_handles_labels()
    ax.legend(h1+h2, l1+l2, fontsize=7.5, ncol=2, loc="best", frameon=True)
    fig.suptitle(title, y=1.02, weight="bold")
    save(fig, stem)


switching_plot("paper_fig_2d_turn_on.png", [(RAW/"dpt"/"n20_DPT_TurnOn_des.plt", "NDBT", INK), (RAW/"dpt"/"n21_DPT_TurnOn_des.plt", "SJ-2N", RED)], True, "fig_04_turn_on_comparison", "Turn-on - paper 400 V vs this project 250 V")
switching_plot("paper_fig_2e_turn_off.png", [(RAW/"dpt"/"n22_DPT_TurnOff_des.plt", "NDBT", INK), (RAW/"dpt"/"n23_DPT_TurnOff_des.plt", "SJ-2N", RED)], False, "fig_05_turn_off_comparison", "Turn-off - paper 400 V vs this project 250 V")


# 06 - short circuit
nd_sc = read_dfise(RAW/"short-circuit"/"SC_n24_SC_250V_des.plt")
sj_sc = read_dfise(RAW/"short-circuit"/"SC_n25_SC_250V_des.plt")
nd_temp = read_dfise(RAW/"short-circuit"/"SC_DUT_PowerIGBT_n24_des.plt")
sj_temp = read_dfise(RAW/"short-circuit"/"SC_DUT_PowerIGBT_n25_des.plt")
fig, _, ax = paper_and_chart("paper_fig_6a_short_circuit.png", (12.0, 4.8))
ax2 = ax.twinx()
sc_metrics = []
for d, td, label, color in ((nd_sc, nd_temp, "NDBT", INK), (sj_sc, sj_temp, "SJ-2N", BLUE)):
    t0 = crossing_time(d["time"], d["v(gate)"], 7.5, True)
    x = (d["time"] - t0)*1e6
    imax = min(len(d["time"]), len(td["time"]))
    hits = np.where(td["Tmax"][:imax] >= 1000.0)[0]
    tfail = float(td["time"][hits[0]]) if len(hits) else float(td["time"][imax-1])
    tsc = (tfail-t0)*1e6
    sc_metrics.append((label, tsc, float(np.max(np.abs(d["i(DUT,collector)"]))), float(np.max(td["Tmax"]))))
    ax.plot(x, d["v(gate)"], color=color, ls="--", lw=1.5, label=f"$V_{{GE}}$ {label}")
    ax.plot(x, np.abs(d["i(DUT,collector)"])/1000, color=color, lw=2, label=f"$I_C$ {label} (kA)")
    ax2.plot(x, d["v(collector)"], color=color, ls=":", lw=1.5, label=f"$V_{{CE}}$ {label}")
    ax.axvline(tsc, color=color, lw=1.4, ls="-.")
    ax.text(tsc-.08, .08, f"$t_{{sc}}$={tsc:.2f} µs", transform=ax.get_xaxis_transform(), rotation=90, color=color, va="bottom", ha="right")
ax.set(xlabel="Time from gate crossing (µs)", ylabel="$V_{GE}$ (V) or $|I_C|$ (kA)", xlim=(-.5, 8.0))
ax2.set_ylabel("$V_{CE}$ (V)")
ax.grid(True, color=GRID, lw=.5)
h1,l1=ax.get_legend_handles_labels(); h2,l2=ax2.get_legend_handles_labels(); ax.legend(h1+h2,l1+l2,fontsize=7.5,ncol=2,loc="upper right")
ax.text(.02,.04,"Project: $V_{CC}=250$ V, $V_{GE}=15$ V, $T_{fail}=1000$ K\nPaper: 400 V measured data; absolute values are not directly comparable.",transform=ax.transAxes,bbox=dict(fc="white",ec="#bbbbbb",alpha=.92),fontsize=8)
fig.suptitle("Short-circuit comparison", y=1.02, weight="bold")
save(fig, "fig_06_short_circuit_comparison")


# 07 - dashboard
fig, ax = plt.subplots(figsize=(10.5, 5.5)); ax.axis("off")
rows = [
    ["Vth @ 250 µA", f"{vth_nd:.3f} V", f"{vth_sj:.3f} V", "Paper sim. SJ: 4.8 V"],
    ["VCEsat @ 30 A", f"{vcesat_nd:.3f} V", f"{vcesat_sj:.3f} V", "Paper sim. SJ: 1.53 V"],
    ["BV", "308.7 V BreakCriteria", "325 V last converged", "Partial / nonconverged"],
    ["Short circuit", f"{sc_metrics[0][1]:.2f} µs", f"{sc_metrics[1][1]:.2f} µs", "250 V, Tfail=1000 K"],
    ["SC peak current", f"{sc_metrics[0][2]/1000:.2f} kA", f"{sc_metrics[1][2]/1000:.2f} kA", "AreaFactor=1e6"],
]
table = ax.table(cellText=rows, colLabels=["Metric", "NDBT", "SJ-2N", "Context"], cellLoc="center", loc="center", colWidths=[.22,.22,.22,.34])
table.auto_set_font_size(False); table.set_fontsize(10); table.scale(1, 1.75)
for (r,c), cell in table.get_celld().items():
    cell.set_edgecolor("#a0a0a0")
    if r == 0: cell.set_facecolor("#e7eef8"); cell.set_text_props(weight="bold")
ax.set_title("CS-SJ-IGBT reproduction status dashboard", fontsize=15, weight="bold", pad=20)
save(fig, "fig_07_results_dashboard")


with (CSV / "extracted_metrics.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["metric", "NDBT", "SJ-2N", "unit", "status_or_condition"])
    w.writerow(["Vth", vth_nd, vth_sj, "V", "Ic=250uA; VCE=5V"])
    w.writerow(["VCEsat", vcesat_nd, vcesat_sj, "V", "Ic=30A; VGE=15V"])
    w.writerow(["BV", 308.7, float(sj_bv["collector OuterVoltage"][-1]), "V", "NDBT BreakCriteria; SJ failed"])
    w.writerow(["tsc", sc_metrics[0][1], sc_metrics[1][1], "us", "VCC=250V; VGE=15V; Tfail=1000K"])
    w.writerow(["SC_Ic_peak", sc_metrics[0][2], sc_metrics[1][2], "A", "AreaFactor=1e6"])
    w.writerow(["SC_Tmax", sc_metrics[0][3], sc_metrics[1][3], "K", "thermal failure criterion"])
