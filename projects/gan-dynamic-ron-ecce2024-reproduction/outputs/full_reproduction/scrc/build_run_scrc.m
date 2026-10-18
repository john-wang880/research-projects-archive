function metrics=build_run_scrc()
% Reduced third-quadrant mechanism, not a vendor GaN compact model.
% Cnode*dVsd/dt=Iload-Idut-Ils1-Vsd/Rleak; real circuit-state integration.
here=fileparts(mfilename('fullpath'));cd(here);m='GaN_SCRC_Current_Sharing';
if bdIsLoaded(m);close_system(m,0);end
new_system(m);set_param(m,'Solver','ode15s','RelTol','1e-9','AbsTol','1e-10', ...
 'MaxStep','10e-9','StopTime','8e-6','ReturnWorkspaceOutputs','on');
p=struct('Itotal',30,'VgDUT',0,'VgLS1',-3,'VthDUT',1.7,'VthLS1',1.7, ...
 'Rdut',.08,'Raux',.08,'Rshunt',.01,'Cnode',200e-12,'Rleak',1e9,'Fdut',1.7,'Faux',4.7);
w=get_param(m,'ModelWorkspace');assignin(w,'p',p);
add_block('simulink/Sources/Clock',[m '/Time'],'Position',[15 65 45 95]);
add_block('simulink/User-Defined Functions/Fcn',[m '/Reverse load pulse'], ...
 'Expr','(u>=1e-6 && u<1.01e-6)*(u-1e-6)/10e-9*p.Itotal+(u>=1.01e-6 && u<=6e-6)*p.Itotal+(u>6e-6 && u<6.01e-6)*(1-(u-6e-6)/10e-9)*p.Itotal', ...
 'Position',[95 60 225 100]);
add_block('simulink/Math Operations/Sum',[m '/Node current balance'],'Inputs','+---','Position',[295 130 320 210],'ShowName','off');
add_block('simulink/Math Operations/Gain',[m '/Node inverse capacitance'],'Gain','1/p.Cnode','Position',[370 145 460 190]);
add_block('simulink/Continuous/Integrator',[m '/Source drain node voltage'],'InitialCondition','0','Position',[515 145 560 190]);
add_block('simulink/User-Defined Functions/Fcn',[m '/DUT reverse channel'], ...
 'Expr','(u>=p.Fdut)*(u-p.Fdut)/(p.Rdut+p.Rshunt)','Position',[675 110 920 150]);
add_block('simulink/User-Defined Functions/Fcn',[m '/LS1 reverse channel'], ...
 'Expr','(u>=p.Faux)*(u-p.Faux)/p.Raux','Position',[675 240 920 280]);
add_block('simulink/Math Operations/Gain',[m '/Node leakage'],'Gain','1/p.Rleak','Position',[675 365 765 400]);
add_block('simulink/Math Operations/Gain',[m '/DUT shunt voltage drop'],'Gain','p.Rshunt','Position',[985 100 1085 145]);
add_block('simulink/Math Operations/Sum',[m '/Actual DUT Vsd'],'Inputs','+-','Position',[1160 150 1190 190]);
add_block('simulink/Signal Routing/Mux',[m '/Observables'],'Inputs','4','Position',[1270 85 1275 305]);
add_block('simulink/Sinks/To Workspace',[m '/Simulation data'],'VariableName','observations','SaveFormat','Timeseries','Position',[1340 150 1455 195]);
add_block('simulink/Sinks/Scope',[m '/Current and voltage scope'],'NumInputPorts','4','Position',[1340 270 1455 345]);
add_line(m,'Time/1','Reverse load pulse/1');add_line(m,'Reverse load pulse/1','Node current balance/1','autorouting','on');
add_line(m,'Node current balance/1','Node inverse capacitance/1');add_line(m,'Node inverse capacitance/1','Source drain node voltage/1');
add_line(m,'Source drain node voltage/1','DUT reverse channel/1','autorouting','on');
add_line(m,'Source drain node voltage/1','LS1 reverse channel/1','autorouting','on');
add_line(m,'Source drain node voltage/1','Node leakage/1','autorouting','on');
add_line(m,'DUT reverse channel/1','Node current balance/2','autorouting','on');
add_line(m,'LS1 reverse channel/1','Node current balance/3','autorouting','on');
add_line(m,'Node leakage/1','Node current balance/4','autorouting','on');
add_line(m,'DUT reverse channel/1','DUT shunt voltage drop/1');
add_line(m,'Source drain node voltage/1','Actual DUT Vsd/1','autorouting','on');
add_line(m,'DUT shunt voltage drop/1','Actual DUT Vsd/2','autorouting','on');
signals={'Reverse load pulse','DUT reverse channel','LS1 reverse channel','Actual DUT Vsd'};
for k=1:4
 add_line(m,[signals{k} '/1'],['Observables/' num2str(k)],'autorouting','on');
 add_line(m,[signals{k} '/1'],['Current and voltage scope/' num2str(k)],'autorouting','on');
end
add_line(m,'Observables/1','Simulation data/1');
a=Simulink.Annotation(m,sprintf('Reduced GaN reverse conduction: F=max(Vth-Vgs,0); I=max((Vsd-F)/R,0).\nDUT branch includes its10mOhm source shunt; LS1 branch has no shunt.\nVth=1.7V and reverseRon80mOhm are explicit assumptions, not extracted operating-point parameters.'));a.Position=[310 445 1210 520];
save_system(m,fullfile(here,[m '.slx']));print(['-s' m],'-dpng','-r150',fullfile(here,'scrc_native_model.png'));
items={};datasets={};gaps=[0 .5 1 2 3 4.5 5 6];
for vgD=[-3,0,6]
 for current=[10,30,50]
  for gap=gaps
   q=p;q.Itotal=current;q.VgDUT=vgD;q.VgLS1=vgD-gap;
   assert(q.VgDUT>=-10 && q.VgLS1>=-10 && q.VgDUT<=7 && q.VgLS1<=7,'Gate setting outside continuous device rating.');
   q.Fdut=max(q.VthDUT-q.VgDUT,0);q.Faux=max(q.VthLS1-q.VgLS1,0);
   in=Simulink.SimulationInput(m);in=in.setVariable('p',q,'Workspace',m);o=sim(in);
   t=o.observations.Time;y=o.observations.Data;win=t>2e-6&t<5.8e-6;
   Id=mean(y(win,2));Ia=mean(y(win,3));Vdut=mean(y(win,4));
   Vcommon=(q.Itotal+q.Fdut/(q.Rdut+q.Rshunt)+q.Faux/q.Raux)/(1/(q.Rdut+q.Rshunt)+1/q.Raux);
   if q.Fdut+q.Itotal*(q.Rdut+q.Rshunt)<=q.Faux
    Vcommon=q.Fdut+q.Itotal*(q.Rdut+q.Rshunt);
   end
   expectedD=max((Vcommon-q.Fdut)/(q.Rdut+q.Rshunt),0);expectedA=max((Vcommon-q.Faux)/q.Raux,0);
   item=struct('VgDUT_V',vgD,'VgLS1_V',vgD-gap,'gateGap_V',gap,'reverseTotalCurrent_A',current, ...
    'DUT_reverseCurrent_A',Id,'LS1_reverseCurrent_A',Ia,'DUT_drainCurrent_A',-Id, ...
    'DUT_Vsd_V',Vdut,'trueEffectiveSCRCresistance_Ohm',Vdut/Id, ...
    'wrongTotalCurrentResistance_Ohm',Vdut/current, ...
    'wrongTotalCurrentRelativeBias_percent',100*(Id/current-1), ...
    'DUT_fraction_percent',100*Id/current,'analyticDUT_A',expectedD,'analyticLS1_A',expectedA, ...
    'maximumSteadyCurrentBalanceError_A',max(abs(sum(y(win,2:3),2)-current)), ...
    'analyticCurrentError_A',max(abs([Id-expectedD,Ia-expectedA])));
   assert(item.analyticCurrentError_A<1e-5 && item.maximumSteadyCurrentBalanceError_A<1e-5,'SCRC KCL/closed-form check failed.');
   items{end+1}=item;datasets{end+1}=struct('time_s',t,'observations',y,'parameters',q); %#ok<AGROW>
  end
 end
end
T=struct2table([items{:}]);writetable(T,fullfile(here,'scrc_current_sharing_sweep.csv'));save(fullfile(here,'scrc_native_sweep.mat'),'items','datasets','T');
metrics=struct('model',[m '.slx'],'cases',height(T),'maximumKCLerror_A',max(T.maximumSteadyCurrentBalanceError_A), ...
 'maximumAnalyticBranchError_A',max(T.analyticCurrentError_A), ...
 'currentMagnitudes_A',[10,30,50],'DUTgateSettings_V',[-3,0,6],'gateGaps_V',gaps, ...
 'assumedThreshold_V',1.7,'datasheetThresholdMinTypMax_V',[1.1,1.7,2.6], ...
 'continuousGateRating_V',[-10,7],'assumedReverseRon_Ohm',.08,'assumedTotalNodeCapacitance_F',200e-12, ...
 'nominalOffStateIsolationGap_V',(.08+.01)*[10,30,50], ...
 'worstDatasheetThresholdSpreadIsolationGap_V',(.08+.01)*[10,30,50]+2.6-1.1, ...
 'interpretation','GateLS1<GateDUT raises the LS1 turn-on threshold but is not sufficient at arbitrarily high reverse current.', ...
 'measurementBiasDefinition','Bias only if total inductor current is wrongly substituted for actual DUT shunt current; proper paper shunt measurement remains valid for actual DUT current.', ...
 'scope','Mechanism-level current sharing with a lumped capacitor, fixed threshold and linear reverseRon, not a vendor compact model or experimental reproduction');
write_json(fullfile(here,'scrc_metrics.json'),metrics);plot_scrc(T,datasets,here);
close_system(m,0);disp(metrics);
end

function plot_scrc(T,datasets,here)
f=figure('Visible','off','Color','w','Position',[100 100 1250 850]);tl=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for vgD=[0,-3]
 nexttile;for current=[10,30,50];s=T.VgDUT_V==vgD&T.reverseTotalCurrent_A==current;plot(T.gateGap_V(s),T.DUT_fraction_percent(s),'-o','LineWidth',1.4);hold on;end
 xlabel('Vgs,DUT - Vgs,LS1 (V)');ylabel('Current in DUT (%)');ylim([40,103]);grid on;title(sprintf('Off-state reverse conduction: DUT gate %dV',vgD));legend('10A','30A','50A','Location','southeast');
 nexttile;for current=[10,30,50];s=T.VgDUT_V==vgD&T.reverseTotalCurrent_A==current;plot(T.gateGap_V(s),T.wrongTotalCurrentRelativeBias_percent(s),'-o','LineWidth',1.4);hold on;end
 xlabel('Gate voltage difference (V)');ylabel('Wrong-current resistance bias (%)');grid on;title('Error if total load current is used instead of DUT shunt');legend('10A','30A','50A','Location','southeast');
end
title(tl,'Native SCRC parallel-branch mechanism scan; nominal Vth1.7V and reverseRon80mOhm');savefig(f,fullfile(here,'scrc_gate_gap_sweep.fig'));exportgraphics(f,fullfile(here,'scrc_gate_gap_sweep.png'),'Resolution',170);close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1200 650]);tl=tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for gap=[0,3]
 ix=find(T.VgDUT_V==0&T.reverseTotalCurrent_A==30&T.gateGap_V==gap,1);d=datasets{ix};nexttile;
 plot(d.time_s*1e6,d.observations(:,1),'k--','LineWidth',1.3);hold on;
 plot(d.time_s*1e6,d.observations(:,2),'LineWidth',1.5);plot(d.time_s*1e6,d.observations(:,3),'LineWidth',1.5);grid on;
 xlabel('Time (us)');ylabel('Reverse current magnitude (A)');title(sprintf('30A, DUT gate0V, LS1 gate-%gV',gap));legend('Total','DUT','LS1','Location','southeast');
end
title(tl,'Equal gates divert current; sufficiently lower LS1 gate suppresses diversion');savefig(f,fullfile(here,'scrc_time_domain.fig'));exportgraphics(f,fullfile(here,'scrc_time_domain.png'),'Resolution',180);close(f);
end
function write_json(file,value);f=fopen(file,'w','n','UTF-8');fprintf(f,'%s\n',jsonencode(value,'PrettyPrint',true));fclose(f);end
