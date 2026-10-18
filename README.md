# Semiconductor Simulation & Reproduction Archive

This archive contains five independent simulation/reproduction projects copied from public repositories owned by [Greatlovers](https://github.com/Greatlovers). The source repositories remain unchanged.

## Projects from the TCAD collection

- **CS-SJ-IGBT** — 650 V trench field-stop charge-storage super-junction IGBT reproduction. See [project README](training/CS-SJ-IGBT/README.md), [Workbench export](training/CS-SJ-IGBT/CS-SJ-IGBT.gzp), and [results dashboard](training/CS-SJ-IGBT/figures/fig_07_results_dashboard.png).
- **RC-IGBT** — reverse-conducting IGBT Sentaurus project. See [project README](training/RC-IGBT/README.md), [sanitized Workbench package](training/RC-IGBT/RC-IGBT_swb_project_sanitized.zip), and [PDF guide](training/RC-IGBT/rc_igbt_project_documentation.pdf).
- **dynamic-CBL-IGBT-3D** — 3D dynamic-CBL IGBT Sentaurus project. See [project folder](projects/dynamic-CBL-IGBT-3D/); the archive excludes material parameters.
- **4H-SiC micro-hole UV photodiode arrays** — Sentaurus source templates and setup utilities for reproducing Figures 3–4. See [project README](projects/reproduction-of-high-speed-4h-sic-micro-hole-uv-photodiode-arrays/README.md); material parameter files and optical tables are intentionally excluded.

## GaN dynamic on-resistance reproduction

- **GaN dynamic Ron — ECCE Europe 2024** — independent MATLAB / Simulink / Simscape Electrical / LTspice reproduction, with native models, audited results, scripts, and a Chinese reproduction report. See [project README](projects/gan-dynamic-ron-ecce2024-reproduction/README.md) and [full reproduction report](projects/gan-dynamic-ron-ecce2024-reproduction/outputs/full_reproduction/GaN_ECCE2024_全篇仿真复现报告.pdf). Reconstructed public curves are not new hardware measurements; limitations are documented in the source README.

## Requirements and notices

Rerunning projects requires the appropriate local software and licenses, including Sentaurus/Synopsys and, for the GaN project, MATLAB/Simulink/Simscape and/or LTspice for the relevant workflows. Some projects intentionally exclude material parameters, optical tables, vendor models, or generated states; read each project's README before running. Preserve original license and notice files. Third-party papers, vendor files, and other third-party content remain subject to their owners' rights; this archive grants no additional rights.

## Sources

- https://github.com/Greatlovers/TCAD
- https://github.com/Greatlovers/dynamic-CBL-IGBT-3D
- https://github.com/Greatlovers/reproduction-of-high-speed-4h-sic-micro-hole-uv-photodiode-arrays
- https://github.com/Greatlovers/gan-dynamic-ron-ecce2024-reproduction
