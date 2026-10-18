"""Cross-check all actual LTspice stepped RAW traces against native Simulink.

The two solvers use the same explicitly reduced reverse-conduction mechanism.
Their agreement verifies implementation, not a GS66508B compact model or hardware.
Run with Python + numpy after the serialized LTspice run has finished.
"""
from pathlib import Path
import csv
import hashlib
import json
import re

import numpy as np

HERE = Path(__file__).resolve().parent


def decode(path):
    raw = path.read_bytes()
    encoding = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
    return raw.decode(encoding).replace("\r\n", "\n")


def interval_mean(time, signal, start=2e-6, end=5.8e-6):
    mask = (time > start) & (time < end)
    x = np.r_[start, time[mask], end]
    y = np.r_[np.interp(start, time, signal), signal[mask], np.interp(end, time, signal)]
    return float(np.trapezoid(y, x) / (end - start))


def main():
    log = decode(HERE / "scrc_parallel.log")
    pattern = r"^\.step it=([^ ]+) vg_d=([^ ]+) gap=([^\n]+)$"
    steps = [tuple(map(float, m)) for m in re.findall(pattern, log, flags=re.M | re.I)]
    assert len(steps) == 72, f"Expected 72 completed steps, found {len(steps)}"
    warnings = [line.strip() for line in log.splitlines()
                if re.search(r"questionable|undefined symbol|fatal|timestep too small", line, re.I)]
    assert not warnings, f"Resolve LTspice diagnostics before accepting: {warnings}"
    text = decode(HERE / "scrc_parallel.raw")
    header, body = text.split("Values:\n", 1)
    nvars = int(re.search(r"No\. Variables:\s*(\d+)", header).group(1))
    npoints = int(re.search(r"No\. Points:\s*(\d+)", header).group(1))
    variable_lines = header.split("Variables:\n", 1)[1].strip().splitlines()
    names = [line.split()[1].lower() for line in variable_lines]
    assert names == ["time", "v(drain)", "v(source_dut)", "i(b_dut)", "i(b_ls1)", "i(i_load)"], names
    # ASCII RAW has a point index before each time value, followed by nvars-1 values.
    parsed = np.fromstring(body, sep=" ")
    assert parsed.size == npoints * (nvars + 1), (parsed.size, npoints, nvars)
    data = parsed.reshape(npoints, nvars + 1)[:, 1:]
    cuts = np.r_[0, np.flatnonzero(np.diff(data[:, 0]) < 0) + 1, npoints]
    assert len(cuts) - 1 == len(steps), (len(cuts) - 1, len(steps))
    with (HERE / "scrc_current_sharing_sweep.csv").open(encoding="utf-8-sig", newline="") as f:
        native_rows = [{key: float(value) for key, value in row.items()} for row in csv.DictReader(f)]
    native = {(row["reverseTotalCurrent_A"], row["VgDUT_V"], row["gateGap_V"]): row
              for row in native_rows}
    comparisons = []
    for index, ((itotal, gate, gap), first, last) in enumerate(zip(steps, cuts[:-1], cuts[1:]), 1):
        trace = data[first:last]
        time = trace[:, 0]
        assert time[0] == 0 and time[-1] >= 8e-6 * (1 - 1e-9), (index, time[0], time[-1])
        row = native[(itotal, gate, gap)]
        dut = interval_mean(time, trace[:, 3])
        auxiliary = interval_mean(time, trace[:, 4])
        vsd = interval_mean(time, trace[:, 2] - trace[:, 1])
        common = interval_mean(time, -trace[:, 1])
        load = interval_mean(time, trace[:, 5])
        # This plateau check includes the deliberately retained 1 GOhm leak.
        kcl = abs(load - dut - auxiliary - common / 1e9)
        fdut = max(1.7 - gate, 0.)
        faux = max(1.7 - (gate - gap), 0.)
        comparisons.append({
            "SPICE_step": index,
            "reverseTotalCurrent_A": itotal,
            "VgDUT_V": gate,
            "VgLS1_V": gate - gap,
            "gateGap_V": gap,
            "DUT_branchThreshold_V": fdut,
            "LS1_branchThreshold_V": faux,
            "SPICE_DUT_A": dut,
            "Simulink_DUT_A": row["DUT_reverseCurrent_A"],
            "DUT_currentDifference_A": dut - row["DUT_reverseCurrent_A"],
            "SPICE_LS1_A": auxiliary,
            "Simulink_LS1_A": row["LS1_reverseCurrent_A"],
            "LS1_currentDifference_A": auxiliary - row["LS1_reverseCurrent_A"],
            "SPICE_DUT_Vsd_V": vsd,
            "Simulink_DUT_Vsd_V": row["DUT_Vsd_V"],
            "DUT_voltageDifference_V": vsd - row["DUT_Vsd_V"],
            "SPICE_effectiveSCRCresistance_Ohm": vsd / dut,
            "Simulink_effectiveSCRCresistance_Ohm": row["trueEffectiveSCRCresistance_Ohm"],
            "effectiveSCRCresistanceDifference_Ohm": vsd / dut - row["trueEffectiveSCRCresistance_Ohm"],
            "SPICE_plateauKCLerror_A": kcl,
        })
    with (HERE / "scrc_spice_native_crosscheck.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(comparisons[0]))
        writer.writeheader()
        writer.writerows(comparisons)
    maxabs = lambda key: max(abs(row[key]) for row in comparisons)
    mixed = [row for row in comparisons if row["VgDUT_V"] == 6 and row["VgLS1_V"] == 0]
    assert len(mixed) == 3
    assert all(row["DUT_branchThreshold_V"] == 0 and row["LS1_branchThreshold_V"] == 1.7 for row in mixed)
    assert maxabs("DUT_currentDifference_A") < 1e-6
    assert maxabs("LS1_currentDifference_A") < 1e-6
    assert maxabs("DUT_voltageDifference_V") < 1e-6
    assert maxabs("SPICE_plateauKCLerror_A") < 1e-6
    metrics = {
        "scope": "Independent numerical engines for the same reduced behavioral circuit; implementation verification only",
        "nativeModel": "GaN_SCRC_Current_Sharing.slx",
        "SPICEcircuit": "scrc_parallel.cir",
        "actualSPICEcases": len(steps),
        "actualNativeCases": len(native),
        "actualRAWpoints": npoints,
        "meanWindow_s": [2e-6, 5.8e-6],
        "maximumDUTcurrentDifference_A": maxabs("DUT_currentDifference_A"),
        "maximumLS1currentDifference_A": maxabs("LS1_currentDifference_A"),
        "maximumDUTvoltageDifference_V": maxabs("DUT_voltageDifference_V"),
        "maximumEffectiveSCRCresistanceDifference_Ohm": maxabs("effectiveSCRCresistanceDifference_Ohm"),
        "maximumSPICEplateauKCLerror_A": maxabs("SPICE_plateauKCLerror_A"),
        "gateDomain_V": [min(row["VgLS1_V"] for row in comparisons), max(row["VgDUT_V"] for row in comparisons)],
        "continuousGateRating_V": [-10, 7],
        "gateDomainWithinContinuousRating": True,
        "mixedBranchDUT6LS1zeroGate": mixed,
        "LTspicePreparserOrFatalDiagnostics": warnings,
        "SHA256": {filename: hashlib.sha256((HERE / filename).read_bytes()).hexdigest()
                   for filename in ["scrc_parallel.cir", "scrc_parallel.raw", "scrc_parallel.log", "scrc_current_sharing_sweep.csv"]},
        "passed": True,
    }
    (HERE / "scrc_crosscheck_metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in metrics.items()
                      if key not in ("mixedBranchDUT6LS1zeroGate", "SHA256")}, indent=2))


if __name__ == "__main__":
    main()
