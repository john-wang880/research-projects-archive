"""Compare native ASC-generated waveforms against the already checked CIR cases."""
from pathlib import Path
import json, hashlib, re
import numpy as np
from analyze_clamp import read_raw, avg

here=Path(__file__).resolve().parent
rows=[]
def canonical(path):
    parts=[]
    for line in path.read_text().lower().splitlines():
        line=' '.join(line.split())
        if not line or line.startswith('*') or line.startswith('.lib ') or line in ('.backanno','.model d d'):
            continue
        line=re.sub(r'^xx','x',line)
        line=re.sub(r'\bp001\b','tvs_mid',line)
        parts.append(line)
    return sorted(parts)
for item in json.loads((here/'native_schematic_manifest.json').read_text(encoding='utf-8-sig')):
    asc=here/item['native_schematic'];cir=here/item['equivalent_verified_deck']
    assert canonical(asc.with_suffix('.net'))==canonical(cir),'Native netlist topology/value mismatch'
    a=read_raw(asc.with_suffix('.raw'));b=read_raw(cir.with_suffix('.raw'))
    assert abs(a['time'][-1]-3e-6)<1e-13
    t=np.linspace(0,3e-6,30001)
    diff=np.interp(t,a['time'],a['v(out)'])-np.interp(t,b['time'],b['v(out)'])
    plateau_a=avg(a['time'],a['v(out)'],1.4e-6,1.8e-6)
    plateau_b=avg(b['time'],b['v(out)'],1.4e-6,1.8e-6)
    row=dict(native_schematic=asc.name,equivalent_deck=cir.name,
             asc_sha256=hashlib.sha256(asc.read_bytes()).hexdigest(),
             asc_raw_sha256=hashlib.sha256(asc.with_suffix('.raw').read_bytes()).hexdigest(),
             cir_raw_sha256=hashlib.sha256(cir.with_suffix('.raw').read_bytes()).hexdigest(),
             transient_max_voltage_difference_V=float(np.max(np.abs(diff))),
             transient_rms_voltage_difference_V=float(np.sqrt(np.mean(diff**2))),
             native_plateau_V=plateau_a,cir_plateau_V=plateau_b,
             plateau_difference_V=plateau_a-plateau_b,native_end_time_s=float(a['time'][-1]),
             canonical_native_netlist_identical=True,
             measurement_window_pass=bool(abs(plateau_a-plateau_b)<1e-5),
             initial_10mV_whole_trace_RMS_criterion_pass=bool(np.sqrt(np.mean(diff**2))<.01),
             pointwise_transient_equivalence_claimed=False,
             edge_limitation='Netlist element reordering changes stiff nonlinear edge details. The 50 ps and Gear audits retain differences. Do not claim pointwise transient convergence or exact source Fig6 response.')
    # Preserve the failed original 10 mV whole-trace check as a separate
    # limitation instead of turning it into a passing edge-equivalence claim.
    assert abs(plateau_a-plateau_b)<1e-5,row
    rows.append(row)
(here/'native_ASC_waveform_verification.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print(json.dumps(rows,indent=2))
