# Original figure reference data

These CSV files reconstruct the plotted vector paths on page 7 of the author accepted manuscript, not the authors' unpublished raw experimental data. Source: *Improved Test Circuit for Characterization of the Dynamic On-Resistance of GaN-HEMTs over a Wide Operating Range*, DOI 10.1109/ECCEEurope62508.2024.10751914, KITopen https://publikationen.bibliothek.kit.edu/1000176527.

`*_native.csv` preserves calibrated path vertices; the shorter-name CSVs use a common 0.01 us grid. `plot_extraction_metadata.json` records axis calibration, PDF curve indices and half-stroke plotting resolution. That resolution is a visual reading tolerance, not measurement uncertainty.

The MATLAB reconstruction can read `figure14_temperature.csv` from this folder for a direct overlay. To rerun extraction with an arbitrary full-text PDF path:

```text
python extract_plot_traces.py path/to/ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf
```

Python packages: NumPy and pdfplumber. `verify_thermal_traces.py` independently integrates the Cauer equations by RK4, checks 1 ns versus 2 ns convergence and compares the full 33.5–38.5 us measurement interval with the original plot. This check confirms agreement with the plotted temperature traces and a discrepancy with the printed mean labels; its inputs and reported results remain separate from the LTspice circuit current reproduction.

Source full-text SHA256: `0df6d7ddf4b4bbde241b4690f0f73ed644e232a0214c3041e4f1ca166e694e3c`.
