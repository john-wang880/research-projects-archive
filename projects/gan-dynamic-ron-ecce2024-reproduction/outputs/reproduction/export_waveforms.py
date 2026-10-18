"""Convert LTspice ASCII RAW output to auditable CSV and current-path metrics."""
from pathlib import Path
import json, re
import numpy as np

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'data'; OUT.mkdir(exist_ok=True)

def read_ascii_raw(path):
    raw=path.read_bytes()
    encoding='utf-16' if raw[:2] in [b'\xff\xfe',b'\xfe\xff'] else 'utf-8-sig'
    text=raw.decode(encoding)
    before,values=text.split('Values:\n',1) if 'Values:\n' in text else text.split('Values:\r\n',1)
    nv=int(re.search(r'No\. Variables:\s*(\d+)',before).group(1))
    npnt=int(re.search(r'No\. Points:\s*(\d+)',before).group(1))
    names=[line.split()[1] for line in before.rsplit('Variables:',1)[1].strip().splitlines()]
    lines=values.strip().splitlines()
    if len(lines)!=nv*npnt: raise ValueError('Incomplete ASCII RAW file')
    a=np.asarray([float(line.split()[-1]) for line in lines]).reshape(npnt,nv)
    return {name.lower():a[:,i] for i,name in enumerate(names)}

def interval(t,y,start,end):
    if start<t[0] or end>t[-1]:raise ValueError('Interval not covered')
    inside=(t>start)&(t<end)
    ti=np.r_[start,t[inside],end]
    yi=np.r_[np.interp(start,t,y),y[inside],np.interp(end,t,y)]
    return ti,yi

def mean(t,y,start,end):
    ti,yi=interval(t,y,start,end)
    return float(np.trapezoid(yi,ti)/(end-start))

params=json.loads((ROOT/'ltspice'/'parameters.json').read_text())
metrics={}
for kind in ['conventional','proposed']:
    d=read_ascii_raw(ROOT/'ltspice'/(kind+'.raw'))
    t=d['time']; idut=d['i(vdut)']; il=d['i(lload)']
    # LTspice switch current has opposite reference to our drain-to-source direction.
    il1=-d['i(s_ls1)']; il2=-d['i(s_ls2)']
    vds=d['v(left)']-d['v(source_dut)']
    terminal=d['v(source_dut)']/params['shunt_ohm']
    load_conduction=np.where(d['v(g_dut)']>3,il,0.)
    columns=['time_s','dut_current_A','inductor_current_A','ls1_current_A','ls2_current_A','dut_vds_V','dc_bus_V','gate_dut_V','dut_terminal_current_A','dut_load_conduction_A']
    a=np.column_stack([t,idut,il,il1,il2,vds,d['v(bus)'],d['v(g_dut)'],terminal,load_conduction])
    np.savetxt(OUT/(kind+'_waveforms.csv'),a,delimiter=',',header=','.join(columns),comments='',fmt='%.14e')
    np.savetxt(OUT/(kind+'_conduction.csv'),np.column_stack([t,load_conduction]),delimiter=',',header='time_s,dut_current_A',comments='',fmt='%.14e')
    ts=params['charge_start_s'];tc=params['charge_end_s'];ms=params['measure_start_s'];me=params['measure_end_s']
    charge=(t>ts+100e-9)&(t<tc-100e-9)
    measurement=(t>ms+100e-9)&(t<me-100e-9)
    # Closed-form circuit reference ignores all resistance, capacitance sag and deadtime.
    ideal=params['vdc_V']*(tc-ts)/params['load_H']
    model_ron=np.divide(vds,idut,out=np.full_like(vds,np.nan),where=np.abs(idut)>1)
    # S-channel alone is used as a thermal input. Its constant-Coss switching pulse is model dependent.
    metrics[kind]={
        'end_s':float(t[-1]),'samples':len(t),'inductor_charge_peak_A':float(il[charge].max()),
        'ideal_charge_peak_A':ideal,'peak_difference_from_lossless_percent':float(100*(il[charge].max()/ideal-1)),
        'dut_charge_rms_A':float(np.sqrt(mean(t,idut**2,ts+100e-9,tc-100e-9))),
        'dut_measure_mean_A':mean(t,idut,ms,me),'ls1_measure_max_abs_A':float(np.abs(il1[measurement]).max()),
        'dut_on_Ron_ohm_interior_mean':float(np.nanmean(model_ron[measurement])),
        'dut_on_Ron_ohm_interior_max_error':float(np.nanmax(np.abs(model_ron[measurement]-params['dut_Ron_ohm']))),
        'dut_channel_global_max_A':float(idut.max()),
        'charge_conduction_energy_J':mean(t,idut**2*0.08,ts,tc)*(tc-ts),
        'measure_conduction_energy_J':mean(t,idut**2*0.08,ms,me)*(me-ms),
        'bus_at_charge_end_V':float(np.interp(tc,t,d['v(bus)']))
    }
    metrics[kind]['nominal_total_channel_energy_J']=mean(t,idut**2*0.08,ts,me)*(me-ts)
    metrics[kind]['nominal_total_load_conduction_energy_J']=mean(t,load_conduction**2*0.08,ts,me)*(me-ts)
    metrics[kind]['extra_channel_energy_percent']=100*(metrics[kind]['nominal_total_channel_energy_J']/metrics[kind]['nominal_total_load_conduction_energy_J']-1)
    metrics[kind]['measured_gate_on_duration_s']=mean(t,(d['v(g_dut)']>3).astype(float),ms,me)*(me-ms)
    # Required current-path assertions. They compare distinct physical branch observables.
    if kind=='proposed':
        assert metrics[kind]['dut_charge_rms_A']<1e-6,'DUT conducts during proposed charging'
        assert metrics[kind]['ls1_measure_max_abs_A']<1e-6,'LS1 diverts measurement current'
    assert metrics[kind]['dut_on_Ron_ohm_interior_max_error']<1e-7,'Probe/Ron extraction mismatch'
assert abs(metrics['conventional']['dut_measure_mean_A']/metrics['proposed']['dut_measure_mean_A']-1)<0.02,'Test currents not comparable'
(OUT/'circuit_metrics.json').write_text(json.dumps(metrics,indent=2),encoding='ascii')
print(json.dumps(metrics,indent=2))
