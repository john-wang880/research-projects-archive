from scw.apps.scwcal import SCWCal
from scw.core.parameter import Parameter
from scw.core.target import Target
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
cal=SCWCal()
initial={'R0_ohm': 577.77939, 'R4_ohm': 291.03302, 'R8_ohm': 587.09776, 'Energy_pJ': 104.67988}
parameters=[Parameter(name=name,value=value,minimum=10 if name!='Energy_pJ' else 1,maximum=3000 if name!='Energy_pJ' else 300,transform=Log10) for name,value in initial.items()]
targets=[Target(name='Total_ns',id='total_D0',value=5.4,conditions={'HoleD_um':'0'}),
 Target(name='Total_ns',id='total_D4',value=2.2,conditions={'HoleD_um':'4'}),
 Target(name='Total_ns',id='total_D8',value=2.9,conditions={'HoleD_um':'8'}),
 Target(name='Peak_mV',id='peak_D4',value=330,conditions={'HoleD_um':'4'},weight=.25)]
cal.set_option(parent=str(HERE.parent/'parent'),tools=['sdevice','extract'],child_dir=str(HERE.parent/'child_local'),files_to_copy=['sdevice.par','sic_uv_nk.txt'],num_threads=3,preprocess_new_project=True)
cal.evaluate(parameters=parameters,targets=targets)
cal.set_backend_control(target_tolerance=.025,initdx=.015)
cal.optimize(parameters=parameters,targets=targets,max_iteration=24)
result={p.name:p.value for p in parameters}
Path('scw_best_parameters.json').write_text(json.dumps(result,indent=2))
print('SCW_NATIVE_BEST_PARAMETERS',json.dumps(result))
