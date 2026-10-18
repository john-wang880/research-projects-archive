"""Independent SciPy numerical check of the published Cauer ladder."""
from pathlib import Path
import json
import numpy as np

out=Path(__file__).resolve().parent
R=np.array([.015,.23,.24,.015])
C=np.array([8e-5,7.4e-4,6.5e-3,2e-3])
A=np.zeros((4,4))
for i in range(4):
    A[i,i]-=1/R[i]/C[i]
    if i<3:A[i,i+1]+=1/R[i]/C[i]
    if i>0:
        A[i,i]-=1/R[i-1]/C[i]
        A[i,i-1]+=1/R[i-1]/C[i]
b=np.array([1/C[0],0,0,0])
def run_case(label, step):
    state=np.zeros(4);saved_t=[0.];saved_y=[0.]
    for start,end in [(0,32.5e-6),(32.5e-6,33.5e-6),(33.5e-6,38.5e-6)]:
        if start==0:
            power=(lambda t: .08*(50*t/32.5e-6)**2) if label=='conventional' else (lambda t:0)
        elif start==32.5e-6:power=lambda t:0
        else:power=lambda t:200
        N=int(round((end-start)/step));h=(end-start)/N
        for i in range(N):
            t=start+i*h
            k1=A@state+b*power(t)
            k2=A@(state+h*k1/2)+b*power(t+h/2)
            k3=A@(state+h*k2/2)+b*power(t+h/2)
            k4=A@(state+h*k3)+b*power(t+h)
            state+=h*(k1+2*k2+2*k3+k4)/6
            saved_t.append(t+h);saved_y.append(state[0])
    return np.array(saved_t),np.array(saved_y)
cases={}
for label in ['conventional','proposed']:
    times,y=run_case(label,1e-9)
    t=np.linspace(33.5e-6,38.5e-6,10001)
    pred=np.interp(t,times,y)
    t2,y2=run_case(label,2e-9)
    pred2=np.interp(t,t2,y2)
    native=np.genfromtxt(out/f'figure14_temperature_{label}_native.csv',delimiter=',',names=True)
    ref=np.interp(t*1e6,native['time_us'],native['plotted_value_K'])
    cases[label]={
        'mean_33p5_to_38p5_us_K':float(np.trapezoid(pred,t)/(5e-6)),
        'peak_38p5_us_K':float(pred[-1]),
        'vs_native_pdf_curve_rmse_K':float(np.sqrt(np.mean((pred-ref)**2))),
        'vs_native_pdf_curve_max_abs_K':float(np.max(abs(pred-ref))),
        'timestep_1ns_vs_2ns_max_abs_K':float(np.max(abs(pred-pred2))),
    }
    np.savetxt(out/f'independent_thermal_{label}.csv',np.column_stack((times*1e6,y)),delimiter=',',header='time_us,junction_temperature_rise_K',comments='')
result={'method':'Independent NumPy RK4 with exact discontinuity boundaries;1ns vs2ns convergence check',
        'R_K_per_W':R.tolist(),'C_J_per_K':C.tolist(),
        'initial_temperature_rise_K':[0,0,0,0],'case_temperature_fixed':True,
        'Ron_ohm':.08,'ramp_peak_A':50,
        'cases':cases,
        'mean_reduction_percent':100*(1-cases['proposed']['mean_33p5_to_38p5_us_K']/cases['conventional']['mean_33p5_to_38p5_us_K'])}
(out/'independent_thermal_check.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
