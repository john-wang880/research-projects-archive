from pathlib import Path
import json,sys,subprocess,hashlib,time
import numpy as np
root=Path(__file__).resolve().parents[1];clamp=root/'outputs/full_reproduction/clamp'
sys.path.insert(0,str(clamp));from analyze_clamp import read_raw,avg
mode='gear' if '--gear' in sys.argv else 'fine'
out=clamp/'native_validation';out.mkdir(exist_ok=True)
si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
results=[]
for item in json.loads((clamp/'native_schematic_manifest.json').read_text()):
    traces=[];runs=[]
    for label,path in [('asc',clamp/Path(item['native_schematic']).with_suffix('.net')),('cir',clamp/item['equivalent_verified_deck'])]:
        txt=path.read_text().replace('.include models/','.include ../models/')
        txt=txt.replace('.tran 0 3u 0 0.2n','.tran 0 3u 0 0.05n').replace('reltol=1e-5 abstol=1e-10','reltol=1e-6 abstol=1e-11')
        if mode=='gear':txt=txt.replace('.options plotwinsize=0 reltol=1e-6 abstol=1e-11','.options plotwinsize=0 reltol=1e-7 abstol=1e-12 method=gear trtol=1')
        # .lib standard.dio adds only an unused default diode model.
        txt='\n'.join(line for line in txt.splitlines() if not line.startswith('.lib '))+'\n'
        deck=out/(path.stem+'_'+label+'_'+mode+'.cir');deck.write_text(txt)
        start=time.time();p=subprocess.Popen([r'D:\LTspice\LTspice.exe','-ascii','-b',str(deck)],cwd=out,startupinfo=si)
        try:code=p.wait(timeout=90)
        except subprocess.TimeoutExpired:p.terminate();p.wait(timeout=10);raise
        assert code==0
        trace=read_raw(deck.with_suffix('.raw'));assert abs(trace['time'][-1]-3e-6)<1e-13
        traces.append(trace);runs.append(dict(deck=deck.name,pid=p.pid,exit_code=code,elapsed_s=time.time()-start,raw_sha256=hashlib.sha256(deck.with_suffix('.raw').read_bytes()).hexdigest()))
    a,b=traces;t=np.linspace(0,3e-6,150001)
    diff=np.interp(t,a['time'],a['v(out)'])-np.interp(t,b['time'],b['v(out)'])
    row=dict(schematic=item['native_schematic'],fine_max_step_s=5e-11,fine_reltol=1e-7 if mode=='gear' else 1e-6,method=mode,runs=runs,
        maximum_difference_V=float(max(abs(diff))),RMS_difference_V=float(np.sqrt(np.mean(diff**2))),
        max_difference_time_s=float(t[np.argmax(abs(diff))]),plateau_difference_V=avg(a['time'],a['v(out)'],1.4e-6,1.8e-6)-avg(b['time'],b['v(out)'],1.4e-6,1.8e-6))
    results.append(row);print(json.dumps(row),flush=True)
(out/('gear_convergence.json' if mode=='gear' else 'convergence.json')).write_text(json.dumps(results,indent=2))
