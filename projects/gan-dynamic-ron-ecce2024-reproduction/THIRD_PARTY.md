# Third-party sources

The repository's MIT license applies to the original implementation and authored documentation. It does not relicense the following external material.

| Material | Owner/source | Distribution in this repository |
|---|---|---|
| ECCE Europe 2024 manuscript | Swoboda et al.; IEEE; [KIT author-accepted manuscript](https://publikationen.bibliothek.kit.edu/1000176527) | Link and optional retrieval only; no manuscript PDF |
| STN1NK60Z SPICE model | [STMicroelectronics](https://www.st.com/resource/en/spice_model/stn1nk60z_spice.zip) | Not bundled; header reserves rights and restricts commercial use/resale |
| DMG2302UK SPICE model | [Diodes Incorporated](https://www.diodes.com/spice/download/1786/DMG2302UK.spice.txt) | Not bundled; original vendor terms remain intact after local retrieval |
| BAS21 SPICE model | [Diodes Incorporated](https://www.diodes.com/spice/download/1510/BAS21.spice.txt) | Not bundled; local compatibility copy comments a bare descriptive line, retaining all coefficients and notices |
| GS66508B datasheet | [Infineon / GaN Systems](https://www.infineon.com/assets/row/public/documents/24/49/infineon-gs66508b-datasheet-en.pdf) | Link only |
| QC-31-1.4-3.7CM specifications | [Quick-Ohm](https://www.quick-ohm.de/pdf/peltier-element/Information_TEC.pdf) | Link only; relevant table is page 7 |
| Additional device/instrument datasheets | Vendor links in module source manifests | Link only |
| MATLAB / Simulink / Simscape / LTspice | Respective software owners | Not bundled; install and license separately |

`tools/fetch_external.py` retrieves requested sources directly from their official endpoints and checks frozen source hashes. Read the vendor's applicable terms before using a model. No statement here grants redistribution rights or authorizes commercial use beyond those terms.

The clamp uses representative ST/Diodes **silicon** models, not an independently verified GS66508B GaN compact model or the authors' unpublished BOM. Numeric public-curve coordinates and reported values are attributed to the paper; fitted parameters and generated predictions are labelled as reconstruction. They are not independent experimental data.

The locally validated full research archive contained downloaded third-party files and large generated RAW/MAT/FIG results. That archive is intentionally not uploaded to this public repository or its releases. Public source and models remain runnable after local dependency retrieval, and large simulation outputs can be regenerated.
