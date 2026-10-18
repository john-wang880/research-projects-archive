#setdep @node|sdevice@
from pathlib import Path
import re,json,math
d=int(@HoleD_um@);node=int(@node|sdevice@);p=Path('@nodedir@')
def readplt(path):
 s=path.read_text();names=re.findall(r'"([^"]+)"',re.search(r'datasets\s*=\s*\[(.*?)\]',s,re.S).group(1));vals=list(map(float,re.findall(r'[-+]?(?:\d*\.\d+|\d+)(?:[Ee][-+]?\d+)?',s.split('Data {',1)[1])));assert len(vals)%len(names)==0
 return [dict(zip(names,vals[i:i+len(names)])) for i in range(0,len(vals),len(names))]
rows=readplt(p/f'pulse_n{node}_circuit.plt');out=(p/f'n{node}_des.out').read_text(errors='replace')
assert 'Good Bye !' in out[-2000:] and 'Exit due to failure' not in out
assert abs(rows[-1]['time']-4e-8)<1e-16 and all(math.isfinite(v) for row in rows for v in row.values())
t=[r['time'] for r in rows];y=[r['v(meas)'] for r in rows];k=max(range(len(y)),key=lambda k:y[k]);peak=y[k]
assert peak>1e-6, 'No meaningful native optical voltage'
pd=readplt(p/f'pulse_pd_n{node}_des.plt')
assert max(r['IntegrSemiconductor OpticalGeneration'] for r in pd)>0, 'No native optical generation'
assert max(r['TimeDependence(Ft) OpticalGeneration'] for r in pd)>.98, 'Input pulse not resolved'
assert abs(pd[0]['RaytracePower Input']/(.093943727869871*float(@Energy_pJ@))-1)<1e-6
def cross(level,start,end,up):
 for j in range(start,end):
  a,b=y[j:j+2]
  if (a<=level<=b if up else b<=level<=a) and a!=b:return t[j]+(t[j+1]-t[j])*(level-a)/(b-a)
 raise ValueError('missing rise/fall crossing')
a=cross(peak*.1,0,k,True);b=cross(peak*.9,0,k,True);c=cross(peak*.9,k,len(y)-1,False);e=cross(peak*.1,k,len(y)-1,False)
metrics={'Tr_ns':(b-a)*1e9,'Tf_ns':(e-c)*1e9,'Total_ns':(b-a+e-c)*1e9,'Peak_mV':peak*1e3,'FinalTime_s':t[-1]}
for name,value in metrics.items():print(f'DOE: {name} {value:.14g}')
(p/f'n{int(@node@)}_metrics.json').write_text(json.dumps(dict(diameter_um=d,sdevice_node=node,metrics=metrics),indent=2))
