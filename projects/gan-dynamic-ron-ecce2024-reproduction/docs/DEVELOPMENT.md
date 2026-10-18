# Development and reproduction notes

The checked-in model files are editable snapshots. The MATLAB builders remain the main source of truth and regenerate the models and output figures. Preserve the two sibling directories under `outputs/`.

- The main executable entry is `outputs/full_reproduction/run_all.m`.
- `tools/validate_native_models.m` directly runs all saved models in a fresh session, without rebuilding or saving them. The Fig10 model stores its current/temperature fixture in its model workspace, so it does not depend on a caller-created base variable.
- The three files `outputs/reproduction/ltspice/common.inc`, `conventional_gates.inc` and `proposed_gates.inc` are required first-stage circuit sources; they are original implementation files and are included.
- Commercial simulator libraries are referenced by the SLX files and are supplied by your installed MATLAB release. The vendor MOSFET/diode SPICE libraries are obtained separately using `tools/fetch_external.py`.
- Standalone SLX execution and the complete builder pipeline are different tests. Both are recorded when run; portable CI only checks containers, published files and numeric evidence.
- Generated Simulink compilation files use unique temporary directories to avoid the Windows 260-character path limit in deeply nested checkouts. They can be cleared using the operating system's normal temporary-file cleanup after MATLAB exits.

The `README`, module model cards and the report retain the local study's assumptions and evidence limits. Paths to large RAW/MAT/FIG files describe generated outputs; those files are not committed. The paper and vendor PDFs are also not committed. Historical file hashes are provenance records and may refer to these external or regenerated files.

Before publishing changes, run the relevant native simulations, review result differences, then stage only the intended public files. With Git installed:

```bash
python tools/validate_repository.py --refresh
git add outputs/full_reproduction/manifest.json
python tools/validate_repository.py
```

The inventory is based on the Git index. It does not implicitly collect untracked simulator outputs or external vendor libraries. Text uses LF endings to make the recorded hashes consistent across Windows and Linux.

Do not remove the recorded failed clamp edge checks merely because the measurement window passes. A new claim of pointwise edge convergence requires fresh evidence. Do not describe the public-curve trapping fit, ideal heatsink temperatures or generated quantization budget as new independent hardware measurements.
