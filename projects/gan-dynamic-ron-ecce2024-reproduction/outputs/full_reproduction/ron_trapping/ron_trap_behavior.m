function [R_mOhm,p]=ron_trap_behavior(time_min,family,condition)
% Closed-form solution to the native Simulink capture/release ODE model.
% Family='fig11',condition=voltageV; family='fig12',condition=caseTempC.
% Resistance deviation states are fitted to public curves; they are not
% uniquely identified microscopic trap occupancy states. No extrapolation.
m=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'model_parameters.json')));
pp=m.trapping.(family);p=pp(find([pp.condition]==condition,1));
if isempty(p),error('The condition was not measured in the published figure.');end
t=time_min(:);R_mOhm=zeros(size(t));pre=t<p.stress_on_min;on=t>=p.stress_on_min&t<=p.stress_off_min;rel=t>p.stress_off_min;
R_mOhm(pre)=p.pre.Rinf_mOhm+p.pre.A_mOhm*exp(-(t(pre)-p.pre.start_min)/p.pre.tau_min);
if any(on),R_mOhm(on)=p.pre.R0_mOhm+(1-exp(-(t(on)-p.stress_on_min)./p.capture.tau_capture_min(:)'))*p.capture.A_mOhm(:);end
if any(rel),R_mOhm(rel)=p.release.Rinf_mOhm+exp(-(t(rel)-p.stress_off_min)./p.release.tau_release_min(:)')*p.release.A_mOhm(:);end
R_mOhm=reshape(R_mOhm,size(time_min));
end
