function verify_pwm_convergence
out=fileparts(mfilename('fullpath'));cd(out);m='TEC_DualBuck_PWM';load_system(fullfile(out,[m '.slx']));
cache=tempname;Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'cache'),'CodeGenFolder',fullfile(cache,'codegen'),'createDir',true);
in=Simulink.SimulationInput(m);in=in.setModelParameter('FixedStep','5e-8');
in=in.setBlockParameter([m '/Electrothermal_Power_Stage/Solver'],'LocalSolverSampleTime','5e-8');o=sim(in);q=o.TEC_results;t=q.Time;y=q.Data;
base=readmatrix(fullfile(out,[m '_results.csv']));yb=interp1(base(:,1),base(:,3),t,'linear');
pos=t>.010 & t<.014;neg=t>.025 & t<.029;
r=struct('baseline_step_s',1e-7,'fine_step_s',5e-8,'native_fixed_step_ran',true,'maximum_current_difference_A',max(abs(y(:,2)-yb)),...
 'positive_mean_current_A',mean(y(pos,2)),'negative_mean_current_A',mean(y(neg,2)),...
 'plateau_rms_current_difference_A',sqrt(mean((y(pos|neg,2)-yb(pos|neg)).^2)));
fid=fopen(fullfile(out,'PWM_convergence_metrics.json'),'w');fwrite(fid,jsonencode(r));fclose(fid);
save(fullfile(out,'PWM_half_step.mat'),'t','y','r');
assert(abs(r.positive_mean_current_A-1)<.05 && abs(r.negative_mean_current_A+1)<.05);
assert(r.plateau_rms_current_difference_A<.025);
f=figure('Visible','off','Color','w');plot(base(:,1)*1e3,base(:,3),t*1e3,y(:,2));xlabel('Time (ms)');ylabel('Peltier current (A)');legend('100 ns native step','50 ns native step');grid on;savefig(f,fullfile(out,'PWM_convergence.fig'));exportgraphics(f,fullfile(out,'PWM_convergence.png'),'Resolution',160);close(f);close_system(m,0);
end
