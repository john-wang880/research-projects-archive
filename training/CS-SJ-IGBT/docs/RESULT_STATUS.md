# Result status

| Item | Status | Notes |
|---|---|---|
| NDBT SDE | Complete | Workbench source included in `.gzp` |
| SJ-2N SDE | Complete | Rephased SJ layout used |
| Ic-Vg / Vth | Complete | NDBT 4.169 V; SJ-2N 4.321 V |
| Ic-VCE / VCEsat | Complete | NDBT 1.542 V; SJ-2N 1.481 V at 30 A |
| NDBT BV | Partial | Current BreakCriteria near 308.7 V; below paper target |
| SJ-2N BV | Nonconverged | Final saved point 325 V |
| Turn-on | Complete | Project VCC=250 V; paper figure uses 400 V |
| Turn-off | Complete | Project VCC=250 V; paper figure uses 400 V |
| Short circuit | Complete under model criterion | NDBT 6.80 µs; SJ-2N 6.31 µs; Tfail=1000 K |

The dashboard and plots preserve these labels. Missing or failed cases are not extrapolated to paper values.

