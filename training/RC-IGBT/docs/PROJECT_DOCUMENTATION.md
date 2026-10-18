# RC-IGBT Project Documentation

## 1. Project purpose

This public release documents an RC-IGBT Sentaurus TCAD project. The project is organized for GitHub browsing, portfolio display, and partial reproduction. It focuses on the main Workbench flow and the SDevice result coverage rather than exposing every generated runtime file in the repository tree.

## 2. Device concept

The simulated device is a reverse-conducting IGBT. The device keeps the MOS-controlled IGBT conduction path on the emitter side and uses a collector-side P+ / N+ short segmentation to provide a reverse conduction path. This makes it suitable for studying forward IGBT conduction, blocking behavior, transient reverse-recovery-like behavior, and snapback.

Key structure blocks:

| Region | Role |
|---|---|
| Gate / oxide / channel | Controls electron injection from the emitter side |
| N+ emitter | Low-resistance electron source region |
| P-body | Forms the MOS channel and body junction |
| N- drift region | Supports high voltage in blocking mode |
| N buffer / field-stop layer | Shapes the electric field and supports punch-through control |
| P+ collector | Provides hole injection for IGBT conductivity modulation |
| N+ collector short | Provides reverse conduction path and affects snapback behavior |

## 3. Workbench flow

```text
sde -> IcVg -> svisual -> IcVc -> svisual1 -> BV -> svisual2 -> tran_reverse_recovery -> svisual3 -> snapback -> svisual4
```

The two main branches compare `self_heating=off` and `self_heating=on` where applicable.

## 4. SDevice simulations

| Simulation | Purpose | Typical observed output |
|---|---|---|
| Ic-Vg | Transfer characteristics at fixed collector voltage | Gate-controlled turn-on and threshold-related behavior |
| Ic-Vc | Output characteristics at fixed gate voltage | On-state current and output curve behavior |
| BV | Blocking / breakdown sweep | Leakage and breakdown trend on log-current axis |
| DPT / reverse recovery | Transient system-level analysis | Gate, switch-node, load, and device current waveforms |
| Snapback | Continuation-style sweep | Snapback branch and current-voltage transition |
| Thermodynamic runs | Self-heating comparison | Maximum lattice temperature trend |

## 5. Public filtering policy

The repository intentionally excludes files that are risky or noisy for public release:

- `*.par` material parameter files
- `*.tdr` and `*.sav` binary state files
- logs, job files, backup folders, trial snapshots, and temporary files
- local VM/server paths and machine-specific runtime metadata
- license files and vendor model files

The visible GitHub page keeps the plots and documentation prominent. Reproduction-oriented files should stay inside a cleaned package and must be reviewed before public distribution.

## 6. Reproduction notes

To reproduce or extend the project:

1. Use a legal local Sentaurus installation.
2. Provide local material parameter files if the command decks reference external parameters.
3. Start from the structure / mesh generation node.
4. Run Ic-Vg and Ic-Vc before interpreting higher-stress simulations.
5. Run BV, transient, and snapback nodes after confirming the DC operating behavior.
6. Compare generated PLT curves against the ranges in `docs/SDEVICE_RESULT_SUMMARY.md`.

## 7. Result display strategy

The most important SDevice results are placed directly in the project README through `figures/rc_igbt_sdevice_results_dashboard.svg`. This keeps the repository homepage readable while still showing all major simulation categories.
