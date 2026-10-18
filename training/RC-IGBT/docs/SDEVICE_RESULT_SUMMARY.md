# SDevice Result Summary

The ranges below were extracted from the uploaded SDevice PLT result files before public filtering. They are used to generate the visible result dashboard.

| Simulation | File | Points | VGE range | VCE range | IC range | Tmax range |
|---|---|---:|---|---|---|---|
| Ic-Vg | `n10_des.plt` | 41 | 0 to 15 V | 5 to 5 V | 8.339e-08 to 43.60 A | - |
| Ic-Vg | `n11_des.plt` | 41 | 0 to 15 V | 5 to 5 V | 8.339e-08 to 43.57 A | 300 to 300.2 K |
| Ic-Vc | `n18_des.plt` | 81 | 15 to 15 V | 0 to 10 V | -1.58e-13 to 72.91 A | - |
| Ic-Vc | `n19_des.plt` | 81 | 15 to 15 V | 0 to 10 V | -6.106e-15 to 72.76 A | 300 to 300.6 K |
| BV | `n22_des.plt` | 37 | 0 to 0 V | 0 to 267.6 V | -1.152e-18 to 0.01299 A | - |
| BV | `n23_des.plt` | 49 | 0 to 0 V | 0 to 267.6 V | 2.165e-18 to 0.01196 A | 300 to 300.0 K |
| Snapback | `n30_des.plt` | 295 | 15 to 15 V | 0 to 0.1711 V | -2.03e-13 to 0.2006 A | - |
| Snapback | `n31_des.plt` | 295 | 15 to 15 V | 0 to 0.1711 V | 7.055e-13 to 0.2006 A | 300 to 300.0 K |
| DPT / reverse recovery | `DPT_n26_sys_des.plt` | 20 | - | - | - | - |
| DPT / reverse recovery | `DPT_n27_sys_des.plt` | 123 | - | - | - | - |
| DPT / reverse recovery | `DPT_Q1_n26_des.plt` | 401 | 0 to 15 V | 0.4508 to 50.63 V | -0.008349 to 65.42 A | - |
| DPT / reverse recovery | `DPT_Q1_n27_des.plt` | 401 | 0 to 15 V | 0.4445 to 50.62 V | -0.008349 to 65.40 A | - |
| DPT / reverse recovery | `DPT_Q2_n26_des.plt` | 401 | 0 to 0 V | 50 to 50 V | -1.187 to 11.26 A | - |
| DPT / reverse recovery | `DPT_Q2_n27_des.plt` | 401 | 0 to 0 V | 50 to 50 V | -1.180 to 11.27 A | - |
| Snapback continuation | `Continuation_n30_des.plt` | 88 | 15 to 15 V | 0 to 33.86 V | 7.389e-14 to 119.9 A | - |
| Snapback continuation | `Continuation_n31_des.plt` | 88 | 15 to 15 V | 0 to 33.67 V | 6.909e-13 to 119.2 A | 300 to 302 K |

## Notes

- The dashboard plots are compact overview figures; the table above keeps the numeric ranges explicit.
- Self-heating branches are included where thermodynamic output variables are available.
- Material parameter files and heavy binary states are not published in the visible tree.
