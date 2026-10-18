from pathlib import Path
import json
import numpy as np

root=Path(__file__).resolve().parent
out=root/'ltspice'
result={}
for case in ['conventional','proposed']:
    p=out/(case+'.raw')
    raw=p.read_bytes()
    txt=raw.decode('utf-16') if raw[:2] in [b'\xff\xfe',b'\xfe\xff'] or b'\x00' in raw[:40] else raw.decode('utf-8')
    txt=txt.replace('\r\n','\n')
    hdr, vals=txt.split('Values:\n',1)
    n=int(hdr.split('No. Variables:')[1].splitlines()[0])
    var=[s.split()[1] for s in hdr.split('Variables:\n',1)[1].splitlines() if s.strip()]
    rows=[]
    for block in vals.strip().splitlines():
        s=block.split()
        if len(s)==2:
            rows.append([float(s[1])])
        else:
            rows[-1].append(float(s[0]))
    arr=np.asarray(rows); assert arr.shape[1]==n
    d={v.lower():arr[:,k] for k,v in enumerate(var)}
    t=d['time']; i=d['i(vdut)']; il=d['i(lload)']
    gates={g:d['v(g_'+g+')']>3 for g in ['hs1','hs2','dut','ls1','ls2']}
    q={}
    for name, a,b in [('charge',2.1e-6,34.4e-6),('measure',35.6e-6,40.4e-6)]:
        k=(t>=a)&(t<=b)
        q[name]={'mean_idut_A':float(np.trapezoid(i[k],t[k])/(t[k][-1]-t[k][0])),
                 'mean_iload_A':float(np.trapezoid(il[k],t[k])/(t[k][-1]-t[k][0])),
                 'mean_ls1_A':float(np.trapezoid(d['i(s_ls1)'][k],t[k])/(t[k][-1]-t[k][0])),
                 'max_abs_idut_minus_iload_A':float(np.max(abs(i[k]-il[k])))}
    q['left_bridge_crossconduction_points']=int(np.count_nonzero(gates['hs1']&(gates['dut']|gates['ls1'])))
    q['right_bridge_crossconduction_points']=int(np.count_nonzero(gates['hs2']&gates['ls2']))
    q['measurement_actual_on_start_s']=float(t[np.flatnonzero(gates['dut']&(t>35e-6))[0]])
    q['measurement_actual_on_end_s']=float(t[np.flatnonzero(gates['dut']&(t>35e-6))[-1]])
    q['max_idut_A']=float(i.max()); q['min_idut_A']=float(i.min())
    q['total_i2ron_energy_J']=float(np.trapezoid(i*i*0.08,t))
    # S_DUT current equals I(VDUT): Coss and reverse diode attach after VDUT and bypass sensor.
    # During S_DUT on, V(left)-V(source_dut)=I(VDUT)*Ron exactly for this model.
    k=gates['dut']
    q['max_on_ohmic_equation_error_V']=float(np.max(abs(d['v(left)'][k]-d['v(source_dut)'][k]-0.08*i[k])))
    ig=il.astype(float)*gates['dut']
    q['gated_inductor_i2ron_energy_J']=float(np.trapezoid(ig*ig*0.08,t))
    q['energy_difference_vs_gated_inductor_percent']=float(100*(q['total_i2ron_energy_J']/q['gated_inductor_i2ron_energy_J']-1))
    result[case]=q
    assert q['left_bridge_crossconduction_points']==0
    assert q['right_bridge_crossconduction_points']==0
    assert q['measure']['max_abs_idut_minus_iload_A']<1e-5
    assert abs(q['measure']['mean_ls1_A'])<1e-6
    assert q['max_on_ohmic_equation_error_V']<1e-5
    if case=='proposed':assert abs(q['charge']['mean_idut_A'])<1e-6
(root/'data'/'independent_circuit_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))

