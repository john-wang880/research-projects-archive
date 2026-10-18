function build_run_tec(modes)
% Native Simscape electrothermal circuit with a real Peltier conserving-port block.
% Figure 7 public architecture, representative controller/LC/thermal assumptions.
out=fileparts(mfilename('fullpath'));cd(out);if nargin<1,modes=[0 1];end
p=[24,0.8,(8.4+0.5*0.8*3.7^2)/(298.15*3.7),0,4.5,0.02,3.0,3.6,0.25,0.012,0.2,500];
p(4)=(p(3)*226.15*3.7-0.5*p(2)*3.7^2)/72;
for switching=modes
 if switching, m='TEC_DualBuck_PWM';stop=0.03;maxstep=2e-7;else,m='TEC_Electrothermal_ClosedLoop';stop=2400;maxstep=1;end
 if bdIsLoaded(m),close_system(m,0);end;new_system(m);
 if switching,solver='ode23t';else,solver='ode15s';end
 set_param(m,'Solver',solver,'RelTol','1e-6','AbsTol','1e-8','StopTime',num2str(stop),'MaxStep',num2str(maxstep),'ReturnWorkspaceOutputs','on');
 mw=get_param(m,'ModelWorkspace');mw.assignin('TEC_parameters',p);mw.assignin('switching_mode',switching);
 b={sprintf('ee_lib/Sensors &\nTransducers/Peltier Device'),'Peltier',[720 230 810 340];...
 'fl_lib/Electrical/Electrical Sources/Controlled Voltage Source','BuckA',[390 190 445 245];...
 'fl_lib/Electrical/Electrical Sources/Controlled Voltage Source','BuckB',[390 385 445 440];...
 'fl_lib/Electrical/Electrical Sensors/Current Sensor','Current',[610 200 665 255];...
 'fl_lib/Thermal/Thermal Sensors/Temperature Sensor','Temperature',[890 100 945 155];...
 'fl_lib/Thermal/Thermal Elements/Thermal Mass','Case_Mass',[920 215 980 265];...
 'fl_lib/Thermal/Thermal Elements/Conductive Heat Transfer','Insulation_Leak',[1030 215 1100 265];...
 'fl_lib/Thermal/Thermal Sources/Temperature Source','Fixed_25C_Heatsink',[890 335 980 380];...
 'fl_lib/Electrical/Electrical Elements/Inductor','LA',[485 205 560 245];...
 'fl_lib/Electrical/Electrical Elements/Inductor','LB',[485 380 560 420];...
 'fl_lib/Electrical/Electrical Elements/Capacitor','CA',[585 295 640 335];...
 'fl_lib/Electrical/Electrical Elements/Capacitor','CB',[665 400 720 440];...
 'fl_lib/Electrical/Electrical Elements/Electrical Reference','Ground',[490 475 535 500];...
 sprintf('nesl_utility/Solver\nConfiguration'),'Solver',[365 475 430 510];...
 sprintf('nesl_utility/Simulink-PS\nConverter'),'SPS_A',[275 190 320 225];...
 sprintf('nesl_utility/Simulink-PS\nConverter'),'SPS_B',[275 385 320 420];...
 sprintf('nesl_utility/PS-Simulink\nConverter'),'PS_I',[655 135 700 170];...
 sprintf('nesl_utility/PS-Simulink\nConverter'),'PS_T',[975 95 1020 130];...
 'fl_lib/Thermal/Thermal Elements/Thermal Reference','ThermalRef',[1010 335 1055 370]};
 if ~switching,b(ismember(b(:,2),{'CA','CB'}),:)=[];end
 for k=1:size(b,1),add_block(b{k,1},[m '/' b{k,2}],'Position',b{k,3});end
 if switching
  set_param(m,'SolverType','Fixed-step','Solver','ode3','FixedStep','1e-7');
  set_param([m '/Solver'],'UseLocalSolver','on','LocalSolverSampleTime','1e-7','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER');
 end
 set_param([m '/Peltier'],'alpha','TEC_parameters(3)','R','TEC_parameters(2)','K','TEC_parameters(4)');
 set_param([m '/Case_Mass'],'mass','0.005','sp_heat','900','T_specify','on','T_priority','High','T','298.15');
 set_param([m '/Fixed_25C_Heatsink'],'temperature','298.15');
 set_param([m '/Insulation_Leak'],'area','0.001','thickness','0.05','th_cond','1');
 for x={'LA','LB'},set_param([m '/' x{1}],'l','220e-6','r','0.03');end
 if switching,for x={'CA','CB'},set_param([m '/' x{1}],'c','10e-6','r','0.1','v_specify','off','vc_specify','on','vc_priority','High','vc','12');end;end
 for x={'SPS_A','SPS_B'},set_param([m '/' x{1}],'Unit','V','FilteringAndDerivatives','zero');end
 set_param([m '/PS_I'],'Unit','A');set_param([m '/PS_T'],'Unit','K');
 % Electrical differential two-buck output network; both legs referenced to ground.
 con(m,'BuckA','LConn',1,'LA','LConn',1);con(m,'LA','RConn',1,'Current','LConn',1);
 con(m,'Current','RConn',2,'Peltier','LConn',1);con(m,'Peltier','LConn',2,'LB','RConn',1);
 con(m,'BuckB','LConn',1,'LB','LConn',1);if switching,con(m,'CA','LConn',1,'LA','RConn',1);con(m,'CB','LConn',1,'LB','RConn',1);end
 for x={'BuckA','BuckB'},con(m,x{1},'RConn',2,'Ground','LConn',1);end
 if switching,for x={'CA','CB'},con(m,x{1},'RConn',1,'Ground','LConn',1);end;end
 con(m,'Solver','RConn',1,'Ground','LConn',1);
 con(m,'SPS_A','RConn',1,'BuckA','RConn',1);con(m,'SPS_B','RConn',1,'BuckB','RConn',1);
 con(m,'Current','RConn',1,'PS_I','LConn',1);
 % Peltier port A is the DUT case; port B is an explicitly ideal heat sink.
 con(m,'Peltier','RConn',1,'Case_Mass','LConn',1);con(m,'Case_Mass','LConn',1,'Insulation_Leak','LConn',1);
 con(m,'Insulation_Leak','RConn',1,'Fixed_25C_Heatsink','LConn',1);con(m,'Peltier','RConn',2,'Fixed_25C_Heatsink','LConn',1);
 con(m,'Temperature','LConn',1,'Case_Mass','LConn',1);con(m,'Temperature','RConn',1,'ThermalRef','LConn',1);con(m,'Temperature','RConn',2,'PS_T','LConn',1);
 add_block('simulink/Sources/Clock',[m '/Time'],'Position',[25 35 55 65]);
 add_block('simulink/Sources/Constant',[m '/Parameters'],'Value','TEC_parameters','Position',[25 590 115 625]);
 add_block('simulink/Sources/Constant',[m '/Switching_Mode'],'Value','switching_mode','Position',[25 650 115 680]);
 add_block('simulink/Continuous/Integrator',[m '/Outer_PI_State'],'InitialCondition','0','Position',[170 540 210 580]);
 add_block('simulink/Continuous/Integrator',[m '/Inner_PI_State'],'InitialCondition','0','Position',[290 540 330 580]);
 add_block('simulink/User-Defined Functions/MATLAB Function',[m '/Cascaded_PI_and_PWM'],'Position',[45 270 230 360]);
 rt=sfroot;ch=rt.find('-isa','Stateflow.EMChart','Path',[m '/Cascaded_PI_and_PWM']);
 ch.Script=sprintf(['function [va,vb,ztd,zid,iref,target,vcmd,d1,d2]=control(t,T,I,zT,zI,p,sw,ref)\n'...
 'if sw>0.5\n target=25;iref=ref;ztd=0;\n'...
 'else\n target=ref;\n'...
 'errT=T-273.15-target; iraw=p(9)*errT+zT;iref=min(p(7),max(-p(7),iraw));ztd=p(10)*errT+0.3*(iref-iraw);\nend\n'...
 'errI=iref-I;vraw=(p(2)+0.06)*iref+p(3)*(298.15-T)+p(11)*errI+zI;vcmd=min(p(8),max(-p(8),vraw));zid=p(12)*errI+100*(vcmd-vraw);\n'...
 'd1=0.5+vcmd/(2*p(1));d2=0.5-vcmd/(2*p(1));\n'...
 'if sw>0.5\n carrier=mod(t*20000,1);va=p(1)*double(carrier<d1);vb=p(1)*double(carrier<d2);\nelse\n va=p(1)*d1;vb=p(1)*d2;\nend\nend']);
 add_line(m,'Time/1','Cascaded_PI_and_PWM/1','autorouting','on');
 add_block('simulink/Continuous/State-Space',[m '/Temperature_Sensor_Response'],'A','-100','B','100','C','1','D','0','X0','298.15','Position',[1040 40 1120 75]);
 add_block('simulink/Continuous/State-Space',[m '/Current_Sensor_Response'],'A','-1e5','B','1e5','C','1','D','0','X0','0','Position',[535 95 605 130]);
 add_line(m,'PS_T/1','Temperature_Sensor_Response/1','autorouting','on');add_line(m,'PS_I/1','Current_Sensor_Response/1','autorouting','on');
 if switching
  add_block('simulink/Sources/Step',[m '/Reference'],'Time','0.015','Before','1','After','-1','Position',[25 700 80 730]);
 else
  add_block('simulink/Sources/Constant',[m '/Reference_Initial'],'Value','15','Position',[25 710 80 740]);
  vals=[600 40;1200 -70;1800 110];for j=1:3,add_block('simulink/Sources/Step',[m '/Reference_Step' num2str(j)],'Time',num2str(vals(j,1)),'Before','0','After',num2str(vals(j,2)),'Position',[120*j 710 120*j+50 740]);end
  add_block('simulink/Math Operations/Sum',[m '/Reference'],'Inputs','++++','Position',[500 710 530 790]);add_line(m,'Reference_Initial/1','Reference/1');for j=1:3,add_line(m,['Reference_Step' num2str(j) '/1'],['Reference/' num2str(j+1)]);end
 end
 add_line(m,'Reference/1','Cascaded_PI_and_PWM/8','autorouting','on');
 if switching
  add_block('simulink/Discrete/Zero-Order Hold',[m '/Sampled_Current'],'SampleTime','50e-6','Position',[460 110 515 145]);
  add_block('simulink/Discrete/Zero-Order Hold',[m '/Sampled_Temperature'],'SampleTime','50e-6','Position',[1070 100 1130 135]);
  add_line(m,'Temperature_Sensor_Response/1','Sampled_Temperature/1','autorouting','on');add_line(m,'Sampled_Temperature/1','Cascaded_PI_and_PWM/2','autorouting','on');
  add_line(m,'Current_Sensor_Response/1','Sampled_Current/1','autorouting','on');add_line(m,'Sampled_Current/1','Cascaded_PI_and_PWM/3','autorouting','on');
 else
  add_line(m,'Temperature_Sensor_Response/1','Cascaded_PI_and_PWM/2','autorouting','on');add_line(m,'Current_Sensor_Response/1','Cascaded_PI_and_PWM/3','autorouting','on');
 end
 add_line(m,'Outer_PI_State/1','Cascaded_PI_and_PWM/4','autorouting','on');add_line(m,'Inner_PI_State/1','Cascaded_PI_and_PWM/5','autorouting','on');add_line(m,'Parameters/1','Cascaded_PI_and_PWM/6','autorouting','on');add_line(m,'Switching_Mode/1','Cascaded_PI_and_PWM/7','autorouting','on');
 add_line(m,'Cascaded_PI_and_PWM/1','SPS_A/1','autorouting','on');add_line(m,'Cascaded_PI_and_PWM/2','SPS_B/1','autorouting','on');add_line(m,'Cascaded_PI_and_PWM/3','Outer_PI_State/1','autorouting','on');add_line(m,'Cascaded_PI_and_PWM/4','Inner_PI_State/1','autorouting','on');
 add_block('simulink/Signal Routing/Mux',[m '/Logged_Signals'],'Inputs','9','Position',[1200 150 1205 350]);
 src={'PS_T/1','PS_I/1','Cascaded_PI_and_PWM/5','Cascaded_PI_and_PWM/6','Cascaded_PI_and_PWM/7','Cascaded_PI_and_PWM/8','Cascaded_PI_and_PWM/9','Cascaded_PI_and_PWM/1','Cascaded_PI_and_PWM/2'};
 for k=1:9,add_line(m,src{k},['Logged_Signals/' num2str(k)],'autorouting','on');end
 add_block('simulink/Sinks/To Workspace',[m '/Results'],'VariableName','TEC_results','SaveFormat','Timeseries','Position',[1250 215 1340 255]);add_line(m,'Logged_Signals/1','Results/1');
 stageHandles=zeros(1,size(b,1));for k=1:size(b,1),stageHandles(k)=get_param([m '/' b{k,2}],'Handle');end
 Simulink.BlockDiagram.createSubsystem(stageHandles);set_param([m '/Subsystem'],'Name','Electrothermal_Power_Stage');
 controls=find_system(m,'SearchDepth',1,'Type','Block');controls=controls(~ismember(controls,{m,[m '/Electrothermal_Power_Stage'],[m '/Logged_Signals'],[m '/Results']}));
 controlHandles=cellfun(@(s)get_param(s,'Handle'),controls);Simulink.BlockDiagram.createSubsystem(controlHandles);set_param([m '/Subsystem'],'Name','Control_and_References');
 set_param([m '/Control_and_References'],'Position',[70 150 335 405]);set_param([m '/Electrothermal_Power_Stage'],'Position',[505 150 790 405]);set_param([m '/Logged_Signals'],'Position',[935 145 940 410]);set_param([m '/Results'],'Position',[1010 250 1120 290]);
 try,Simulink.BlockDiagram.arrangeSystem(m);catch,end
 a=Simulink.Annotation(m,sprintf('Figure 7 functional reproduction. Native Peltier and physical electrical network.\nSlow thermal model neglects capacitor transients; PWM model retains both LC filters.\nController, L/C, insulation and ideal heatsink are disclosed assumptions.'));a.Position=[390 30 1120 80];
 save_system(m,fullfile(out,[m '.slx']));print(['-s' m],'-dpng','-r140',fullfile(out,[m '_diagram.png']));
 print(['-s' m '/Electrothermal_Power_Stage'],'-dpng','-r140',fullfile(out,[m '_physical_network.png']));
 simout=sim(m);q=simout.TEC_results;ts=q.Time;data=q.Data;writematrix([ts,data],fullfile(out,[m '_results.csv']));save(fullfile(out,[m '_results.mat']),'ts','data','p');
 f=figure('Visible','off','Color','w','Position',[100 100 1150 900]);tiledlayout(3,1);
 if switching
  nexttile;plot(ts*1e3,data(:,2),ts*1e3,data(:,3),'--');ylabel('Current (A)');legend('Peltier current','Reference');grid on;
  nexttile;plot(ts*1e3,data(:,5));ylabel('Differential command (V)');grid on;
  nexttile;idx=ts>0.010 & ts<0.0103;plot(ts(idx)*1e3,data(idx,8:9));ylabel('Switch-node rails (V)');xlabel('Time (ms)');legend('Buck A','Buck B');grid on;
  metrics.current_positive_mean=mean(data(ts>0.010 & ts<0.014,2));metrics.current_negative_mean=mean(data(ts>0.025 & ts<0.029,2));metrics.current_positive_ripple=max(data(ts>0.010 & ts<0.014,2))-min(data(ts>0.010 & ts<0.014,2));metrics.native_pwm_ran=true;
 else
  nexttile;plot(ts,data(:,1)-273.15,ts,data(:,4),'--');ylabel('Case temperature (C)');legend('Physical Peltier case','Reference');grid on;
  nexttile;plot(ts,data(:,2:3));ylabel('TEC current (A)');legend('Measured','Reference');grid on;
  nexttile;plot(ts,data(:,5));ylabel('TEC voltage (V)');xlabel('Time (s)');grid on;
  targets=[15 55 -15 95];e=zeros(1,4);for k=1:4,sel=ts>(600*k-60)&ts<600*k;e(k)=mean(data(sel,1)-273.15)-targets(k);end
  metrics.temperature_targets_C=targets;metrics.steady_state_error_C=e;metrics.max_abs_current_A=max(abs(data(:,2)));metrics.max_abs_voltage_command_V=max(abs(data(:,5)));metrics.native_peltier_ran=true;metrics.parameters=p;
 end
 sgtitle(strrep(m,'_',' '));savefig(f,fullfile(out,[m '_plot.fig']));exportgraphics(f,fullfile(out,[m '_plot.png']),'Resolution',170);close(f);
 fid=fopen(fullfile(out,[m '_metrics.json']),'w');fwrite(fid,jsonencode(metrics));fclose(fid);
 assert(all(isfinite(data(:))));if ~switching,assert(max(abs(e))<0.1 && metrics.max_abs_current_A<3.7);else,assert(abs(metrics.current_positive_mean-1)<0.2 && abs(metrics.current_negative_mean+1)<0.2);end
 close_system(m,0);clear metrics;
end
end
function con(m,a,pa,ia,b,pb,ib)
aa=get_param([m '/' a],'PortHandles');bb=get_param([m '/' b],'PortHandles');add_line(m,aa.(pa)(ia),bb.(pb)(ib),'autorouting','on');
end
