# Project documentation

## Workbench flow

The exported project contains two SDE device branches (Trench-FS NDBT and 2N CS-SJBT) followed by SDevice nodes for Ic-Vg, Ic-VCE, BV, DPT turn-on/turn-off, short circuit, and SVisual extraction.

Key Workbench parameters include gate-oxide thickness, P-base peak concentration, P-collector concentration, field-stop concentration, and drift/SJ concentrations. The final published results use the values stored in the exported Workbench tree; no additional parameter sweep is required to reproduce the displayed curves.

## Result-file mapping

| Analysis | NDBT | SJ-2N |
|---|---|---|
| Ic-Vg | `IcVg_n10_des.plt` | `IcVg_n11_des.plt` |
| Ic-VCE | `IcVc_n12_des.plt` | `IcVc_n13_des.plt` |
| BV | `BV_n14_des.plt` | `BV_n15_des.plt` |
| Turn-on | `n20_DPT_TurnOn_des.plt` | `n21_DPT_TurnOn_des.plt` |
| Turn-off | `n22_DPT_TurnOff_des.plt` | `n23_DPT_TurnOff_des.plt` |
| Short circuit | `SC_n24_SC_250V_des.plt` | `SC_n25_SC_250V_des.plt` |
| SC temperature | `SC_DUT_PowerIGBT_n24_des.plt` | `SC_DUT_PowerIGBT_n25_des.plt` |

## Extraction definitions

- `Vth`: gate voltage interpolated at `|Ic|=250 µA`, with `VCE=5 V`.
- `VCEsat`: collector voltage interpolated at `|Ic|=30 A`, with `VGE=15 V`.
- `BV`: NDBT uses the SDevice BreakCriteria output; SJ-2N reports the final converged PLT voltage and remains nonconverged.
- `tsc`: time from the 7.5 V rising crossing of VGE to the first `Tmax >= 1000 K` sample.

## Replotting

Install Python 3.10+ with packages listed in `scripts/requirements.txt`, then run:

```bash
python scripts/plot_results.py
```

The paper-excerpt extraction script expects locally rendered paper pages and is supplied for transparency; the complete IEEE PDF is intentionally absent.

