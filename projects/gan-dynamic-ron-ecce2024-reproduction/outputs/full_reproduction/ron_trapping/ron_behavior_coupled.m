function [R_Ohm,info]=ron_behavior_coupled(Id_A,Tj_C,Vstress_V,history_time_min,stress_on_min,stress_off_min,Tcase_C)
% Coupled illustration based ONLY on the public Fig10..12 calibrations.
% Units: A,degC,V,min,min,min,degC -> Ohm. Default case temperature25C.
% The static surface supplies current and instantaneous junction-temperature
% response; a calibrated30A trapping-resistance increment is added. This
% assumed separation of effects is NOT independently validated by the paper.
% Available dynamic slices: Tc25C/V50..400V OR V150V/Tc15..55C. Their1D
% interpolation is behavioral; no unsupported2D trap surface is fabricated.
if nargin<7,Tcase_C=25;end
if any(Tj_C(:)<15|Tj_C(:)>95)||any(abs(Id_A(:))>50)
 error('Fig10 calibrated domain is15..95C and approximately-50..50A.');
end
if stress_off_min<stress_on_min,error('Stress release must follow application.');end
if Vstress_V==0
 R_Ohm=ron_static_behavior(Id_A,Tj_C)/1000;
 info=struct('model_class','public-curve static calibrated behavior','family','unstressed baseline','trap_increment_mOhm',zeros(size(history_time_min)),...
  'assumptions','Zero historicalstressamplitude assumes no prior trapping; recovery frompriorstressmust retain that historicalamplitude and specify stressofftime','units','A,degC,V,min -> Ohm');
 return
end
p=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'model_parameters.json')));
if abs(Tcase_C-25)<1e-6 && Vstress_V>=50 && Vstress_V<=400
 family='fig11';value=Vstress_V;pp=p.trapping.fig11;
elseif abs(Vstress_V-150)<1e-6 && Tcase_C>=15 && Tcase_C<=55
 family='fig12';value=Tcase_C;pp=p.trapping.fig12;
else
 error('Dynamic data cover Tc25C voltage-slice or150V temperature-slice only.');
end
conditions=[pp.condition];[conditions,ix]=sort(conditions);pp=pp(ix);
low=find(conditions<=value,1,'last');high=find(conditions>=value,1,'first');
if low==high,weights=1;selected=low;else,weights=[(conditions(high)-value)/(conditions(high)-conditions(low)),(value-conditions(low))/(conditions(high)-conditions(low))];selected=[low high];end
t=history_time_min(:);delta=zeros(size(t));
for k=1:numel(selected)
 q=pp(selected(k));d=zeros(size(t));on=t>=stress_on_min&t<=stress_off_min;rel=t>stress_off_min;
 tau=q.capture.tau_capture_min(:)';A=q.capture.A_mOhm(:);
 if any(on),d(on)=(1-exp(-(t(on)-stress_on_min)./tau))*A;end
 new_end=(1-exp(-(stress_off_min-stress_on_min)./tau))*A;
 source_end=q.release_Rend_mOhm-q.pre.R0_mOhm;
 % Scale the published release solution to the newly chosen capture duration.
 % This exact continuity is an explicit behavioral extension, not evidence
 % that physical release obeys the same law for otherstressdurations.
 if abs(source_end)>eps && any(rel)
  d(rel)=new_end/source_end*(q.release.Rinf_mOhm-q.pre.R0_mOhm+exp(-(t(rel)-stress_off_min)./q.release.tau_release_min(:)')*q.release.A_mOhm(:));
 end
 delta=delta+weights(k)*d;
end
delta=reshape(delta,size(history_time_min));
R_Ohm=(ron_static_behavior(Id_A,Tj_C)+delta)/1000;
info=struct('model_class','public-curve calibrated behavioral coupling','family',family,...
 'trap_slice_conditions',conditions(selected),'weights',weights,'trap_increment_mOhm',delta,...
 'assumptions','Additive current/instantaneous-temperature baseline plus30A trap increment; alternate stressduration uses scaled release modes; not independently validated',...
 'units','A,degC,V,min -> Ohm');
end
