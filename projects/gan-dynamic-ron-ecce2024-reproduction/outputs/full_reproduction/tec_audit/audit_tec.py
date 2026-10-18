"""Independent6-state Peltier/PI/sensor ODE audit of nativeSimscape outputs.

No Simulink output waveform is used as a forcing function. Native source
parameters and piecewise setpoints alone define the independent trajectory.
"""
from pathlib import Path
import csv,json,hashlib
import numpy as np
from scipy.integrate import solve_ivp
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'outputs/full_reproduction/tec_audit';OUT.mkdir(parents=True,exist_ok=True)
CODE=ROOT/'outputs/full_reproduction/tec/build_run_tec.m'
NATIVE=ROOT/'outputs/full_reproduction/tec/TEC_Electrothermal_ClosedLoop_results.csv'
native=np.genfromtxt(NATIVE,delimiter=',');assert native.ndim==2 and native.shape[1]==10
t=native[:,0];native=native[:,1:]
assert t[-1]>=2399.99

Vdc=24.;Rtec=.8;alpha=(8.4+.5*Rtec*3.7**2)/(298.15*3.7)
K=(alpha*226.15*3.7-.5*Rtec*3.7**2)/72
C=4.5;Gleak=.02;TB=298.15;Ls=2*220e-6;Rw=2*.03;Rtotal=Rtec+Rw
Ilim=3.;Vlim=3.6;kpT=.25;kiT=.012;awT=.3;kpI=.2;kiI=500.;awI=100.
tauT=.01;tauI=1e-5;targets=[15,55,-15,95];events=[0,600,1200,1800,2400]
parameters=dict(Vdc_V=Vdc,Rtec_Ohm=Rtec,alpha_V_per_K=alpha,K_W_per_K=K,Ccase_J_per_K=C,
 Ginsulation_W_per_K=Gleak,ideal_heatsink_K=TB,Lseries_H=Ls,Rseries_inductors_Ohm=Rw,
 current_reference_limit_A=Ilim,voltage_command_limit_V=Vlim,kpT_A_per_K=kpT,kiT_A_per_Ks=kiT,
 antiwindupT_per_s=awT,kpI_V_per_A=kpI,kiI_V_per_As=kiI,antiwindupI_per_s=awI,
 temp_sensor_tau_s=tauT,current_sensor_tau_s=tauI)
def control(y,ref):
 TA,I,zT,zI,Ts,Is=np.asarray(y)
 errT=Ts-273.15-ref;iraw=kpT*errT+zT;iref=np.clip(iraw,-Ilim,Ilim)
 errI=iref-Is;vraw=Rtotal*iref+alpha*(TB-Ts)+kpI*errI+zI;vcmd=np.clip(vraw,-Vlim,Vlim)
 return iref,vcmd,kiT*errT+awT*(iref-iraw),kiI*errI+awI*(vcmd-vraw)
def rhs(ref):
 def f(t,y):
  TA,I,zT,zI,Ts,Is=y;iref,vcmd,zdT,zdI=control(y,ref)
  # MathWorks defines QA as heatflow INTO Peltier portA. It leaves the
  # attached case mass, so C*TAdot=-QA-Gleak*(TA-TB).
  QA=alpha*TA*I-.5*Rtec*I*I+K*(TA-TB)
  return [(-QA-Gleak*(TA-TB))/C,(vcmd-Rtotal*I-alpha*(TB-TA))/Ls,zdT,zdI,(TA-Ts)/tauT,(I-Is)/tauI]
 return f

y0=np.array([TB,0.,0.,0.,TB,0.]);solutions=[];solverrecords=[]
for j,ref in enumerate(targets):
 sol=solve_ivp(rhs(ref),[events[j],events[j+1]],y0,method='Radau',rtol=2e-9,atol=[1e-9,1e-10,1e-10,1e-10,1e-9,1e-10],max_step=1.,dense_output=True)
 assert sol.success,sol.message
 y0=sol.y[:,-1];solutions.append(sol)
 solverrecords.append(dict(target_C=ref,nfev=sol.nfev,njev=sol.njev,nlu=sol.nlu,solver_points=len(sol.t),success=sol.success))
 # Capture exact independent trajectory, including nativeeventduplicates.
Y=np.empty((6,len(t)));refarr=np.empty(len(t))
for j,ref in enumerate(targets):
 sel=(t>=events[j])&(t<(events[j+1]) if j<3 else t<=events[j+1]);Y[:,sel]=solutions[j].sol(t[sel]);refarr[sel]=ref
iref,vcmd,_,_=control(Y,refarr);ind=np.column_stack((Y[0],Y[1],iref,refarr,vcmd,.5+vcmd/(2*Vdc),.5-vcmd/(2*Vdc),Vdc/2+vcmd/2,Vdc/2-vcmd/2))
signalnames=['Tcase_K','Itec_A','Iref_A','target_C','Vcmd_V','dutyA','dutyB','railA_V','railB_V']
def metr(e):return dict(RMSE=float(np.sqrt(np.mean(e*e))),MAX=float(np.max(abs(e))))
finite=np.all(np.isfinite(ind));assert finite
active=np.ones(len(t),dtype=bool)
for ev in events[1:-1]:active&=abs(t-ev)>1e-6
metrics=dict(source_code=str(CODE),source_code_sha256=hashlib.sha256(CODE.read_bytes()).hexdigest(),
 native_results=str(NATIVE),native_results_sha256=hashlib.sha256(NATIVE.read_bytes()).hexdigest(),
 native_results_mtime_epoch=NATIVE.stat().st_mtime,independent_solver='SciPyRadau,6coupledstates,rtol2e-9',
 ODE_state_order=['TA_K','I_A','outer_PI_A','inner_PI_V','T_sensor_K','I_sensor_A'],
 parameters=parameters,solver_records=solverrecords,all_finite=bool(finite),trajectory_comparison={})
for i,name in enumerate(signalnames):metrics['trajectory_comparison'][name]=dict(all_logged_points=metr(ind[:,i]-native[:,i]),excluding_setpoint_discontinuities=metr((ind[:,i]-native[:,i])[active]))
metrics['controller_limits']=dict(native_current_reference_MAX_A=float(max(abs(native[:,2]))),
 native_actual_current_MAX_A=float(max(abs(native[:,1]))),independent_actual_current_MAX_A=float(max(abs(Y[1]))),
 native_voltage_command_MAX_V=float(max(abs(native[:,4]))),reference_limit_is_not_actual_transient_current_limit=True)

steady=[];energy=[]
for j,ref in enumerate(targets):
 sel=(t>events[j+1]-60)&(t<events[j+1]);TA=float(np.mean(native[sel,0]));I=float(np.mean(native[sel,1]));Vsrc=float(np.mean(native[sel,4]));Ti=float(np.mean(ind[sel,0]));Ii=float(np.mean(ind[sel,1]));
 # Choose quadratic root continuous through zero at target25C.
 analyticI=(alpha*(ref+273.15)-np.sqrt((alpha*(ref+273.15))**2+2*Rtec*(K+Gleak)*(ref+273.15-TB)))/Rtec
 QA=alpha*TA*I-.5*Rtec*I**2+K*(TA-TB)
 QB=-alpha*TB*I-.5*Rtec*I**2+K*(TB-TA)
 Vtec=alpha*(TB-TA)+Rtec*I;Ptec=Vtec*I;Pseries=Rw*I**2;Pleak=Gleak*(TB-TA)
 steady.append(dict(target_C=ref,native_Tcase_C=TA-273.15,independent_Tcase_C=Ti-273.15,native_I_A=I,independent_I_A=Ii,
  analytic_steady_I_A=float(analyticI),native_I_minus_analytic_A=float(I-analyticI),native_Vcmd_V=Vsrc,analytic_Vcmd_V=float(Rtotal*analyticI+alpha*(25-ref)),
  QA_into_Peltier_A_W=float(QA),QB_into_Peltier_B_W=float(QB),Ptec_electrical_W=float(Ptec),Pseries_loss_W=float(Pseries),
  Pheatleak_into_case_W=float(Pleak),case_steady_balance_residual_W=float(-QA+Pleak),Peltier_energy_balance_residual_W=float(Ptec+QA+QB),
  overall_source_power_balance_residual_W=float(Vsrc*I-Ptec-Pseries)))
 # Integrate nativecaseheatflow and compare actual native storedenergychange.
 sel=(t>=events[j])&(t<=events[j+1]);tt=t[sel];T=native[sel,0];ii=native[sel,1];
 qa=alpha*T*ii-.5*Rtec*ii**2+K*(T-TB);net=-qa+Gleak*(TB-T)
 integral=float(np.trapezoid(net,tt));stored=float(C*(T[-1]-T[0]));
 energy.append(dict(target_C=ref,integrated_native_heatflow_J=integral,actual_case_energy_change_J=stored,
  quadrature_residual_J=integral-stored,native_sampling_note='Trapezoid quadrature of adaptively logged nativepoints; includes output-sampling integrationerror.'))
metrics['steady_states']=steady;metrics['native_thermal_energy_integrals']=energy
metrics['assumptions']=[
 'Ideal fixed25C heat sink has unlimited heatacceptance/supply and no thermalmass or ambient rise.',
 'Case5g with900J/kgK is4.5J/K; fixedinsulationconductance0.02W/K is a disclosed representativeassumption, not identified frompaper.',
 'No added DUT average heatload. Fullbridgemeasurementpowers are pulsed and not injected into this separateTECmodel.',
 'Longtime model omits10uF outputcaps after LCsettling; PWMmodel is separate and not validated bythis6stateaudit.',
 'PaperSecIV states achievablecasecapability-15..95C, whileFig12 hasRonmeasurements15..55C; noauthorTECtransienttrajectory is published forindependentmatching.',
 'Temperature/current controllerparameters and sensors are representative implementationassumptions.',
 'Peltier alpha/R/K assume constantcoefficients over-15..95C; actualdevice variation and finiteheatsink limitations remain unverified.'
]
metrics['equation_source']='https://www.mathworks.com/help/simscape-electrical/ref/peltierdevice.html'
(OUT/'TEC_independent_audit_metrics.json').write_text(json.dumps(metrics,indent=2),encoding='utf-8')
with (OUT/'independent_vs_native.csv').open('w',encoding='utf-8',newline='') as f:
 w=csv.writer(f);w.writerow(['time_s']+[n+'_native' for n in signalnames]+[n+'_independent' for n in signalnames]);w.writerows(np.column_stack((t,native,ind)))
with (OUT/'steady_state_energy.csv').open('w',encoding='utf-8',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(steady[0]));w.writeheader();w.writerows(steady)
fig,axs=plt.subplots(3,1,figsize=(11,9),sharex=True,layout='constrained')
for ax,col,unit in zip(axs,[0,1,4],['Case temperature (C)','TEC current (A)','Differential command (V)']):
 a=native[:,col]-(273.15 if col==0 else 0);b=ind[:,col]-(273.15 if col==0 else 0)
 ax.plot(t,a,lw=1.5,label='Native Simscape');ax.plot(t,b,'--',lw=1,label='Independent six state ODE');ax.set_ylabel(unit);ax.grid(alpha=.25);ax.legend(fontsize=9)
axs[0].plot(t,refarr,':',color='k',lw=.7,label='Target');axs[0].legend(fontsize=9);axs[-1].set_xlabel('Time (s)');axs[0].set_title('TEC independent equation audit | same declared assumptions')
fig.savefig(OUT/'TEC_independent_overlay.png',dpi=170);plt.close(fig)
fig,axs=plt.subplots(2,1,figsize=(10,6),sharex=True,layout='constrained')
axs[0].plot(t,ind[:,0]-native[:,0]);axs[0].set(ylabel='Temperature residual (K)',title='Independent versus native numerical residuals');
axs[1].plot(t,ind[:,1]-native[:,1]);axs[1].set(xlabel='Time (s)',ylabel='Current residual (A)')
for ax in axs:ax.grid(alpha=.25)
fig.savefig(OUT/'TEC_independent_residuals.png',dpi=170);plt.close(fig)
print(json.dumps(dict(trajectory=metrics['trajectory_comparison'],steady=steady,limits=metrics['controller_limits'],energy=energy),indent=2))
