"""Finalize all circuit cases; preserve recovery-window failures and large-current cases."""
from pathlib import Path
import json,hashlib,re,zipfile
import numpy as np
from analyze_clamp import read_raw,avg
out=Path(__file__).resolve().parent

def wide_metrics(manifest, destination, must_pass=False):
 cases=[]
 for c in json.loads((out/manifest).read_text(encoding='utf-8')):
  p=out/Path(c['deck']).name;d=read_raw(p.with_suffix('.raw'));t=d['time'];v=d['v(out)'];target=c['on_voltage_V'];error=avg(t,v,1.4e-6,1.8e-6)-target
  mask=(t>=1e-6)&(t<=1.8e-6);bad=np.flatnonzero(mask&(np.abs(v-target)>.02*abs(target)))
  m={**c,'deck':p.name,'window_start_s':1.4e-6,'window_end_s':1.8e-6,'on_mean_V':avg(t,v,1.4e-6,1.8e-6),'window_error_V':error,'steady_error_V':error,'error_note':'finite-pulse measurement window; not infinite-time DC steady state','absolute_peak_V':float(np.max(np.abs(v))),'turn_on_peak_V':float(np.max(np.abs(v[(t>=.95e-6)&(t<=1.8e-6)]))),'off_transition_peak_V':float(np.max(np.abs(v[(t>=1.9e-6)&(t<=2.3e-6)]))),'completed_end_s':float(t[-1]),'input_current_mean_A':avg(t,d['i(vdut)'],1.4e-6,1.8e-6),'input_current_off_mean_A':avg(t,d['i(vdut)'],.8e-6,.95e-6),'peak_input_current_A':float(np.max(np.abs(d['i(vdut)']))),'turn_on_peak_input_current_A':float(np.max(np.abs(d['i(vdut)'][(t>=.95e-6)&(t<=1.8e-6)]))),'off_transition_peak_input_current_A':float(np.max(np.abs(d['i(vdut)'][(t>=1.9e-6)&(t<=2.3e-6)]))),'off_output_mean_V':avg(t,v,.8e-6,.95e-6),'passes_2percent_wide_voltage':abs(error)<.02*abs(target),'last_2percent_violation_after_DUT_edge_ns':float((t[bad[-1]]-1e-6)*1e9) if len(bad) else 0.}
  m['status']='passed finite-window voltage criterion' if m['passes_2percent_wide_voltage'] else 'finite pulse has not recovered within sampled window; long-window/DC diagnosis retained'
  if must_pass:assert m['passes_2percent_wide_voltage'],p.name+' failed safe-sequencing window criterion'
  assert abs(t[-1]-3e-6)<1e-13
  np.savetxt(out/(p.stem+'_waveforms.csv'),np.column_stack([t,d['v(input)'],v,d['i(vdut)']]),delimiter=',',header='time_s,input_V,output_V,input_current_A',comments='',fmt='%.14e')
  cases.append(m)
 (out/destination).write_text(json.dumps(cases,indent=2),encoding='utf-8');return cases

wide=wide_metrics('wide_manifest.json','wide_range_metrics.json')
early=wide_metrics('wide_early_release_manifest.json','wide_early_release_metrics.json')
safe=wide_metrics('wide_safe_manifest.json','wide_safe_metrics.json',must_pass=True)

diag={}
for p in sorted(out.glob('diagnostic*.cir')):
 d=read_raw(p.with_suffix('.raw'));t=d['time'];long='long' in p.stem;dc='_dc' in p.stem
 window=(.065e-6,.085e-6) if dc else ((6e-6,7e-6) if long else (1.4e-6,1.8e-6))
 m={'deck':p.name,'end_time_s':float(t[-1]),'window_s':window,'node_window_means':{k:avg(t,y,*window) for k,y in d.items() if k!='time'}}
 if 'i(vdut)' in d:m['peak_input_current_A']=float(np.max(np.abs(d['i(vdut)'])))
 if 'v(out)' in d:m['absolute_peak_output_V']=float(np.max(np.abs(d['v(out)'])))
 if long or 'strong' in p.stem:
  bad=np.flatnonzero((t>=1e-6)&(t<=(7.8e-6 if long else 1.8e-6))&(np.abs(d['v(out)']+5)>.1));m['last_2percent_violation_after_DUT_edge_ns']=float((t[bad[-1]]-1e-6)*1e9) if len(bad) else 0.
 diag[p.stem]=m
 np.savetxt(out/(p.stem+'_waveforms.csv'),np.column_stack(list(d.values())),delimiter=',',header=','.join(d.keys()),comments='',fmt='%.14e')
(out/'diagnostic_metrics.json').write_text(json.dumps(diag,indent=2),encoding='utf-8')

verification=[]
for p in sorted(out.glob('*.cir')):
 raw=p.with_suffix('.raw');log=p.with_suffix('.log');msg=log.read_text(encoding='utf-8-sig');d=read_raw(raw)
 r={'circuit':p.name,'raw_bytes':raw.stat().st_size,'raw_points':len(d['time']),'raw_end_s':float(d['time'][-1]),'raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'deck_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'log_has_completed_elapsed_time':'Total elapsed time:' in msg,'temperature_C':float(re.search(r'\ntemp = ([\d.]+)',msg).group(1)),'no_fatal_error':not bool(re.search(r'Fatal|Timestep too small|singular matrix',msg,re.I))}
 assert r['log_has_completed_elapsed_time'] and r['no_fatal_error'];verification.append(r)
slx_info=[]
for filename,cases in [('GaN_Fig5_Clamp_Analog_State.slx',4),('GaN_Clamp_Wide_Range_Analog_State.slx',6)]:
 slx=out/filename
 with zipfile.ZipFile(slx) as z:assert 'simulink/blockdiagram.xml' in z.namelist()
 slx_info.append({'native_file':filename,'actually_simulated_cases':cases,'self_contained_model_workspace':True,'sha256':hashlib.sha256(slx.read_bytes()).hexdigest(),'diagram_visually_checked':True})
schema={'native_circuit_cases':len(verification),'native_simulink_cases':10,'native_simulink_models':slx_info,'native_models_diagram_visually_checked':True,'main_figures_visually_checked':['clamp_ltspice_comparison.png','clamp_simulink.png','fig6_source_digitized.png','noise_range_budget.png','wide_range_original_models.png','wide_clamp_simulink.png'],'spice_verification':verification,'published_numerical_values_are_reference_only':True,'wide_original_model_window_passes':sum(m['passes_2percent_wide_voltage'] for m in wide),'wide_original_model_cases':len(wide),'wide_early_release_window_passes':sum(m['passes_2percent_wide_voltage'] for m in early),'wide_safe_interlock_window_passes':sum(m['passes_2percent_wide_voltage'] for m in safe)}
(out/'verification.json').write_text(json.dumps(schema,indent=2),encoding='utf-8')
index={'paper_figures':[5,6],'completed_scope':'public clamp topology, explicit representative parts, physical nonlinear waveforms, gate-drive/recovery/interlock sensitivity, signed range, ADC budget and source digitization','LTspice_cases':len(verification),'Simulink_cases':10,'results':{'nonlinear_circuits':'clamp_metrics.json','wide_original_window_failures':'wide_range_metrics.json','wide_early_release':'wide_early_release_metrics.json','wide_safe_interlock':'wide_safe_metrics.json','isolated_DC_and_long_recovery':'diagnostic_metrics.json','Simulink_analog_state':'clamp_simulink_metrics.json','Simulink_wide_analog_state':'wide_clamp_simulink_metrics.json','measurement_range_budget':'noise_range_budget.json','digitized_original_reference':'fig6_digitization.json','native_schematic_structural_equivalence':'native_schematic_equivalence.json'},'model_card':'MODEL_CARD.md','source_provenance':'sources/source_manifest.json','verification':'verification.json','source_fig6_original_response_ns':[275,160,120],'source_fig6_original_sigmaRon_uOhm':[90.3,525.4,695.],'no_exact_noise_reproduction_claim':True,'no_exact_275ns_fitting':True,'wide_original_window_results_include_failures':True,'circuit_loading_boundary':'forced DUT voltage input quantifies loading current; it does not prove perturbation of a coupled real DUT is negligible','source_missing_items':['author clamp BOM and gate driver/timing','author PCB parasitics and probe overload response','actual voltage scales and unspecified noise filter/raw samples']}
(out/'metrics.json').write_text(json.dumps(index,indent=2),encoding='utf-8')
print(json.dumps({'native_circuit_cases':len(verification),'wide_safe':safe,'index':index},indent=2))
