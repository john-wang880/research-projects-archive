# Figure 13/14 independent paper audit

Source: author-accepted 8-page ECCE Europe 2024 manuscript,
`outputs/ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf`, page 7.

## Source provenance

The source PDF SHA-256 is
`0df6d7ddf4b4bbde241b4690f0f73ed644e232a0214c3041e4f1ca166e694e3c`.
`extract_plot_traces.py` reads native PDF vector paths using `pdfplumber`.
It calibrates each chart to native grid line coordinates, rather than
calibrating a raster screenshot. Output CSVs reconstruct plotted curves;
they are not unpublished laboratory data.

All figure paths were verified against rendered manuscript pages 2, 3, 7.
Fig. 13 current paths are PDF curve indices 11 and 12; voltage 16 and 17.
Fig. 14 current paths are 18 and 19; temperature 23 and 24.

## Topology and public time parameters

The positive-current charge path is HS2 -> L_DPT -> LS1, with DUT off.
Upper freewheeling uses HS1 and HS2. The lower measurement state uses
DUT and LS2, while HS1, HS2, LS1 are off. LS1 must not carry current in
measurement. The DUT current shunt is in the DUT branch only, and the
paper's DUT Vds measurement excludes the shunt drop.

For the conventional self-heating comparison, DUT replaces LS1 as the
charging device; LS1 remains off. This comparison should use the same
freewheeling/measurement sequence and identical current as far as practical.

Published setup: VDC 150 V, L_DPT 90 uH, C_DC 500 uF, charging 32.5 us,
nominal upper freewheel 1 us, nominal measurement 5 us, Tc 25 C, Vgs 6/0 V,
Rg 20/5.6 ohm, Rshunt 10 milliohm. The 32.5 us ramp gives an ideal
54.1667 A and agrees with Fig. 13's approximately 54--55 A peak. It does
not contradict the 90 uH inductance.

Fig. 13 vector-path maxima are approximately 55.33 A conventional and
54.75 A proposed. The stable 34.2--39.1 us plateau means are 52.33 and
52.28 A. The two traces differ slightly through finite loss, delay and
measurement behavior. Native visual half-stroke resolution is 0.0974 us,
0.323 A, and 0.0298 V. These are plotting resolutions, not measurement
error bars. Gate timing should follow the published 32.5+1+5 us, not be
retuned to match current-trace threshold crossing times.

## Figure 14 thermal trace reproduction

Fig. 14 uses a simplified 50 A current template:
0--32.5 us linear ramp, 32.5--33.5 us DUT current zero, and
33.5--38.5 us DUT current 50 A. Proposed DUT has only the final pulse.
Do not tune L or VDC to turn the physical Fig. 13 current into 50 A.

The Rev200402 GS66508B datasheet's actual Cauer ladder is
R=[0.015,0.23,0.24,0.015] K/W and
C=[8e-5,7.4e-4,6.5e-3,2e-3] J/K; each C is a shunt capacity,
successive R connect junction toward fixed case temperature.
It must not be interpreted as independent Foster exponentials.

An independent NumPy RK4 solution (`verify_thermal_traces.py`) uses
Ron 0.08 ohm, zero initial thermal rise, the public 50 A template, and
fixed case temperature. RK4 timestep convergence between 1 ns and 2 ns
is below 1.1 microkelvin in the measurement window.

| Metric | Conventional | Proposed |
|---|---:|---:|
| Independent mean, 33.5--38.5 us | 5.236685 K | 2.527375 K |
| Independent endpoint, 38.5 us | 6.123210 K | 3.632014 K |
| Native plotted-curve window mean | 5.222304 K | 2.519568 K |
| Native plotted-curve endpoint | 6.113378 K | 3.630049 K |
| Solver vs native plot RMSE | 0.014987 K | 0.009408 K |
| Solver vs native plot max abs | 0.026971 K | 0.024892 K |

The independent mean reduction is 51.7371%; the native-vector-curve mean
reduction is 51.7537%. Native visual half-stroke resolution is 0.0874 us
and 0.0334 K. The solver reproduces the plotted thermal curves within
the plotted vertical stroke resolution.

## Published mean annotation discrepancy

Fig. 14 labels the measurement-window means as 4.7 K and 1.8 K and
the text reports 62%. These labels do not match the average of the
plotted curves over the actual 33.5--38.5 us DUT conduction interval.

The two horizontal dashed mean lines have PDF x endpoints
505.02004654438 and 524.96584413614, mapping to 33.5--38.5 us.
Their PDF y coordinates are 484.67765073032 and 515.0093171618;
they map to approximately 4.674 and 1.771 K. The axis origin is
x=371.35247904838 for t=0; x scale is 3.9899575 PDF points per us;
temperature origin is y=533.52101979626 for 0 K, with y scale
10.4502158 PDF points per K. Thus the interval location is not an
axis-calibration mistake.

A deliberately different average interval 32.5--37.5 us gives roughly
4.834 and 1.822 K from the plotted curves, but is not the plotted
measurement interval and still does not fully explain both labels.
No averaging window or thermal parameter was tuned to force 62%.
The authors' exact averaging implementation is not public in this paper.
Report the mechanism and thermal curve reproduction as successful, and
keep the 62%/4.7/1.8 annotations as an unresolved reporting/averaging
inconsistency, rather than claiming they were independently reproduced.

## Remaining scope boundaries

Constant Ron 80 milliohm cannot explain the experimental Table I means
82.74 vs 79.50 milliohm on its own. A temperature-dependent Ron and
experimental trap history would be needed to reproduce those experimental
resistance values physically. Minute-scale Fig. 11/12 trap evolution and
Fig. 6 clamp noise/resolution are separate experimental/model tasks.
