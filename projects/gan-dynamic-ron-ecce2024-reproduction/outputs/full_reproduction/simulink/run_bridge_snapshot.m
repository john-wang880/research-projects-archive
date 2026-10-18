function result=run_bridge_snapshot(config)
%RUN_BRIDGE_SNAPSHOT Simulate a current/stress/Ron snapshot using native SLX.
% config may contain Rdut,Raux [Ohm], VDC [V], targetCurrent_A [A],
% Tcharge,Tfree,Tmeasure,T0,MaxStep,conventional,idleUpper and StopTime [s].
% No plotted waveform or CSV is used as a simulated electrical input.
outdir=fileparts(mfilename('fullpath'));m='GaN_Full_Bridge_SPS';
load_system(fullfile(outdir,[m '.slx']));w=get_param(m,'ModelWorkspace');p=evalin(w,'p');
if nargin<1;config=struct();end
fields=fieldnames(config);
for k=1:numel(fields);if isfield(p,fields{k});p.(fields{k})=config.(fields{k});end;end
if isfield(config,'targetCurrent_A')
 p.direction=sign(config.targetCurrent_A);
 assert(p.direction~=0,'Target current cannot be zero.');
 p.Tcharge=p.L*abs(config.targetCurrent_A)/p.VDC;
 if p.direction<0 && ~isfield(config,'Tfree');p.Tfree=0;end
end
assert(p.Rdut>0 && p.Raux>0 && p.VDC>0 && p.L>0 && p.Cdc>0,'Invalid physical parameter.');
measurementStart=p.T0+p.Tcharge+p.Tfree;measurementEnd=measurementStart+p.Tmeasure;
stop=max(55e-6,measurementEnd+10e-6);if isfield(config,'StopTime');stop=config.StopTime;end
in=Simulink.SimulationInput(m);in=in.setVariable('p',p,'Workspace',m);in=in.setModelParameter('StopTime',num2str(stop,17));
if isfield(config,'MaxStep');in=in.setModelParameter('MaxStep',num2str(config.MaxStep,17));end
o=sim(in);t=o.iD.Time;iD=o.iD.Data;Vds=interp1(o.Vds.Time,o.Vds.Data,t);
win=t>measurementStart+100e-9&t<measurementEnd-100e-9;
result=struct('time_s',t,'dut_current_A',iD, ...
 'inductor_left_to_right_A',interp1(o.iL.Time,o.iL.Data,t), ...
 'bus_voltage_V',interp1(o.Vbus.Time,o.Vbus.Data,t),'dut_Vds_V',Vds, ...
 'dut_conduction_power_W',iD.^2*p.Rdut,'parameters',p, ...
 'measurementWindow_s',[measurementStart,measurementEnd], ...
 'measuredRon_Ohm',mean(Vds(win)./iD(win)), ...
 'meanMeasurementCurrent_A',mean(iD(win)), ...
 'model','GaN_Full_Bridge_SPS.slx','inputDefinition','Native switched electrical network, no waveform replay');
close_system(m,0);
end
