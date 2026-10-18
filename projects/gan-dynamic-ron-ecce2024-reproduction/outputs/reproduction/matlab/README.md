# Figure 14 thermal reproduction

The MATLAB files implement the thermal calculation described in Swoboda et al., IEEE ECCE Europe 2024, DOI 10.1109/ECCEEurope62508.2024.10751914. MATLAB R2022b is supported; no extra toolbox is needed.

Run `run_figure14_reconstruction` to reconstruct the 50 A input explicitly plotted in Figure 14. This is a reconstruction of the figure's input, separate from the approximately 54 A circuit current in Figure 13. The thermal network is the GS66508B Rev 200402 four-stage **Cauer** ladder, with C1 connected at the junction and R4 ending at the fixed case boundary.

To use circuit-derived currents, call:

```matlab
thermal_reproduce('conventional_current.csv','proposed_current.csv',33.5e-6,38.5e-6,'ltspice_driven');
```

Each CSV must have numeric columns `time_s` and `dut_current_A`, cover the same simulation time range, and use increasing time. Timing arguments are in seconds and must match the actual circuit schedule. The integration includes the complete 5 us measurement interval. Input power is `80e-3 * current.^2`, linearly interpolated between samples; switching losses, trapping and electrothermal resistance feedback are excluded to follow the paper's thermal calculation method.

The initial thermal rise is zero; case temperature is fixed at 25 C. These boundary conditions are explicit local assumptions because the paper does not publish its original simulation project or complete initial thermal history. Outputs include native `.fig`, `.mat`, PNG, waveform CSV and JSON metrics. Reported losses are DUT conduction energy, and the Cauer solver checks that input energy equals stored thermal energy plus energy conducted to the case.

The original Figure 14 thermal traces and printed mean-temperature labels must be compared separately. The printed 4.7 K, 1.8 K and 62% labels are not targets for adjusting the integration window. The reconstruction run writes a comparison against independently extracted original PDF vector traces when these are available.

Run `validate_cauer` for independent verification. A 10 W constant input must converge to 5 K junction rise (`sum(R)=0.5 K/W`); the pulse result is checked against MATLAB `ode15s`, and the energy balance is checked across the complete transient. These verification inputs do not count as paper reproduction data.

Run `run_ltspice_thermal` after exporting the two LTspice waveform CSVs to `../data/`. Its default measurement window is 35.5–40.5 us because the local circuit begins charging at 2 us. It calculates two separate cases: the main conduction-pattern estimate uses `I(LLOAD)` only while `gate_dut_V>3 V`; a sensitivity case retains the raw DUT channel current. The latter includes sub-nanosecond capacitor-discharge spikes from the ideal switch and constant 200 pF Coss. Those spikes are not a validated GaN switching-current prediction. The reported difference between the two cases quantifies the numerical effect; neither case establishes the device's real switching losses.
