function verify_coupled_model
% Numerical checks of the explicit coupling extension, not experimental proof.
out=fileparts(mfilename('fullpath'));addpath(out);p=jsondecode(fileread(fullfile(out,'model_parameters.json')));
tests=struct;epsT=1e-8;R=[];
for V=[50 100 150 200 250 300 350 400]
 [r,info]=ron_behavior_coupled(30,25,V,[-1 0 13-epsT 13+epsT 39],0,13,25);
 assert(all(r>0));assert(abs(r(3)-r(4))<1e-6);assert(abs(r(1)-ron_static_behavior(30,25)/1000)<1e-12);
 R=[R;V r];
end
tests.voltage_cases=[50 100 150 200 250 300 350 400];tests.release_continuity_bound_Ohm=1e-6;
for T=[15 25 35 45 55]
 r=ron_behavior_coupled(30,T,150,[0 10 13-epsT 13+epsT 39],0,13,T);assert(all(r>0));assert(abs(r(3)-r(4))<1e-6);
end
tests.temperature_cases=[15 25 35 45 55];
r=ron_behavior_coupled(30,25,150,[-1 0 1 10],0,0,25);assert(max(abs(r-ron_static_behavior(30,25)/1000))<1e-12);
tests.zero_duration_no_increment=true;
r=ron_behavior_coupled(30,25,0,[0 10],0,13,25);assert(max(abs(r-ron_static_behavior(30,25)/1000))<1e-12);
tests.zero_historical_stress_no_increment=true;
for t=[-1 0 1 13 39]
 r=ron_behavior_coupled(30,25,150,t,0,13,25);assert(isscalar(r)&&isfinite(r)&&r>0);
 rr=ron_trap_behavior(t,'fig11',150);assert(isscalar(rr)&&isfinite(rr)&&rr>0);
end
tests.scalar_pre_capture_release_queries=true;
try,ron_behavior_coupled(30,25,300,10,0,13,55);error('Unsupported grid erroneously passed');catch e,assert(contains(e.message,'slice'));end
tests.unsupported_2D_grid_rejected=true;
fid=fopen(fullfile(out,'coupling_checks.json'),'w');fprintf(fid,'%s',jsonencode(tests));fclose(fid);
writematrix(R,fullfile(out,'coupling_voltage_snapshots_Ohm.csv'));
for family={'fig11','fig12'}
 f=family{1};fig=openfig(fullfile(out,[f '_Simulink.fig']),'invisible');axs=findobj(fig,'Type','axes');
 leg=findobj(fig,'Type','legend');ss=p.trapping.(f);if strcmp(f,'fig11'),unit=' V';else,unit=' C';end
 labels=arrayfun(@(q)[num2str(q.condition) unit],ss,'UniformOutput',false);set(leg,'String',labels);
 savefig(fig,fullfile(out,[f '_Simulink.fig']));exportgraphics(fig,fullfile(out,[f '_Simulink.png']),'Resolution',160);close(fig);
end
fprintf('Coupled calibratedbehavior continuity/domain checks PASS.\n');
end
