"""Audit/reconstruct public plotted curves; never claims independent physics.

Coordinates are taken from native PDF vector paths. Fits use only separated
training points; intervening plotted points are retained as validation data.
"""
from pathlib import Path
import csv, json, hashlib, sys
import numpy as np
import pdfplumber
from scipy.optimize import least_squares
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else ROOT/'outputs/full_reproduction/ron_trapping'
OUT.mkdir(parents=True,exist_ok=True)
SOURCE=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT/'outputs/ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf'
pdf=pdfplumber.open(SOURCE)
specs={
 'fig10':dict(page=6,indices=list(range(9)),conditions=list(range(95,14,-10)),
  condition_name='Tc_C',x_name='Id_A',x0=183.7659839,xscale=(202.3999781-183.7659839)/10,
  y0=620.04016,yscale=(620.04016-604.26538)/5,y_offset=40,
  axis_evidence='I=0 at x183.7659839; I=10 at202.3999781; R=40 at top620.04016; R=45 at604.26538'),
 'fig11':dict(page=6,indices=list(range(19,27)),conditions=list(range(50,401,50)),
  condition_name='Vds_V',x_name='time_min',x0=402.22425334833,xscale=(439.05700897944-402.22425334833)/10,
  y0=427.74876314667,yscale=(427.74876314667-403.98731267333)/5,y_offset=50,
  stress_off_min=13.5833333333,vertical_annotation_min=13.5833333333,
  axis_evidence='t=0 at402.22425334833; t=10 at439.05700897944; R=50 at427.74876314667; R=55 at403.98731267333'),
 'fig12':dict(page=7,indices=list(range(5)),conditions=list(range(55,14,-10)),
  condition_name='Tc_C',x_name='time_min',x0=138.980466585,xscale=(175.166853135-138.980466585)/10,
  y0=204.8258865975,yscale=(204.8258865975-189.4431779075)/5,y_offset=45,
  stress_off_min=13.75,vertical_annotation_min=14.0,
  axis_evidence='t=0 at138.980466585; t=10 at175.166853135; R=45 at204.8258865975; R=50 at189.4431779075')}

def metrics(y,p):
 e=np.asarray(p)-y
 return dict(n=int(len(y)),rmse_mOhm=float(np.sqrt(np.mean(e*e))),max_abs_mOhm=float(np.max(abs(e))),mae_mOhm=float(np.mean(abs(e))))

def savecsv(path,header,rows):
 with path.open('w',encoding='utf-8',newline='') as f:
  w=csv.writer(f);w.writerow(header);w.writerows(rows)

datasets={};meta=dict(source=str(SOURCE),sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 method='Native PDF vector-path vertices calibrated to printed axis grid; plotted data, not unpublished raw measurements',figures={})
for name,s in specs.items():
 curves=[];ms=[]
 for ix,cond in zip(s['indices'],s['conditions']):
  c=pdf.pages[s['page']-1].curves[ix]
  assert set(o[0] for o in c['path'])<={'m','l'},'Unexpected Bezier path'
  xy=np.array([o[1] for o in c['path']]);data=np.column_stack(((xy[:,0]-s['x0'])/s['xscale'],s['y_offset']+(s['y0']-xy[:,1])/s['yscale']))
  order=np.argsort(data[:,0],kind='stable');data=data[order];xy=xy[order]
  curves.append(dict(condition=cond,data=data,xy=xy))
  savecsv(OUT/f'{name}_{s["condition_name"]}_{cond}_native.csv',[s['x_name'],'Ron_mOhm','pdf_x_pt','pdf_top_pt'],np.column_stack((data,xy)))
  ms.append(dict(condition=cond,pdf_curve_index=ix,vertices=len(data),range=[float(data[0,0]),float(data[-1,0])],
   stroke_width_pt=c['linewidth'],half_stroke_x_units=c['linewidth']/2/s['xscale'],half_stroke_mOhm=c['linewidth']/2/s['yscale'],color_rgb=c['stroking_color']))
 datasets[name]=curves
 meta['figures'][name]={k:v for k,v in s.items() if k!='indices'};meta['figures'][name]['curves']=ms
meta['source_inconsistencies']=[
 'Fig10 sectionVI-B says VDC150V, but plot annotation says Vds,IDLE100V; these are retained as conflicting source statements.',
 'Prose stress release13min; Fig11 paths approximately13.57..13.75min and line13.5833min; Fig12 paths13.75..13.95min and vertical annotation14min. Native percurve sampling alignment is explicit; nominal13min timing tested separately.',
 'Fig11 150V curve and Fig12 25C curve are the same public vector series after coordinate calibration, a useful independent axis/mapping crosscheck.'
]
(OUT/'coordinate_provenance.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')

# Static resistance: temperature/current polynomial with condition holdout.
static=datasets['fig10'];trainT=[15,35,55,75,95];testT=[25,45,65,85]
def features(I,T,di,dt=2):
 x=np.asarray(I)/50;z=(np.asarray(T)-55)/40
 return np.column_stack([x**i*z**j for j in range(dt+1) for i in range(di+1)])
train=[];pointhold=[];temphold=[]
for c in static:
 d=c['data'];i=np.arange(len(d));rows=np.column_stack((d,np.full(len(d),c['condition'])))
 if c['condition'] in trainT:
  train.extend(rows[i%3!=1]);pointhold.extend(rows[i%3==1])
 else:temphold.extend(rows)
train=np.array(train);pointhold=np.array(pointhold);temphold=np.array(temphold)
static_candidates=[]
for di in [2,3,4,5]:
 coef=np.linalg.lstsq(features(train[:,0],train[:,2],di),train[:,1],rcond=None)[0]
 score=metrics(pointhold[:,1],features(pointhold[:,0],pointhold[:,2],di)@coef)
 static_candidates.append((di,coef,score))
bestscore=min(q[2]['rmse_mOhm'] for q in static_candidates)
best=next(q for q in static_candidates if q[2]['rmse_mOhm']<=bestscore+.03);di,coef,_=best
staticModel=dict(current_degree=di,temperature_degree=2,coefficient_order='outer j=temperaturePower0..2; inner i=currentPower0..degree',
 normalization=dict(current='Id/50',temperature='(Tc-55)/40'),coefficients_mOhm=coef.tolist(),
 training_temperatures_C=trainT,held_out_temperatures_C=testT,candidates=[dict(current_degree=q[0],point_holdout=q[2]) for q in static_candidates],
 training=metrics(train[:,1],features(train[:,0],train[:,2],di)@coef),
 point_holdout=metrics(pointhold[:,1],features(pointhold[:,0],pointhold[:,2],di)@coef),
 whole_temperature_holdout=metrics(temphold[:,1],features(temphold[:,0],temphold[:,2],di)@coef),
 domain='Tc15..95C; Id approx-50..50A; Fig10 lower freewheel protocol and Vgs6V; not extrapolated to arbitrary Vgs or trap state')
allpred=[]
fig,ax=plt.subplots(figsize=(9,6),layout='constrained')
for c in static:
 d=c['data'];color=plt.cm.viridis((c['condition']-15)/80)
 pred=features(d[:,0],np.full(len(d),c['condition']),di)@coef
 label=f'{c["condition"]} C'+(' (condition holdout)' if c['condition'] in testT else '')
 ax.plot(d[:,0],d[:,1],'.',color=color,ms=3);ax.plot(d[:,0],pred,color=color,label=label)
 for i,((cur,R),P) in enumerate(zip(d,pred)):
  role='whole_temperature_holdout' if c['condition'] in testT else ('point_holdout' if i%3==1 else 'calibration')
  allpred.append([c['condition'],cur,R,P,role])
ax.set(xlabel='Signed drain current (A)',ylabel='Plotted on-resistance (mOhm)',title='Fig10 public-curve reconstruction | polynomial behavior model');ax.grid(alpha=.25);ax.legend(fontsize=8,ncol=2)
fig.savefig(OUT/'Fig10_static_resistance.png',dpi=180);plt.close(fig)
savecsv(OUT/'fig10_model_comparison.csv',['Tc_C','Id_A','plotted_Ron_mOhm','model_Ron_mOhm','validation_role'],allpred)

# Capture/release exponentials fitted independently; continuity at release is enforced.
# States are resistance deviations. Signed release weights can represent slow drift;
# they are not identified microscopic trap occupancies.
rng=np.random.default_rng(20241001)
def exp_terms(t,tau):return np.exp(-np.asarray(t)[:,None]/np.asarray(tau)[None,:])
def fit_pre(t,y,mask):
 # Stable baseline relaxation y=B+A*exp(-(t-tfirst)/tau), with signed A.
 start=float(t.min())
 def f(p,tt):return p[0]+p[1]*np.exp(-(tt-start)/np.exp(p[2]))
 opt=least_squares(lambda p:f(p,t[mask])-y[mask],[y[-1],min(-.1,y[0]-y[-1]),np.log(3)],bounds=([20,-5,np.log(.01)],[150,5,np.log(100)]),max_nfev=2000)
 return dict(R0_mOhm=float(f(opt.x,np.array([t.max()]))[0]),Rinf_mOhm=opt.x[0],A_mOhm=opt.x[1],start_min=start,tau_min=float(np.exp(opt.x[2])),training=metrics(y[mask],f(opt.x,t[mask])),holdout=metrics(y[~mask],f(opt.x,t[~mask]))),f(opt.x,t)
def fit_capture(t,y,mask,R0,k):
 def f(p,tt):return R0+(1-exp_terms(tt,np.exp(p[k:])))@p[:k]
 best=None
 for attempt in range(10):
  tau=np.sort(np.exp(rng.uniform(np.log(.015),np.log(25),k)))
  amps=np.full(k,max(1,(np.median(y[-20:])-R0))/k)
  p0=np.r_[amps,np.log(tau)]
  opt=least_squares(lambda p:f(p,t[mask])-y[mask],p0,bounds=(np.r_[np.full(k,-10),np.full(k,np.log(.002))],np.r_[np.full(k,70),np.full(k,np.log(150))]),max_nfev=2000)
  if best is None or opt.cost<best.cost:best=opt
 p=best.x;ix=np.argsort(p[k:]);A=p[:k][ix];tau=np.exp(p[k:][ix])
 return dict(modes=k,A_mOhm=A.tolist(),tau_capture_min=tau.tolist(),training=metrics(y[mask],f(p,t[mask])),holdout=metrics(y[~mask],f(p,t[~mask]))),lambda tt:R0+(1-exp_terms(np.atleast_1d(tt),tau))@A
def fit_release(t,y,mask,Rend,k):
 # R=B+sum(Ai exp(-u/taui)), last Ai=Rend-B-sum(previousAi).
 def unpack(p):return p[0],np.r_[p[1:k],Rend-p[0]-sum(p[1:k])],np.exp(p[k:])
 def f(p,tt):B,A,tau=unpack(p);return B+exp_terms(tt,tau)@A
 best=None
 for attempt in range(14):
  tau=np.sort(np.exp(rng.uniform(np.log(.02),np.log(25),k)))
  B=np.median(y[-30:]);A=np.full(k-1,(Rend-B)/k)
  p0=np.r_[B,A,np.log(tau)]
  opt=least_squares(lambda p:f(p,t[mask])-y[mask],p0,bounds=(np.r_[20,np.full(k-1,-60),np.full(k,np.log(.002))],np.r_[120,np.full(k-1,70),np.full(k,np.log(200))]),max_nfev=2500)
  if best is None or opt.cost<best.cost:best=opt
 B,A,tau=unpack(best.x);ix=np.argsort(tau);A=A[ix];tau=tau[ix]
 return dict(modes=k,Rinf_mOhm=float(B),A_mOhm=A.tolist(),tau_release_min=tau.tolist(),training=metrics(y[mask],f(best.x,t[mask])),holdout=metrics(y[~mask],f(best.x,t[~mask]))),lambda tt:B+exp_terms(np.atleast_1d(tt),tau)@A
def choose(candidates):
 # Add a mode only when holdout RMSE improves by both25% and0.03mOhm.
 chosen=candidates[0]
 for cand in candidates[1:]:
  a=chosen[0].get('model_selection',chosen[0]['holdout'])['rmse_mOhm'];b=cand[0].get('model_selection',cand[0]['holdout'])['rmse_mOhm']
  if b<a*.75 and a-b>.03:chosen=cand
 return chosen
trapModels={};allmetrics={};condition_rows=[]
for name in ['fig11','fig12']:
 s=specs[name];trapModels[name]=[];allmetrics[name]=[]
 fig,axes=plt.subplots(2,1,figsize=(10,8),layout='constrained',sharex=True)
 for j,c in enumerate(datasets[name]):
  d=c['data'];t,y=d.T
  with np.errstate(divide='ignore',invalid='ignore'):dy=np.diff(y)/np.diff(t)
  edgeoff=np.flatnonzero((t[:-1]>12)&(t[:-1]<15)&(dy<-20))[0]
  edgeon=np.flatnonzero((t[:-1]>-.3)&(t[:-1]<.3)&(dy>20))[0]
  off=float(t[edgeoff]);onset=float(t[edgeon])
  pre=(t<=onset+1e-5);on=(t>onset+1e-5)&(t<=off+1e-5);rel=(t>off+1e-5)
  # Blocked alternating samples at approximately0.25min periods; excludes
  # adjacent-point random leakage while retaining fast-transition coverage.
  blocks=np.floor((t-t.min())/.25).astype(int)%5
  mask=(blocks!=1)&(blocks!=3);validation=blocks==1;test=blocks==3
  pm,py=fit_pre(t[pre],y[pre],mask[pre]);R0=pm['R0_mOhm']
  candidates=[fit_capture(t[on]-onset,y[on],mask[on],R0,k) for k in [1,2,3]]
  for cm0,cf0 in candidates:cm0['model_selection']=metrics(y[on][validation[on]],cf0(t[on][validation[on]]-onset))
  cm,cf=choose(candidates);Rend=float(cf(off-onset)[0])
  rcandidates=[fit_release(t[rel]-off,y[rel],mask[rel],Rend,k) for k in [1,2,3]]
  for rm0,rf0 in rcandidates:rm0['model_selection']=metrics(y[rel][validation[rel]],rf0(t[rel][validation[rel]]-off))
  rm,rf=choose(rcandidates)
  pred=np.empty(len(t));pred[pre]=py;pred[on]=cf(t[on]-onset);pred[rel]=rf(t[rel]-off)
  condition=dict(condition=c['condition'],condition_name=s['condition_name'],stress_off_min=off,
   stress_on_min=onset,transition_estimation='Native last vertex before slope above20mOhm/min on or below-20mOhm/min off; plotted-time alignment, not a recovered experimental command timestamp',
   pre=pm,capture=cm,release=rm,capture_candidates=[a[0] for a in candidates],release_candidates=[a[0] for a in rcandidates],
   all_training=metrics(y[mask],pred[mask]),all_holdout=metrics(y[~mask],pred[~mask]),model_selection=metrics(y[validation],pred[validation]),independent_blocked_time_test=metrics(y[test],pred[test]),
   release_Rend_mOhm=Rend)
  # Nominal text13min predicts a different release time. This sensitivity
  # changes time only, without refitting any parameter.
  nominal=np.empty(len(t));npf=t<0;nominal[npf]=pm['Rinf_mOhm']+pm['A_mOhm']*np.exp(-(t[npf]-pm['start_min'])/pm['tau_min']);nn=(t>=0)&(t<=13);nr=t>13
  nominal[nn]=cf(t[nn]);nominal[nr]=rm['Rinf_mOhm']+exp_terms(t[nr]-13,rm['tau_release_min'])@np.asarray(rm['A_mOhm'])
  condition['nominal_text_13min_timing_all_points']=metrics(y,nominal)
  trapModels[name].append(condition);allmetrics[name].append({k:condition[k] for k in ['condition','all_training','all_holdout','model_selection','independent_blocked_time_test','nominal_text_13min_timing_all_points']})
  color=plt.cm.turbo(j/max(1,len(datasets[name])-1));label=f'{c["condition"]} '+('V' if name=='fig11' else 'C')
  axes[0].plot(t,y,color=color,lw=.5,alpha=.6);axes[0].plot(t,pred,color=color,lw=1.5,label=label)
  axes[1].plot(t,pred-y,color=color,lw=.8,label=label)
  roles=np.where(mask,'calibration',np.where(validation,'model_selection','independent_blocked_time_test'))
  savecsv(OUT/f'{name}_{s["condition_name"]}_{c["condition"]}_comparison.csv',['time_min','plotted_Ron_mOhm','model_Ron_mOhm','model_nominal13min_mOhm','validation_role'],zip(t,y,pred,nominal,roles))
  condition_rows.append([name,c['condition'],s['condition_name'],off,cm['modes'],rm['modes'],condition['all_training']['rmse_mOhm'],condition['all_holdout']['rmse_mOhm'],condition['all_holdout']['max_abs_mOhm'],condition['independent_blocked_time_test']['rmse_mOhm'],condition['independent_blocked_time_test']['max_abs_mOhm']])
 axes[0].axvline(0,color='k',ls=':',lw=.7);axes[0].axvline(s['stress_off_min'],color='k',ls=':',lw=.7)
 axes[0].set(ylabel='On-resistance (mOhm)',title=f'{name.upper()} | public-curve calibrated capture/release ODE');axes[0].legend(ncol=4,fontsize=8);axes[0].grid(alpha=.25)
 axes[1].set(xlabel='Time (min)',ylabel='Fit minus plot (mOhm)',title='Residuals; selected points are withheld during fitting');axes[1].grid(alpha=.25)
 fig.savefig(OUT/f'{name}_trap_reconstruction.png',dpi=180);plt.close(fig)

models=dict(status='Public-curve calibrated behavioral reconstruction. No independent microscopic trap validation.',static=staticModel,trapping=trapModels,
 units=dict(resistance='mOhm',time='min',temperature='degC',current='A'),
 state_equations=dict(capture='dz/dt=(1-z)/tau_capture, z(t_on)=0; R=R0+sum(Acapture*z)',release='dz/dt=-z/tau_release, z(t_off)=1; R=Rinf+sum(Arelease*z)',pre='dR/dt=(Rinf_pre-R)/tau_pre; initialize R at native plot start'),
 sampling='Original paper states repeatedmeasurements every5s; PDF vector vertices include irregular plotted sampling and are not raw acquisition files.',
 identification_limits='Capture/release resistance modes fitted independently; signedweights may represent drift. They are not uniquely identified carriertrap populations. Voltage/temperature families are fitted separately; shared150V25C plotted vertices crosscheck coordinate calibration but no2D voltage-temperature measurement grid exists.')
(OUT/'model_parameters.json').write_text(json.dumps(models,indent=2),encoding='utf-8')
savecsv(OUT/'fit_metrics.csv',['figure','condition','condition_name','stress_off_min','capture_modes','release_modes','calibration_RMSE_mOhm','blocked_holdout_RMSE_mOhm','blocked_holdout_MAX_mOhm','independent_test_RMSE_mOhm','independent_test_MAX_mOhm'],condition_rows)
(OUT/'metrics.json').write_text(json.dumps(dict(static=staticModel,trapping=allmetrics),indent=2),encoding='utf-8')
print(json.dumps(dict(static=staticModel,trap_metrics=condition_rows),indent=2))
