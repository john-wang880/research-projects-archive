"""Read native LTspice ASCII RAW files; keep all mechanism and source metrics auditable."""
from pathlib import Path
import numpy as np
import json,re
OUT=Path(__file__).resolve().parent
def read_raw(path):
 raw=path.read_bytes();encoding='utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig';txt=raw.decode(encoding)
 header,body=txt.split('Values:\n',1) if 'Values:\n' in txt else txt.split('Values:\r\n',1)
 nv=int(re.search(r'No\. Variables:\s*(\d+)',header).group(1));n=int(re.search(r'No\. Points:\s*(\d+)',header).group(1))
 names=[line.split()[1].lower() for line in header.rsplit('Variables:',1)[1].strip().splitlines()]
 lines=body.strip().splitlines();assert len(lines)==n*nv,'incomplete raw'
 a=np.array([float(s.split()[-1]) for s in lines]).reshape(n,nv);return dict(zip(names,a.T))
def avg(t,y,start,end):
 tx=np.r_[start,t[(t>start)&(t<end)],end];yx=np.interp(tx,t,y);return float(np.trapezoid(yx,tx)/(end-start))
def main():
 metrics={}
 names=['improved_positive','blocking_positive','improved_negative','blocking_negative','improved_strong_drive_positive','improved_strong_drive_negative','improved_slow_release_positive','improved_slow_release_negative','current_mirror_reduced']
 for name in names:
  d=read_raw(OUT/(name+'.raw'));
  if 'i(vdut)' not in d:d['i(vdut)']=d['i(da)']
  t=d['time'];v=d['v(out)'];vin=d['v(input)'];target=-.48 if 'negative' in name else .48
  reg=np.arange(0,3e-6+1e-10,1e-10);rv=np.interp(reg,t,v);event=(reg>=.95e-6)&(reg<=1.8e-6);full=(reg>=.8e-6)&(reg<=2.4e-6)
  invalid=(reg>=1e-6)&(reg<=1.8e-6)&(np.abs(rv-target)>abs(target)*.02)
  last=np.flatnonzero(invalid);settle=0 if not len(last) else float((reg[last[-1]]-1e-6)*1e9)
  metrics[name]={'engine':'LTspice 24.0.12','raw_points':len(t),'end_time_s':float(t[-1]),'turn_on_output_min_V':float(rv[event].min()),'turn_on_output_max_V':float(rv[event].max()),'full_interval_absolute_peak_V':float(np.abs(rv[full]).max()),'on_plateau_V':avg(t,v,1.4e-6,1.8e-6),'input_current_mean_A':avg(t,d['i(vdut)'],1.4e-6,1.8e-6),'peak_input_current_A':float(np.max(np.abs(d['i(vdut)']))),'target_on_voltage_V':target,'steady_error_uV':1e6*(avg(t,v,1.4e-6,1.8e-6)-target),'last_2percent_violation_after_DUT_edge_ns':settle,'off_plateau_V':avg(t,v,.8e-6,.95e-6),'range_note':'actual oscilloscope fullscale not known; peak here is representative circuit simulation'}
  if name!='current_mirror_reduced':
   metrics[name]['max_TVS_current_A']=float(max(np.max(np.abs(d['i(dtvsp)'])),np.max(np.abs(d['i(dtvsm)']))))
   metrics[name]['BTB_gate_setting']='10 V / 2 Ohm' if 'strong' in name else ('4.5 V / 300 Ohm' if 'slow' in name else ('4.5 V / 20 Ohm' if 'improved' in name else 'OFF'))
  else:metrics[name]['current_mirror']='ideal matched 60 mA output ports; original 2024 cascode BOM unavailable'
  cols=[t,vin,v];headers=['time_s','input_V','output_V']
  if 'v(gate_block)' in d:d['v(gate_block,out)']=d['v(gate_block)']-v
  if 'v(gate_top)' in d and 'v(middle)' in d:d['v(gate_top,middle)']=d['v(gate_top)']-d['v(middle)']
  for key,label in [('v(gate_block,out)','blocking_gate_V'),('v(gate_top,middle)','BTB_gate_V'),('i(dtvsp)','TVS_pos_A'),('i(dtvsm)','TVS_neg_A')]:
   if key in d:cols.append(d[key]);headers.append(label)
  np.savetxt(OUT/(name+'_waveforms.csv'),np.column_stack(cols),delimiter=',',header=','.join(headers),comments='',fmt='%.14e')
  assert abs(t[-1]-3e-6)<1e-13,'transient not completed'
  assert abs(metrics[name]['steady_error_uV'])<(500 if 'slow' in name else 100),'steady measurement offset unexpectedly high'
 assert metrics['improved_positive']['full_interval_absolute_peak_V']<metrics['blocking_positive']['full_interval_absolute_peak_V'],'BTB did not reduce range'
 assert metrics['improved_strong_drive_positive']['full_interval_absolute_peak_V']<metrics['improved_positive']['full_interval_absolute_peak_V'],'strong drive did not improve range'
 summary={'cases':metrics,'source_response_ns':{'improved':275,'blocking':160,'current_mirror':120},'source_sigma_Ron_uOhm':{'improved':90.3,'blocking':525.4,'current_mirror':695.0},'unreproduced_exact_measurements':['author BOM and PCB parasitics','specific gate timing and filter/noise chain','exact 275 / 160 / 120 ns and sigmaRon values'],'pass_claim':'nonlinear circuit mechanism, signed steady measurement, shorting range reduction, gate drive sensitivity'}
 (OUT/'clamp_metrics.json').write_text(json.dumps(summary,indent=2),encoding='utf-8');print(json.dumps(summary,indent=2))

if __name__ == "__main__":
 main()
