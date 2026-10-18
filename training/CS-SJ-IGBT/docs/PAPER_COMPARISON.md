# Comparison with Li et al. (IEEE TED, 2025)

## Scope

The main paper target is the simulated 650 V trench-FS CS-SJBT and its NDBT comparison. The public project focuses on the 2N layout and does not claim full experimental reproduction.

## Static characteristics

The project SJ-2N `VCEsat=1.481 V` at 30 A is close to the paper’s simulated `1.53 V`. The project `Vth=4.321 V` is lower than the paper’s simulated `4.8 V` but retains the intended NDBT/SJ comparison.

## Breakdown voltage

The paper reports simulated cell/terminal BV of 750/805 V. The current project does not reproduce this: NDBT reaches its current BreakCriteria near 308.7 V and SJ-2N becomes nonconvergent after 325 V. The BV figure is therefore labeled partial/nonconverged.

## Switching

The paper’s Fig. 2(d,e) uses 400 V, 30 A, `RG=22 Ω`, and `Lσ=30 nH`. The project DPT result shown here uses 250 V and zero initial inductor current, with load current built by the first pulse. Shape comparisons are meaningful; absolute switching energy is not reported as a paper match.

## Short circuit

The paper reports measured `tsc` near 1 µs (H5), 2 µs (SJ-2N), 6 µs (SJ-4N), and 8 µs (H3) at 400 V. This project uses 250 V electrothermal TCAD and a `Tmax=1000 K` failure boundary, giving 6.80 µs for NDBT and 6.31 µs for SJ-2N. These are model- and condition-dependent values, not direct reproduction of the measured 400 V result.

