function build_wide_clamp_simulink
% Fig.5 public-topology Coss/TVS/shunt state model, native editable Simulink.
% Reduced analog physics: not authors' unspecified BOM or fitted Fig.6 delay.
out=fileparts(mfilename('fullpath')); cd(out);
mdl='GaN_Clamp_Wide_Range_Analog_State';
load_system('simulink');
if bdIsLoaded(mdl),close_system(mdl,0);end
new_system(mdl);
set_param(mdl,'Solver','ode15s','RelTol','1e-7','AbsTol','1e-9','MaxStep','5e-10','StopTime','3e-6','ReturnWorkspaceOutputs','on');
names={'wide_50V_negative','wide_50V_positive','wide_150V_negative','wide_150V_positive','wide_400V_negative','wide_400V_positive'};
bus=[50 50 150 150 400 400];signs=[-1 1 -1 1 -1 1];
tt=(0:1e-10:3e-6)';
gate_block=interp1([0 1.05e-6 1.06e-6 1.94e-6 1.95e-6 3e-6],[0 0 10 10 0 0],tt);
gate_btb=interp1([0 0.93e-6 0.94e-6 2.04e-6 2.05e-6 3e-6],[4.5 4.5 0 0 4.5 4.5],tt);
mw=get_param(mdl,'ModelWorkspace');
for k=1:6
 name=names{k};y=65+(k-1)*275;
 sign_value=signs(k);VBUS=bus(k);VON=sign_value*5;
 vi=interp1([0 1e-6 1.02e-6 2e-6 2.02e-6 3e-6],[VBUS VBUS VON VON VBUS VBUS],tt);
 dvi=zeros(size(tt));dvi(tt>=1e-6 & tt<1.02e-6)=(VON-VBUS)/20e-9;dvi(tt>=2e-6 & tt<2.02e-6)=(VBUS-VON)/20e-9;
 gb=gate_btb;
 assignin(mw,['v_' name],[tt vi]);assignin(mw,['dv_' name],[tt dvi]);assignin(mw,['gb_' name],[tt gate_block]);assignin(mw,['btb_' name],[tt gb]);
 vars={['v_' name],['dv_' name],['gb_' name],['btb_' name]};
 for j=1:4
  bn=[name '_input' num2str(j)];add_block('simulink/Sources/From Workspace',[mdl '/' bn],'VariableName',vars{j},'Position',[30 y+45*(j-1) 155 y+20+45*(j-1)]);
 end
 add_block('simulink/Continuous/State-Space',[mdl '/' name '_blocking_gate'],'A','-1/1.88e-9','B','1/1.88e-9','C','1','D','0','X0','0','Position',[195 y+80 270 y+115]);
 add_block('simulink/Continuous/State-Space',[mdl '/' name '_BTB_gates'],'A','-1/0.26e-9','B','1/0.26e-9','C','1','D','0','X0',num2str(gb(1)),'Position',[195 y+130 270 y+165]);
 add_block('simulink/Signal Routing/Mux',[mdl '/' name '_mux'],'Inputs','5','Position',[315 y 320 y+170]);
 % u=[Vin,dVin/dt,Vgs_blocking,Vgs_BTB,Vout]. Kirchhoff-current balance.
 % Coss=11pF, Cprobe=14pF, PCB=5pF, TVS=3pF, two BTB Coss series=13pF.
 expr='(11e-12*u(2)+(1e-9+(abs((u(3)-4.662)/5.338)-abs((u(3)-4.662)/5.338-1)+1)/2/11)*(u(1)-u(5))-(abs((u(4)-0.6118)/3.8882)-abs((u(4)-0.6118)/3.8882-1)+1)/2/0.122*u(5)-u(5)/1e6-((u(5)-8+abs(u(5)-8))/2-(-u(5)-8+abs(-u(5)-8))/2)/0.29-(u(5)-u(1)-0.7+abs(u(5)-u(1)-0.7))/2/0.35)/46e-12';
 add_block('simulink/User-Defined Functions/Fcn',[mdl '/' name '_Kirchhoff'],'Expr',expr,'Position',[360 y+45 545 y+90]);
 add_block('simulink/Continuous/Integrator',[mdl '/' name '_Vout'],'InitialCondition','0','Position',[585 y+45 625 y+90]);
 add_block('simulink/Continuous/Transfer Fcn',[mdl '/' name '_20MHz'],'Numerator','1','Denominator','[1/(2*pi*20e6) 1]','Position',[675 y+45 765 y+90]);
 fspan=12;
 add_block('simulink/Discontinuities/Saturation',[mdl '/' name '_ADC_range'],'UpperLimit',num2str(fspan/2),'LowerLimit',num2str(-fspan/2),'Position',[790 y+45 820 y+90]);
 add_block('simulink/Discontinuities/Quantizer',[mdl '/' name '_ADC12bit'],'QuantizationInterval',num2str(fspan/4096,17),'Position',[850 y+45 910 y+90]);
 add_block('simulink/Sinks/To Workspace',[mdl '/' name '_analog_log'],'VariableName',[name '_analog'],'SaveFormat','Timeseries','Position',[675 y+125 810 y+155]);
 add_block('simulink/Sinks/To Workspace',[mdl '/' name '_ADC_log'],'VariableName',[name '_ADC'],'SaveFormat','Timeseries','Position',[930 y+45 1060 y+90]);
 add_line(mdl,[name '_input1/1'],[name '_mux/1']);add_line(mdl,[name '_input2/1'],[name '_mux/2']);
 add_line(mdl,[name '_input3/1'],[name '_blocking_gate/1']);add_line(mdl,[name '_input4/1'],[name '_BTB_gates/1']);
 add_line(mdl,[name '_blocking_gate/1'],[name '_mux/3']);add_line(mdl,[name '_BTB_gates/1'],[name '_mux/4']);
 add_line(mdl,[name '_mux/1'],[name '_Kirchhoff/1']);add_line(mdl,[name '_Kirchhoff/1'],[name '_Vout/1']);
 add_line(mdl,[name '_Vout/1'],[name '_mux/5'],'autorouting','on');add_line(mdl,[name '_Vout/1'],[name '_20MHz/1']);
 add_line(mdl,[name '_20MHz/1'],[name '_ADC_range/1']);add_line(mdl,[name '_ADC_range/1'],[name '_ADC12bit/1']);add_line(mdl,[name '_ADC12bit/1'],[name '_ADC_log/1']);
 add_line(mdl,[name '_Vout/1'],[name '_analog_log/1']);
 % Compact visible labels avoid overlapping native block names.
 bl=find_system(mdl,'SearchDepth',1,'Type','Block');for bi=1:numel(bl),set_param(bl{bi},'ShowName','off');end
 set_param([mdl '/' name '_blocking_gate'],'AttributesFormatString','Blocking gate RC');
 set_param([mdl '/' name '_BTB_gates'],'AttributesFormatString','BTB gate RC');
 set_param([mdl '/' name '_Kirchhoff'],'AttributesFormatString','Kirchhoff current law');
 set_param([mdl '/' name '_Vout'],'AttributesFormatString','Clamp voltage');
 set_param([mdl '/' name '_20MHz'],'AttributesFormatString','20 MHz filter');
 set_param([mdl '/' name '_ADC_range'],'AttributesFormatString','Range');
 set_param([mdl '/' name '_ADC12bit'],'AttributesFormatString','12 bit');
 cn=Simulink.Annotation(mdl,strrep(name,'_',' '));cn.Position=[30 y-20];
end
note=Simulink.Annotation(mdl,['Native analog-state approximation of Fig.5: Coss current, gate RC, conductance, BTB short and nonlinear TVS. ' newline 'All coefficients are explicit representative assumptions. Detailed LTspice vendor models are the primary circuit result; no waveform delay is prescribed. ' newline '20 MHz filter and 12 bit quantization are separate measurement states, with assumed +/-6 V ADC range; BTB 2 Ohm / RC 0.26 ns: releases before DUT fall, recloses after DUT rises.']);
note.Position=[25 10];
save_system(mdl,fullfile(out,[mdl '.slx']));print(['-s' mdl],'-dpng','-r150',fullfile(out,'wide_clamp_simulink_diagram.png'));
res=sim(mdl);save(fullfile(out,'wide_clamp_simulink_result.mat'),'res');
metrics=struct;assert(all(abs([signs])==1));fig=figure('Visible','off','Color','w','Position',[80 80 1200 1020]);
for k=1:6
 name=names{k};s=res.get([name '_analog']);q=res.get([name '_ADC']);
 t=s.Time;v=s.Data(:);signed=signs(k)*5;
 mask=t>=.95e-6 & t<=1.7e-6;settlemask=t>=1.0e-6 & t<=1.8e-6;
 use=t>=1.4e-6 & t<=1.8e-6;
 metrics.(name)=struct('peak_V',max(v(mask)),'minimum_V',min(v(mask)),'mean_plateau_V',trapz(t(use),v(use))/(t(find(use,1,'last'))-t(find(use,1))),'target_V',signed);
 z=find(settlemask & abs(v-signed)>.02*abs(signed),1,'last');if isempty(z),stime=0;else,stime=(t(z)-1e-6)*1e9;end
 metrics.(name).last_2percent_violation_ns=stime;
 metrics.(name).passes_2percent=abs(metrics.(name).mean_plateau_V-signed)<.02*abs(signed);assert(metrics.(name).passes_2percent);
 writematrix([t v],fullfile(out,['simulink_analog_' name '.csv']));
 subplot(3,2,k);plot((t-1e-6)*1e9,v,'LineWidth',1.4);hold on;plot((q.Time-1e-6)*1e9,q.Data,'--','LineWidth',1);xlim([-100 400]);grid on;
 title(strrep(name,'_',' '));xlabel('Time from DUT turn-on (ns)');ylabel('Clamp output (V)');legend('Analog state','20 MHz + 12 bit','Location','best');
end
sgtitle('Simulink Coss / BTB / TVS state simulation - reduced physical model at +/-5 V');
savefig(fig,fullfile(out,'wide_clamp_simulink.fig'));exportgraphics(fig,fullfile(out,'wide_clamp_simulink.png'),'Resolution',160);close(fig);
fid=fopen(fullfile(out,'wide_clamp_simulink_metrics.json'),'w');fprintf(fid,'%s',jsonencode(metrics));fclose(fid);
fprintf('SLX_SIMULATED %s\n',fullfile(out,[mdl '.slx']));disp(metrics);close_system(mdl,0);
end
