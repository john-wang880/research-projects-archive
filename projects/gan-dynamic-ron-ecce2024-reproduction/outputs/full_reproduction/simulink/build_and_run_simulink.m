function build_and_run_simulink()
% Native Simscape Electrical full bridge and native Simulink Cauer ladder.
% Figure 1-4 fixed-Ron topology reproduction; no vendor compact/trap model.
outdir=fileparts(mfilename('fullpath')); cd(outdir);
load_system('simulink'); load_system('sps_lib');
build_bridge('GaN_Full_Bridge_SPS',outdir);
build_thermal('GaN_Cauer_Figure14',outdir);
polish_models(outdir);
run_bridge_cases(outdir);
run_thermal(outdir);
end

function build_bridge(m,outdir)
if bdIsLoaded(m);close_system(m,0);end
new_system(m);set_param(m,'Solver','ode45','MaxStep','5e-9','RelTol','1e-7', ...
    'AbsTol','1e-8','StopTime','55e-6','ReturnWorkspaceOutputs','on');
w=get_param(m,'ModelWorkspace');
par=struct('VDC',150,'L',90e-6,'Cdc',500e-6,'Ron',0.08,'Rdut',0.08,'Raux',0.08,'Rshunt',0.01,'Rload',0.001, ...
    'T0',2e-6,'Tcharge',32.5e-6,'Tfree',1e-6,'Tmeasure',5e-6, ...
    'direction',1,'conventional',0,'idleUpper',1);
assignin(w,'p',par);
add_block('sps_lib/powergui',[m '/powergui'],'Position',[690 25 780 60],'SimulationMode','Continuous','CurrentSourceSwitches','off');
add_block('simulink/Sources/Clock',[m '/Time'],'Position',[20 130 55 160]);
add_block('simulink/Ports & Subsystems/Subsystem',[m '/Gate sequencing'],'Position',[95 95 250 330]);
s=[m '/Gate sequencing'];delete_line(s,'In1/1','Out1/1');delete_block([s '/Out1']);
set_param([s '/In1'],'Name','time_s','Position',[20 125 45 145]);
gates={'HS1','HS2','DUT','LS1','LS2'};
expr={...
 '(u<p.T0) || (u>=p.T0+p.Tcharge && u<p.T0+p.Tcharge+p.Tfree && p.direction>0) || (u>=p.T0 && u<p.T0+p.Tcharge && p.direction<0) || (u>=p.T0+p.Tcharge+p.Tfree+p.Tmeasure && p.idleUpper>0)',...
 '(u<p.T0) || (u<p.T0+p.Tcharge+p.Tfree && p.direction>0) || (u>=p.T0+p.Tcharge+p.Tfree+p.Tmeasure && p.idleUpper>0)',...
 '(u>=p.T0+p.Tcharge+p.Tfree && u<p.T0+p.Tcharge+p.Tfree+p.Tmeasure) || (u>=p.T0 && u<p.T0+p.Tcharge && p.direction>0 && p.conventional>0)',...
 '(u>=p.T0 && u<p.T0+p.Tcharge && p.direction>0 && p.conventional==0) || (u>=p.T0+p.Tcharge+p.Tfree+p.Tmeasure && p.idleUpper==0)',...
 '(u>=p.T0 && p.direction<0 && u<p.T0+p.Tcharge+p.Tfree+p.Tmeasure) || (u>=p.T0+p.Tcharge+p.Tfree && u<p.T0+p.Tcharge+p.Tfree+p.Tmeasure) || (u>=p.T0+p.Tcharge+p.Tfree+p.Tmeasure && p.idleUpper==0)'};
for k=1:5
 y=30+65*(k-1);add_block('simulink/User-Defined Functions/Fcn',[s '/' gates{k} '_gate'], ...
  'Expr',expr{k},'Position',[90 y 290 y+30]);
 add_block('simulink/Sinks/Out1',[s '/' gates{k}],'Port',num2str(k),'Position',[345 y+5 365 y+25]);
 add_line(s,'time_s/1',[gates{k} '_gate/1'],'autorouting','on');
 add_line(s,[gates{k} '_gate/1'],[gates{k} '/1']);
end
add_line(m,'Time/1','Gate sequencing/1');
add_block('sps_lib/Passives/Series RLC Branch',[m '/DC link 500uF'],'BranchType','C', ...
 'Capacitance','p.Cdc','Setx0','on','InitialVoltage','p.VDC','Orientation','down','Position',[350 145 390 365]);
positions={[490 100 560 150],[910 100 980 150],[620 290 690 340],[490 290 560 340],[910 290 980 340]};
for k=1:5
 switchRon=choose(k==3,'p.Rdut','p.Raux');
 add_block('sps_lib/Power Electronics/Ideal Switch',[m '/' gates{k}], ...
  'Ron',switchRon,'IC','0','Rs','1e9','Cs','inf', ...
  'Orientation','down','Position',positions{k});
 add_line(m,['Gate sequencing/' num2str(k)],[gates{k} '/1'],'autorouting','on');
 % The measurement output is disabled through Measurements.
 ph=get_param([m '/' gates{k}],'PortHandles');
 if ~isempty(ph.Outport)
  add_block('simulink/Sinks/Terminator',[m '/' gates{k} '_measurement_unused'],'Position',[positions{k}(3)+30 positions{k}(2)+15 positions{k}(3)+50 positions{k}(2)+35]);
  add_line(m,ph.Outport(1),get_param([m '/' gates{k} '_measurement_unused'],'PortHandles').Inport);
 end
end
add_block('sps_lib/Sensors and Measurements/Current Measurement',[m '/Inductor current'], ...
 'Position',[575 205 625 235]);
add_block('sps_lib/Passives/Series RLC Branch',[m '/Load inductor 90uH'],'BranchType','RL', ...
 'Resistance','p.Rload','Inductance','p.L','SetiL0','on','InitialCurrent','0','Position',[715 205 845 235]);
add_block('sps_lib/Sensors and Measurements/Current Measurement',[m '/DUT current'], ...
 'Orientation','down','Position',[630 350 665 395]);
add_block('sps_lib/Passives/Series RLC Branch',[m '/Current shunt 10mOhm'],'BranchType','R', ...
 'Resistance','p.Rshunt','Orientation','down','Position',[630 410 665 460]);
add_block('sps_lib/Utilities/Ground',[m '/Ground'],'Position',[375 510 395 535]);
add_block('sps_lib/Sensors and Measurements/Voltage Measurement',[m '/DC bus voltage'], ...
 'Position',[1040 100 1080 145]);
add_block('sps_lib/Sensors and Measurements/Voltage Measurement',[m '/DUT drain-source voltage'], ...
 'Position',[1040 295 1080 345]);
% Physical node connections are made through conserving electrical ports.
port=@(b,side,index) getport([m '/' b],side,index);
bus=port('DC link 500uF','LConn',1);grnd=port('DC link 500uF','RConn',1);
left=port('HS1','RConn',1);right=port('HS2','RConn',1);
connect(m,bus,port('HS1','LConn',1));connect(m,bus,port('HS2','LConn',1));
connect(m,left,port('LS1','LConn',1));connect(m,left,port('DUT','LConn',1));
connect(m,left,port('Inductor current','LConn',1));
connect(m,port('Inductor current','RConn',1),port('Load inductor 90uH','LConn',1));
connect(m,port('Load inductor 90uH','RConn',1),right);
connect(m,right,port('LS2','LConn',1));
connect(m,port('DUT','RConn',1),port('DUT current','LConn',1));
connect(m,port('DUT current','RConn',1),port('Current shunt 10mOhm','LConn',1));
connect(m,grnd,port('LS1','RConn',1));connect(m,grnd,port('LS2','RConn',1));
connect(m,grnd,port('Current shunt 10mOhm','RConn',1));connect(m,grnd,port('Ground','LConn',1));
connect(m,bus,port('DC bus voltage','LConn',1));connect(m,grnd,port('DC bus voltage','LConn',2));
connect(m,left,port('DUT drain-source voltage','LConn',1));
connect(m,port('DUT','RConn',1),port('DUT drain-source voltage','LConn',2));
names={'Inductor current','DUT current','DC bus voltage','DUT drain-source voltage'};
vars={'iL','iD','Vbus','Vds'};
for k=1:4
 add_block('simulink/Sinks/To Workspace',[m '/' vars{k} '_data'],'VariableName',vars{k}, ...
  'SaveFormat','Timeseries','Position',[1145 80+75*k 1245 110+75*k]);
 add_line(m,[names{k} '/1'],[vars{k} '_data/1'],'autorouting','on');
end
add_block('simulink/Sinks/Scope',[m '/Waveform scope'],'NumInputPorts','4','Position',[1145 450 1250 515]);
for k=1:4;add_line(m,[names{k} '/1'],['Waveform scope/' num2str(k)],'autorouting','on');end
add_note(m,'ECCE Europe 2024 | Figure 1-4 full-bridge electrical topology',[360 15 650 55]);
add_note(m,'Finite DC-link capacitor; no stiff supply.\nFixed 80 mOhm switches, 10 mOhm DUT shunt.\nIdeal synchronous transitions; no Coss, deadtime or switching-loss claim.',[390 560 940 630]);
add_note(m,'Positive current: right to left.\nDUT current is positive drain to source.\nGate parameters are stored in Model Workspace p.',[20 360 300 425]);
set_param(m,'ZoomFactor','FitSystem');save_system(m,fullfile(outdir,[m '.slx']));
print(['-s' m],'-dpng','-r160',fullfile(outdir,'full_bridge_model.png'));
end

function build_thermal(m,outdir)
if bdIsLoaded(m);close_system(m,0);end
new_system(m);set_param(m,'Solver','ode15s','MaxStep','2e-9','RelTol','1e-9', ...
 'AbsTol','1e-10','StartTime','-5e-6','StopTime','45e-6','ReturnWorkspaceOutputs','on');
w=get_param(m,'ModelWorkspace');assignin(w,'R',[.015,.23,.24,.015]);assignin(w,'C',[8e-5,7.4e-4,6.5e-3,2e-3]);
add_block('simulink/Sources/Clock',[m '/Time'],'Position',[20 100 50 130]);
expr={'(u>=0 && u<=32.5e-6)*(50*u/32.5e-6)+(u>=33.5e-6 && u<=38.5e-6)*50', ...
 '(u>=33.5e-6 && u<=38.5e-6)*50'};
types={'Conventional','Proposed'};
for k=1:2
 y=55+225*(k-1);
 add_block('simulink/User-Defined Functions/Fcn',[m '/' types{k} ' current'], ...
 'Expr',expr{k},'Position',[110 y 260 y+40]);
 add_block('simulink/Math Operations/Math Function',[m '/' types{k} ' current squared'], ...
 'Operator','square','Position',[295 y 340 y+40]);
 add_block('simulink/Math Operations/Gain',[m '/' types{k} ' Ron 80mOhm'], ...
 'Gain','0.08','Position',[375 y 465 y+40]);
 ladder=[m '/' types{k} ' Cauer ladder'];add_ladder(ladder,[510 y-20 765 y+90]);
 add_block('simulink/Sinks/To Workspace',[m '/' types{k} ' temperatures'], ...
 'VariableName',[lower(types{k}) 'T'],'SaveFormat','Timeseries','Position',[840 y+10 990 y+45]);
 add_line(m,'Time/1',[types{k} ' current/1'],'autorouting','on');
 add_line(m,[types{k} ' current/1'],[types{k} ' current squared/1']);
 add_line(m,[types{k} ' current squared/1'],[types{k} ' Ron 80mOhm/1']);
 add_line(m,[types{k} ' Ron 80mOhm/1'],[types{k} ' Cauer ladder/1']);
 add_line(m,[types{k} ' Cauer ladder/1'],[types{k} ' temperatures/1']);
end
add_note(m,'Figure 14: paper plotted 50 A input template | zero initial temperature rise',[60 430 890 465]);
add_note(m,'True Cauer topology: junction C1 -- R1 -- C2 -- R2 -- C3 -- R3 -- C4 -- R4 -- fixed case.\nEach capacitor is referenced to temperature zero; current template is generated from time, not replayed CSV.',[60 485 920 550]);
set_param(m,'ZoomFactor','FitSystem');save_system(m,fullfile(outdir,[m '.slx']));
print(['-s' m],'-dpng','-r160',fullfile(outdir,'thermal_model.png'));
print(['-s' m '/Conventional Cauer ladder'],'-dpng','-r160',fullfile(outdir,'cauer_subsystem.png'));
end

function add_ladder(s,pos)
add_block('simulink/Ports & Subsystems/Subsystem',s,'Position',pos);
delete_line(s,'In1/1','Out1/1');set_param([s '/In1'],'Name','Power_W','Position',[20 130 45 150]);
set_param([s '/Out1'],'Name','Node_rises_K','Position',[805 165 835 185]);
for k=1:4
 x=105+(k-1)*165;
 add_block('simulink/Math Operations/Sum',[s '/C' num2str(k) ' heat balance'], ...
 'Inputs','+-','Position',[x 125 x+25 160]);
 add_block('simulink/Math Operations/Gain',[s '/1 over C' num2str(k)], ...
 'Gain',['1/C(' num2str(k) ')'],'Position',[x+35 125 x+90 160]);
 add_block('simulink/Continuous/Integrator',[s '/T' num2str(k)], ...
 'InitialCondition','0','Position',[x+45 195 x+85 230]);
 add_line(s,['C' num2str(k) ' heat balance/1'],['1 over C' num2str(k) '/1']);
 add_line(s,['1 over C' num2str(k) '/1'],['T' num2str(k) '/1'],'autorouting','on');
end

add_line(s,'Power_W/1','C1 heat balance/1');
for k=1:3
 x=150+(k-1)*165;
 add_block('simulink/Math Operations/Sum',[s '/T' num2str(k) ' minus T' num2str(k+1)], ...
 'Inputs','+-','Position',[x 280 x+25 315]);
 add_block('simulink/Math Operations/Gain',[s '/R' num2str(k) ' heat flow'], ...
 'Gain',['1/R(' num2str(k) ')'],'Position',[x+40 280 x+95 315]);
 add_line(s,['T' num2str(k) '/1'],['T' num2str(k) ' minus T' num2str(k+1) '/1'],'autorouting','on');
 add_line(s,['T' num2str(k+1) '/1'],['T' num2str(k) ' minus T' num2str(k+1) '/2'],'autorouting','on');
 add_line(s,['T' num2str(k) ' minus T' num2str(k+1) '/1'],['R' num2str(k) ' heat flow/1']);
 add_line(s,['R' num2str(k) ' heat flow/1'],['C' num2str(k) ' heat balance/2'],'autorouting','on');
 add_line(s,['R' num2str(k) ' heat flow/1'],['C' num2str(k+1) ' heat balance/1'],'autorouting','on');
end
add_block('simulink/Math Operations/Gain',[s '/R4 to fixed case'],'Gain','1/R(4)','Position',[645 280 730 315]);
add_line(s,'T4/1','R4 to fixed case/1','autorouting','on');add_line(s,'R4 to fixed case/1','C4 heat balance/2','autorouting','on');
add_block('simulink/Signal Routing/Mux',[s '/Four node temperatures'],'Inputs','4','Position',[750 90 755 255]);
for k=1:4;add_line(s,['T' num2str(k) '/1'],['Four node temperatures/' num2str(k)],'autorouting','on');end
add_line(s,'Four node temperatures/1','Node_rises_K/1');
add_note(s,'Each integrator represents a physical thermal capacitance.\nHeat currents through R1-R3 enter one node and leave its neighbour.',[45 15 720 60]);
end

function polish_models(outdir)
m='GaN_Full_Bridge_SPS';
s=[m '/Gate sequencing'];
set_param(s,'Mask','on','MaskDisplay', ...
 ['disp(''Gate sequencing'');port_label(''input'',1,''t'');' ...
 'port_label(''output'',1,''HS1'');port_label(''output'',2,''HS2'');' ...
 'port_label(''output'',3,''DUT'');port_label(''output'',4,''LS1'');port_label(''output'',5,''LS2'');']);
gates={'HS1','HS2','DUT','LS1','LS2'};places=[445 70;865 70;575 260;445 260;865 260];
for k=1:5
 delete_line(m,['Gate sequencing/' num2str(k)],[gates{k} '/1']);
 add_block('simulink/Signal Routing/Goto',[m '/command_' gates{k}],'GotoTag',['g_' gates{k}], ...
  'Position',[275 105+42*(k-1) 325 125+42*(k-1)],'ShowName','off');
 add_line(m,['Gate sequencing/' num2str(k)],['command_' gates{k} '/1'],'autorouting','on');
 x=places(k,1);y=places(k,2);
 add_block('simulink/Signal Routing/From',[m '/gate_' gates{k}],'GotoTag',['g_' gates{k}], ...
  'Position',[x y x+65 y+20],'ShowName','off');
 add_line(m,['gate_' gates{k} '/1'],[gates{k} '/1'],'autorouting','on');
 set_param([m '/' gates{k} '_measurement_unused'],'ShowName','off');
end
blocks=find_system(m,'SearchDepth',1,'Type','Block');
for k=1:numel(blocks);set_param(blocks{k},'FontSize','10');end
set_param(m,'ZoomFactor','FitSystem');save_system(m,fullfile(outdir,[m '.slx']));
print(['-s' m],'-dpng','-r160',fullfile(outdir,'full_bridge_model.png'));
m='GaN_Cauer_Figure14';types={'Conventional','Proposed'};
for k=1:2
 set_param([m '/' types{k} ' current squared'],'ShowName','off');
 set_param([m '/' types{k} ' Ron 80mOhm'],'ShowName','off');
 set_param([m '/' types{k} ' current'],'Mask','on','MaskDisplay','disp(''I_D(t)'')');
 s=[m '/' types{k} ' Cauer ladder'];
 set_param(s,'Mask','on','MaskDisplay','disp(''4-stage Cauer'');port_label(''input'',1,''P(W)'');port_label(''output'',1,''dT1..4(K)'');');
 for j=1:4
  set_param([s '/C' num2str(j) ' heat balance'],'ShowName','off');
  set_param([s '/1 over C' num2str(j)],'ShowName','off');
  if j<4
   set_param([s '/T' num2str(j) ' minus T' num2str(j+1)],'ShowName','off');
   set_param([s '/R' num2str(j) ' heat flow'],'ShowName','off');
   add_note(s,sprintf('q%d = (T%d-T%d)/R%d',j,j,j+1,j),[145+(j-1)*165 340 290+(j-1)*165 362]);
  end
 end
 set_param([s '/Four node temperatures'],'ShowName','off');
 set_param([s '/R4 to fixed case'],'ShowName','off');
 add_note(s,'q4 = T4/R4',[645 340 775 362]);
end
set_param(m,'ZoomFactor','FitSystem');save_system(m,fullfile(outdir,[m '.slx']));
print(['-s' m],'-dpng','-r160',fullfile(outdir,'thermal_model.png'));
print(['-s' m '/Conventional Cauer ladder'],'-dpng','-r160',fullfile(outdir,'cauer_subsystem.png'));
end

function run_bridge_cases(outdir)
m='GaN_Full_Bridge_SPS';load_system(fullfile(outdir,[m '.slx']));
w=get_param(m,'ModelWorkspace');baseline=evalin(w,'p');
metrics=struct();cases={};
for direction=[1,-1]
 for current=[10,30,50]
  p=baseline;p.direction=direction;p.Tcharge=p.L*current/p.VDC;
  if direction<0;p.Tfree=0;end
  label=sprintf('%s_%02dA',choose(direction>0,'positive','negative'),current);
  result=simulate_bridge(m,p,55e-6);
  save_case(result,p,label,outdir);
  cases{end+1}=case_metrics(result,p,label); %#ok<AGROW>
 end
end
for idleUpper=[0,1]
 p=baseline;p.idleUpper=idleUpper;
 label=sprintf('idle_%s',choose(idleUpper>0,'upper','lower'));
 result=simulate_bridge(m,p,5e-3);save_case(result,p,label,outdir);
 item=case_metrics(result,p,label);item.terminalVds_V=result.Vds(end);item.terminalInductor_A=result.iL(end);
 item.expectedIdleVds_V=choose(idleUpper>0,result.Vbus(end),0);
 item.idleVdsError_V=abs(item.terminalVds_V-item.expectedIdleVds_V);cases{end+1}=item;
end
for conventional=[0,1]
 p=baseline;p.conventional=conventional;
 label=choose(conventional>0,'baseline_conventional','baseline_proposed');
 result=simulate_bridge(m,p,55e-6);save_case(result,p,label,outdir);
 item=case_metrics(result,p,label);
  root=fileparts(fileparts(outdir));
 reference=fullfile(root,'reproduction','data',[choose(conventional>0,'conventional','proposed') '_waveforms.csv']);
 if isfile(reference)
  lt=readtable(reference);win=result.time_s>35.7e-6&result.time_s<40.3e-6;
  fieldnamesLT=lt.Properties.VariableNames;item.ltspiceCSVColumns=fieldnamesLT;
  if ismember('inductor_current_A',fieldnamesLT)
   il=interp1(lt.time_s,lt.inductor_current_A,result.time_s(win));
   item.ltspicePlateauCurrentRmsError_A=sqrt(mean((-result.iL(win)-il).^2));
   item.ltspicePlateauCurrentRmsRelativeError_percent=100*item.ltspicePlateauCurrentRmsError_A/sqrt(mean(il.^2));
  end
 end
 cases{end+1}=item;
end
in=Simulink.SimulationInput(m);in=in.setVariable('p',baseline,'Workspace',m);in=in.setModelParameter('MaxStep','2.5e-9');half=sim(in);
base=load(fullfile(outdir,'baseline_proposed.mat'));
interior=base.r.time_s>3e-6&base.r.time_s<34.4e-6;
halfI=interp1(half.iL.Time,half.iL.Data,base.r.time_s(interior));
convergence=struct('solver','ode45','steps_s',[5e-9,2.5e-9], ...
 'chargingCurrentMaximumDifference_A',max(abs(base.r.iL(interior)-halfI)), ...
 'coarseChargeEnd_A',interp1(base.r.time_s,base.r.iL,34.49e-6), ...
 'fineChargeEnd_A',interp1(half.iL.Time,half.iL.Data,34.49e-6), ...
 'comment','ode23tb/ode15s produced inaccurate SPS switching results in this model; accepted ode45 also agrees with ode23t and closed-form RLC solution.');
write_json(fullfile(outdir,'solver_convergence.json'),convergence);
metrics=struct('model','GaN_Full_Bridge_SPS.slx','tool','Simscape Electrical Specialized Power Systems', ...
 'cases',{cases},'assumptions',{{'Fixed Ron80mOhm for all switches; shunt10mOhm.', ...
 'No manufacturer nonlinear GaN model, Coss, deadtime, or gate dynamics.', ...
 'Inductor series resistance explicitly1mOhm, matching the existing LTspice default measured from RAW; not specified by the paper.', ...
 'Finite initial-voltage500uF bus capacitor; no stiff DC supply.', ...
 'Ideal simultaneous gate transitions intentionally compare conduction plateaus.'}});
write_json(fullfile(outdir,'electrical_metrics.json'),metrics);
plot_bridge(outdir);
save_system(m);close_system(m,0);
end

function r=simulate_bridge(m,p,stop)
in=Simulink.SimulationInput(m);in=in.setVariable('p',p,'Workspace',m);
in=in.setModelParameter('StopTime',num2str(stop,17));
o=sim(in);
t=o.iL.Time;r=struct('time_s',t,'iL',o.iL.Data,'iD',interp1(o.iD.Time,o.iD.Data,t), ...
 'Vbus',interp1(o.Vbus.Time,o.Vbus.Data,t),'Vds',interp1(o.Vds.Time,o.Vds.Data,t));
end

function save_case(r,p,label,outdir)
% Retain microsecond switching detail but decimate long idle output only.
if r.time_s(end)>1e-3
 keep=r.time_s<=55e-6;long=find(r.time_s>55e-6);keep(long(1:200:end))=true;keep(end)=true;
 fields=fieldnames(r);for k=1:numel(fields);r.(fields{k})=r.(fields{k})(keep);end
end
T=table(r.time_s,r.iL,r.iD,r.Vbus,r.Vds,'VariableNames', ...
 {'time_s','inductor_left_to_right_A','dut_drain_to_source_A','bus_voltage_V','dut_Vds_V'});
writetable(T,fullfile(outdir,[label '.csv']));save(fullfile(outdir,[label '.mat']),'r','p');
end

function item=case_metrics(r,p,label)
ta=p.T0;tb=ta+p.Tcharge;tc=tb+p.Tfree;td=tc+p.Tmeasure;
win=r.time_s>tc+100e-9&r.time_s<td-100e-9;charge=r.time_s>ta+100e-9&r.time_s<tb-100e-9;
item=struct('label',label,'targetCurrent_A',p.direction*p.VDC*p.Tcharge/p.L, ...
 'meanDUTMeasurementCurrent_A',mean(r.iD(win)), ...
 'meanMeasuredRon_Ohm',mean(r.Vds(win)./r.iD(win)), ...
 'rmsDUTChargingCurrent_A',sqrt(mean(r.iD(charge).^2)), ...
 'idealChargeEndInductor_A',-p.direction*p.VDC*p.Tcharge/p.L, ...
 'chargeEndInductor_A',interp1(r.time_s,r.iL,tb-10e-9), ...
 'initialBus_V',r.Vbus(1),'finalBus_V',r.Vbus(end),'tcharge_s',p.Tcharge, ...
 'terminalVds_V',NaN,'terminalInductor_A',NaN,'expectedIdleVds_V',NaN,'idleVdsError_V',NaN, ...
 'ltspiceCSVColumns',{{}},'ltspicePlateauCurrentRmsError_A',NaN, ...
 'ltspicePlateauCurrentRmsRelativeError_percent',NaN);
if p.direction>0 && p.conventional>0;Rcharge=p.Raux+p.Rdut+p.Rload+p.Rshunt;else;Rcharge=2*p.Raux+p.Rload;end
physical=[-Rcharge/p.L,1/p.L;-1/p.Cdc,0];x=expm(physical*(p.Tcharge-10e-9))*[0;p.VDC];
item.analyticChargeEndInductor_A=-p.direction*x(1);
item.analyticChargeEndCurrentError_A=abs(item.chargeEndInductor_A-item.analyticChargeEndInductor_A);
loopR=(2*p.Raux+p.Rload)*ones(size(r.time_s));
measureFull=r.time_s>=tc&r.time_s<td;chargeFull=r.time_s>=ta&r.time_s<tb;
loopR(measureFull)=p.Raux+p.Rdut+p.Rload+p.Rshunt;
if p.direction>0 && p.conventional>0;loopR(chargeFull)=Rcharge;end
item.energyResidual_J=0.5*p.Cdc*(r.Vbus(1)^2-r.Vbus(end)^2)-0.5*p.L*r.iL(end)^2-trapz(r.time_s,loopR.*r.iL.^2);
end

function plot_bridge(outdir)
f=figure('Visible','off','Color','w','Position',[100 100 1200 850]);
tl=tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
for direction=[1,-1]
 for current=[10,30,50]
  d=load(fullfile(outdir,sprintf('%s_%02dA.mat',choose(direction>0,'positive','negative'),current)));
  nexttile;plot(d.r.time_s*1e6,d.r.iD,'LineWidth',1.5);hold on;plot(d.r.time_s*1e6,-d.r.iL,'--','LineWidth',1);
  grid on;xlim([0,45]);xlabel('Time (us)');ylabel('Current (A)');
  title(sprintf('%s %d A procedure',choose(direction>0,'Positive','Negative'),current));legend('DUT','-I_L','Location','best');
 end
end
title(tl,'Simscape Electrical full bridge: Figure 2 and Figure 3 procedures');
savefig(f,fullfile(outdir,'signed_current_procedures.fig'));exportgraphics(f,fullfile(outdir,'signed_current_procedures.png'),'Resolution',160);close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1200 700]);tl=tiledlayout(2,2);
for upper=[1,0]
 d=load(fullfile(outdir,['idle_' choose(upper>0,'upper','lower') '.mat']));
 nexttile;plot(d.r.time_s*1e3,d.r.Vds,'LineWidth',1.3);hold on;plot(d.r.time_s*1e3,d.r.Vbus,'--');grid on;
 title([choose(upper>0,'Upper','Lower') ' idle: DUT voltage']);xlabel('Time (ms)');ylabel('Voltage (V)');legend('DUT Vds','Vbus');
 nexttile;plot(d.r.time_s*1e3,d.r.iD);hold on;plot(d.r.time_s*1e3,d.r.iL);grid on;title([choose(upper>0,'Upper','Lower') ' idle: inductor discharge']);xlabel('Time (ms)');ylabel('Current (A)');legend('DUT','I_L');
end
title(tl,'Figure 4 idle-state stress and discharge');savefig(f,fullfile(outdir,'idle_states.fig'));exportgraphics(f,fullfile(outdir,'idle_states.png'),'Resolution',160);close(f);
end

function run_thermal(outdir)
m='GaN_Cauer_Figure14';load_system(fullfile(outdir,[m '.slx']));o=sim(m);
t=o.conventionalT.Time;A=o.conventionalT.Data;B=interp1(o.proposedT.Time,o.proposedT.Data,t);
T=table(t,A(:,1),B(:,1),'VariableNames',{'time_s','conventional_deltaTj_K','proposed_deltaTj_K'});
writetable(T,fullfile(outdir,'figure14_simulink.csv'));save(fullfile(outdir,'figure14_simulink.mat'),'t','A','B');
ta=33.5e-6;tb=38.5e-6;tw=unique([t(t>ta&t<tb);ta;tb]);
avga=trapz(tw,interp1(t,A(:,1),tw))/(tb-ta);avgb=trapz(tw,interp1(t,B(:,1),tw))/(tb-ta);
metrics=struct('model',[m '.slx'],'meanConventional_K',avga,'meanProposed_K',avgb, ...
 'meanReduction_percent',100*(1-avgb/avga),'peakConventional_K',max(A(:,1)), ...
 'peakProposed_K',max(B(:,1)),'paperPrintedMeans_K',[4.7,1.8], ...
 'paperPrintedReduction_percent',62,'zeroInitialRise',true, ...
 'measurementWindow_us',[33.5,38.5],'topology','Four-capacitance Cauer ladder; R4 to fixed case', ...
 'R_K_per_W',[.015,.23,.24,.015],'C_J_per_K',[8e-5,7.4e-4,6.5e-3,2e-3]);
root=fileparts(fileparts(outdir));
ref=fullfile(root,'reproduction','matlab','figure14_input_reconstruction','thermal_waveforms.csv');
if isfile(ref)
 d=readtable(ref);selection=t>=d.time_s(1)&t<=d.time_s(end);
 ra=interp1(d.time_s,d.conventional_deltaTj_K,t(selection));rb=interp1(d.time_s,d.proposed_deltaTj_K,t(selection));
 metrics.matlabExactReferenceMaxError_K=[max(abs(A(selection,1)-ra)),max(abs(B(selection,1)-rb))];
end
write_json(fullfile(outdir,'thermal_metrics.json'),metrics);
f=figure('Visible','off','Color','w','Position',[100 100 1150 650]);
plot(t*1e6,A(:,1),'LineWidth',1.6);hold on;plot(t*1e6,B(:,1),'LineWidth',1.6);ylabel('Junction temperature rise (K)');
xline(ta*1e6,'k:');xline(tb*1e6,'k:');grid on;xlabel('Time (us)');xlim([-5,45]);
title('Native Simulink Cauer ladder: Figure 14 reconstructed input');
legend('Conventional','Proposed','Measurement start','Measurement end','Location','northwest');
savefig(f,fullfile(outdir,'figure14_simulink.fig'));exportgraphics(f,fullfile(outdir,'figure14_simulink.png'),'Resolution',180);close(f);
close_system(m,0);
end

function p=getport(b,side,index);h=get_param(b,'PortHandles');p=h.(side)(index);end
function connect(m,a,b);add_line(m,a,b,'autorouting','on');end
function add_note(m,text,pos);a=Simulink.Annotation(m,strrep(text,'\n',newline));a.Position=pos;end
function v=choose(condition,a,b);if condition;v=a;else;v=b;end;end
function write_json(file,value);f=fopen(file,'w','n','UTF-8');fprintf(f,'%s\n',jsonencode(value,'PrettyPrint',true));fclose(f);end
