function summary=run_integrated_snapshots()
% Public-curve behavioral Ron snapshots coupled to a native electrical model.
% Pulse heating is a one-way diagnostic, not feedback into the fitted Fig10
% measurement surface. No claim of independently predicted trapping physics.
here=fileparts(mfilename('fullpath'));full=fileparts(here);outputs=fileparts(full);
addpath(fullfile(full,'simulink'),fullfile(full,'ron_trapping'),fullfile(outputs,'reproduction','matlab'));
conditions=[30,25,150,0;30,25,150,5;30,25,150,20;-30,25,150,5;30,55,150,5;30,25,400,5];
labels={'positive30_initial','positive30_capture','positive30_recovery', ...
 'negative30_capture','positive30_hot55','positive30_stress400'};
Rth=[.015,.23,.24,.015];Cth=[8e-5,7.4e-4,6.5e-3,2e-3];
all=cell(6,1);items=cell(6,1);
for k=1:6
 q=conditions(k,:);[Rdut,info]=ron_behavior_coupled(q(1),q(2),q(3),q(4),0,13.58,q(2));
 config=struct('Rdut',Rdut,'Raux',.08,'targetCurrent_A',q(1),'VDC',q(3));
 electrical=run_bridge_snapshot(config);
 [time_s,index]=unique(electrical.time_s,'stable');
 Id=electrical.dut_current_A(index);Vds=electrical.dut_Vds_V(index);
 power=Id.^2*Rdut;
 [nodes,diagnostics]=cauer_temperature(time_s,power,Rth,Cth);
 ta=electrical.measurementWindow_s(1);tb=electrical.measurementWindow_s(2);
 tw=unique([time_s(time_s>ta&time_s<tb);ta;tb]);
 meanRise=trapz(tw,interp1(time_s,nodes(:,1),tw))/(tb-ta);
 heat=struct('time_s',time_s,'junctionRise_K',nodes(:,1),'nodeRises_K',nodes, ...
  'power_W',power,'diagnostics',diagnostics,'R_K_per_W',Rth,'C_J_per_K',Cth);
 item=struct('label',labels{k},'targetCurrent_A',q(1),'surfaceTemperatureInput_C',q(2), ...
  'caseTemperature_C',q(2),'historicalStressVoltage_V',q(3),'historyTime_min',q(4), ...
  'stressOn_min',0,'stressOff_min',13.58,'setRon_Ohm',Rdut, ...
  'extractedRon_Ohm',electrical.measuredRon_Ohm, ...
  'extractionError_Ohm',abs(electrical.measuredRon_Ohm-Rdut), ...
  'meanCurrent_A',electrical.meanMeasurementCurrent_A, ...
  'measurementMeanPulseRise_K',meanRise,'peakPulseRise_K',max(nodes(:,1)), ...
  'energyBalanceRelativeResidual',diagnostics.maximumRelativeEnergyResidual, ...
  'calibratedTrapIncrement_mOhm',info.trap_increment_mOhm,'family',info.family, ...
  'measurementWindow_s',[ta,tb]);
 assert(item.extractionError_Ohm<1e-8,'Native extraction does not match the configured resistance.');
 assert(item.energyBalanceRelativeResidual<1e-8,'Thermal energy balance failed.');
 T=table(time_s,Id,Vds,interp1(electrical.time_s,electrical.bus_voltage_V,time_s),power,nodes(:,1), ...
  'VariableNames',{'time_s','dut_current_A','dut_Vds_V','bus_voltage_V','conduction_power_W','pulse_deltaTj_K'});
 writetable(T,fullfile(here,[labels{k} '.csv']));save(fullfile(here,[labels{k} '.mat']),'electrical','heat','item','info','config');
 all{k}=struct('electrical',electrical,'heat',heat,'item',item,'info',info);items{k}=item;
end
summary=struct('cases',{items},'modelClass','Public-curve calibrated behavioral coupling demonstration', ...
 'electricalEngine','Native Simscape Electrical SPS full bridge, ode45', ...
 'thermalEngine','Exact four-capacitance Cauer ladder pulse-increment diagnostic', ...
 'couplingDirection','Behavioral frozen-Ron snapshot -> electrical pulse -> thermal increment', ...
 'limits',{{'Ron is configured from public Fig10-12 calibrations, so this is not an independent prediction of trapping physics.', ...
 'Fig10 surface was measured versus case temperature and may retain5us pulse self-heating; treating its temperature coordinate as instantaneous junction temperature is an unvalidated assumption.', ...
 'No thermal feedback is applied to the fitted Fig10 surface here, to avoid counting its residual self-heating twice.', ...
 'A30A calibrated trap-resistance increment is additively combined with signed-current static resistance; separability is an explicit behavioral assumption.', ...
 'Negative current uses synchronized gated on-state conduction, not a gate-dependent self-commutated reverse-conduction compact model.', ...
 'No current-temperature-trap iteration was tuned to match Table I experimental means or standard deviations.'}});
write_json(fullfile(here,'integration_metrics.json'),summary);
save(fullfile(here,'integration_all_cases.mat'),'all','summary');
rows=[items{:}];writetable(struct2table(rmfield(rows,{'label','family','measurementWindow_s'})),fullfile(here,'integration_summary.csv'));
plot_cases(all,here);
build_native_electrothermal(here,full,all{2});
disp(struct2table(rmfield(rows,{'label','family','measurementWindow_s'})));
end

function plot_cases(all,here)
f=figure('Visible','off','Color','w','Position',[100 100 1250 860]);tl=tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
for k=1:6
 a=all{k};nexttile;relative=(a.electrical.time_s-a.item.measurementWindow_s(1))*1e6;
 yyaxis left;plot(relative,a.electrical.dut_current_A,'LineWidth',1.3);ylabel('DUT current (A)');
 yyaxis right;plot(relative,a.electrical.dut_Vds_V,'--','LineWidth',1.1);ylabel('DUT Vds (V)');ylim([-6,8]);
 xlim([-1,7]);xlabel('Time from measurement start (us)');grid on;
 title(sprintf('%+dA, %dC, %dV, %.0fmin | Ron %.3fmOhm',a.item.targetCurrent_A,a.item.caseTemperature_C,a.item.historicalStressVoltage_V,a.item.historyTime_min,1e3*a.item.setRon_Ohm));
end
title(tl,'Calibrated behavioral Ron snapshots in the native full bridge');
savefig(f,fullfile(here,'integration_electrical.fig'));exportgraphics(f,fullfile(here,'integration_electrical.png'),'Resolution',170);close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1200 650]);c=lines(6);names=cell(6,1);
for k=1:6
 a=all{k};plot((a.heat.time_s-a.item.measurementWindow_s(1))*1e6,a.heat.junctionRise_K,'Color',c(k,:),'LineWidth',1.5);hold on;
 names{k}=sprintf('%+dA, %dC, %dV, %.0fmin',a.item.targetCurrent_A,a.item.caseTemperature_C,a.item.historicalStressVoltage_V,a.item.historyTime_min);
end
xline(0,'k:','Measurement starts');xline(5,'k:','Measurement ends');xlim([-2,15]);grid on;
xlabel('Time from measurement start (us)');ylabel('Pulse junction-temperature increment (K)');
title('One-way Cauer diagnostic; temperature is not fed back into the fitted surface');
legend(names,'NumColumns',2,'Location','northeast');savefig(f,fullfile(here,'integration_pulse_heating.fig'));exportgraphics(f,fullfile(here,'integration_pulse_heating.png'),'Resolution',180);close(f);
end

function build_native_electrothermal(here,full,example)
base='GaN_Full_Bridge_SPS';thermal='GaN_Cauer_Figure14';m='GaN_Behavioral_Electrothermal_Snapshot';
load_system(fullfile(full,'simulink',[base '.slx']));
save_system(base,fullfile(here,[m '.slx']));
if bdIsLoaded(base);close_system(base,0);end
load_system(fullfile(here,[m '.slx']));load_system(fullfile(full,'simulink',[thermal '.slx']));
w=get_param(m,'ModelWorkspace');p=evalin(w,'p');fn=fieldnames(example.electrical.parameters);
for k=1:numel(fn);p.(fn{k})=example.electrical.parameters.(fn{k});end
assignin(w,'p',p);assignin(w,'R',[.015,.23,.24,.015]);assignin(w,'C',[8e-5,7.4e-4,6.5e-3,2e-3]);
add_block('simulink/Math Operations/Math Function',[m '/DUT conduction current squared'],'Operator','square','Position',[1050 670 1090 710],'ShowName','off');
add_block('simulink/Math Operations/Gain',[m '/DUT resistance snapshot'],'Gain','p.Rdut','Position',[1130 670 1200 710]);
add_block([thermal '/Proposed Cauer ladder'],[m '/Native Cauer pulse heating'],'Position',[1270 630 1450 740]);
add_block('simulink/Sinks/To Workspace',[m '/Pulse thermal node outputs'],'VariableName','thermalNodes','SaveFormat','Timeseries','Position',[1510 650 1660 700]);
add_line(m,'DUT current/1','DUT conduction current squared/1','autorouting','on');
add_line(m,'DUT conduction current squared/1','DUT resistance snapshot/1');
add_line(m,'DUT resistance snapshot/1','Native Cauer pulse heating/1');
add_line(m,'Native Cauer pulse heating/1','Pulse thermal node outputs/1');
a=Simulink.Annotation(m,sprintf('Behavioral snapshot: %+d A, %.0f C surface coordinate, %.0f V historical stress, %.0f min.\nRon frozen at %.3f mOhm; genuine electrical-to-Cauer power path.\nCalibration demonstration only; no temperature feedback into Fig10 surface.',example.item.targetCurrent_A,example.item.caseTemperature_C,example.item.historicalStressVoltage_V,example.item.historyTime_min,1e3*example.item.setRon_Ohm));
a.Position=[1040 790 1620 880];set_param(m,'ZoomFactor','FitSystem');
save_system(m);print(['-s' m],'-dpng','-r150',fullfile(here,'integrated_native_model.png'));
o=sim(m);time_s=o.thermalNodes.Time;rise=o.thermalNodes.Data(:,1);
ref=interp1(example.heat.time_s,example.heat.junctionRise_K,time_s,'linear','extrap');
valid=struct('model',[m '.slx'],'case',example.item.label,'maximumDifferenceFromExactCauer_K',max(abs(rise-ref)), ...
 'peakNativeRise_K',max(rise),'peakExactRise_K',example.item.peakPulseRise_K, ...
 'passed',max(abs(rise-ref))<1e-3,'scope','Native simultaneous electrical and thermal integration, frozen calibratedRon snapshot');
assert(valid.passed,'Native integrated Cauer model does not match exact integration.');
write_json(fullfile(here,'native_integration_validation.json'),valid);
writetable(table(time_s,rise,ref,'VariableNames',{'time_s','native_deltaTj_K','exact_deltaTj_K'}),fullfile(here,'native_integration_thermal_comparison.csv'));
close_system(m,0);close_system(thermal,0);
end

function write_json(file,value);f=fopen(file,'w','n','UTF-8');fprintf(f,'%s\n',jsonencode(value,'PrettyPrint',true));fclose(f);end
