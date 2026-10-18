function build_run_ron_models
% Rebuild and simulate real native Simulink ODE models for public Fig10..12.
% The slow dynamics are calibrated resistance deviations, not hidden author
% model recovery or independent physical prediction. Time is in minutes.
out=fileparts(mfilename('fullpath'));addpath(out);cd(out);
p=jsondecode(fileread('model_parameters.json'));
fprintf('MATLAB %s | Simulink license %d\n',version,license('test','Simulink'));
summary=struct;summary.status='Actual native Simulink simulations executed; public-curve calibrated behavior';
summary.MATLAB=version;summary.solver='ode15s relativeTolerance1e-7 absoluteTolerance1e-8 maxStep0.025min';
for fam={'fig11','fig12'}
    family=fam{1};params=p.trapping.(family);mdl=['RonTrap_' family];
    if bdIsLoaded(mdl),close_system(mdl,0);end
    new_system(mdl);load_system('simulink');
    set_param(mdl,'StartTime','-14','StopTime','39','Solver','ode15s','RelTol','1e-7','AbsTol','1e-8','MaxStep','0.025',...
        'SaveOutput','on','SaveTime','on','OutputSaveName','yout','TimeSaveName','tout','SaveFormat','Dataset','ReturnWorkspaceOutputs','on');
    a=Simulink.Annotation(mdl,'Public-curve calibrated resistance dynamics | time in minutes | not independently validated microscopic traps');
    a.Position=[30 10];
    for k=1:numel(params)
        q=params(k);sub=[mdl '/Condition_' num2str(q.condition)];y=70+(k-1)*105;
        add_block('simulink/Ports & Subsystems/Subsystem',sub,'Position',[70 y 420 y+70]);
        delete_line(sub,'In1/1','Out1/1');delete_block([sub '/In1']);
        set_param([sub '/Out1'],'Position',[1140 215 1170 235]);
        build_condition(sub,q);
        sink=[mdl '/Ron_' num2str(q.condition)];add_block('simulink/Sinks/To Workspace',sink,'VariableName',['R_' num2str(q.condition)],'SaveFormat','Timeseries','Position',[500 y+20 660 y+50]);
        add_line(mdl,['Condition_' num2str(q.condition) '/1'],['Ron_' num2str(q.condition) '/1'],'autorouting','on');
    end
    save_system(mdl,fullfile(out,[mdl '.slx']));
    try,print(['-s' mdl],'-dpng',fullfile(out,[mdl '_diagram.png']));catch er,fprintf('Diagram export: %s\n',er.message);end
    simout=sim(mdl);
    figure('Visible','off','Color','w','Position',[40 40 1050 720]);tiledlayout(2,1,'TileSpacing','compact');ax1=nexttile;hold(ax1,'on');ax2=nexttile;hold(ax2,'on');
    colors=turbo(numel(params));entries=struct([]);
    for k=1:numel(params)
        q=params(k);ts=simout.get(['R_' num2str(q.condition)]);
        cf=sprintf('%s_%s_%d_native.csv',family,q.condition_name,q.condition);tab=readtable(cf);
        native_t=tab.time_min;native_y=tab.Ron_mOhm;
        % At the release event the analytical expression is continuous. Solver
        % samples vary; interpolate the simulated trajectory to plotted times.
        simulated=interp1(ts.Time,squeeze(ts.Data),native_t,'pchip');
        analytic=ron_trap_behavior(native_t,family,q.condition);err=simulated-native_y;
        entries(k).condition=q.condition;entries(k).RMSE_vs_public_plot_mOhm=sqrt(mean(err.^2));entries(k).MAX_vs_public_plot_mOhm=max(abs(err));
        entries(k).MAX_Simulink_vs_analytical_mOhm=max(abs(simulated-analytic));entries(k).actual_solver_points=numel(ts.Time);
        writetable(table(native_t,native_y,simulated,analytic,'VariableNames',{'time_min','public_plot_mOhm','Simulink_ODE_mOhm','analytical_ODE_mOhm'}),sprintf('%s_%d_Simulink_comparison.csv',family,q.condition));
        plot(ax1,native_t,native_y,'.','Color',colors(k,:),'MarkerSize',2,'HandleVisibility','off');
        if strcmp(family,'fig11'),unit=' V';else,unit=' C';end
        plot(ax1,ts.Time,squeeze(ts.Data),'Color',colors(k,:),'DisplayName',[num2str(q.condition) unit]);
        plot(ax2,native_t,err,'Color',colors(k,:));
    end
    xlabel(ax1,'Time (min)');ylabel(ax1,'R_{on} (m\Omega)');grid(ax1,'on');legend(ax1,'Location','best','NumColumns',4);
    title(ax1,[upper(family) ' public plots and native Simulink calibrated ODE']);
    xlabel(ax2,'Time (min)');ylabel(ax2,'Simulation minus plot (m\Omega)');grid(ax2,'on');title(ax2,'Residuals contain withheld points; fit metrics identify calibration and holdout separately');
    savefig(gcf,fullfile(out,[family '_Simulink.fig']));exportgraphics(gcf,fullfile(out,[family '_Simulink.png']),'Resolution',160);close(gcf);
    save(fullfile(out,[family '_Simulink_runs.mat']),'simout','entries');summary.(family)=entries;close_system(mdl,0);
end
% Fig10 polynomial evaluated by native Fcn block, two external inputs. Source
% current/temperature settings are inputs; the plotted resistance is NOT fed
% to the model. Entire withheld-temperature curves remain independent tests.
mdl='RonStatic_Fig10';if bdIsLoaded(mdl),close_system(mdl,0);end;new_system(mdl);
add_block('simulink/Sources/In1',[mdl '/Id_A'],'Position',[45 80 75 100]);
add_block('simulink/Sources/In1',[mdl '/Tc_C'],'Position',[45 160 75 180],'Port','2');
add_block('simulink/Signal Routing/Mux',[mdl '/Inputs'],'Inputs','2','Position',[120 85 125 170]);
expr='0';coef=p.static.coefficients_mOhm;ic=1;
for j=0:p.static.temperature_degree
 for i=0:p.static.current_degree
  expr=[expr sprintf('+%.17g*(u(1)/50)^%d*((u(2)-55)/40)^%d',coef(ic),i,j)];ic=ic+1;
 end
end
add_block('simulink/User-Defined Functions/Fcn',[mdl '/Calibrated_Ron_polynomial'],'Expr',expr,'Position',[180 105 520 155]);
add_block('simulink/Sinks/Out1',[mdl '/R_mOhm'],'Position',[590 115 620 135]);
add_line(mdl,'Id_A/1','Inputs/1');add_line(mdl,'Tc_C/1','Inputs/2');add_line(mdl,'Inputs/1','Calibrated_Ron_polynomial/1');add_line(mdl,'Calibrated_Ron_polynomial/1','R_mOhm/1');
tab=readtable('fig10_model_comparison.csv');N=height(tab);input=[(0:N-1)' tab.Id_A tab.Tc_C];
mw=get_param(mdl,'ModelWorkspace');assignin(mw,'staticInput',input);
% The saved model must also run outside this builder's SimulationInput scope.
externalExpr="getVariable(get_param('RonStatic_Fig10','ModelWorkspace'),'staticInput')";
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','1','StopTime',num2str(N-1),'LoadExternalInput','on','ExternalInput',char(externalExpr),'SaveOutput','on','OutputSaveName','staticY','SaveTime','on','SaveFormat','Dataset');
save_system(mdl,fullfile(out,[mdl '.slx']));
simout=sim(mdl);ds=simout.get('staticY');ts=ds.getElement(1).Values;R=squeeze(ts.Data);
summary.fig10.MAX_Simulink_vs_polynomial_mOhm=max(abs(R-tab.model_Ron_mOhm));
summary.fig10.RMSE_vs_all_plotted_points_mOhm=sqrt(mean((R-tab.plotted_Ron_mOhm).^2));
summary.fig10.sample_count=N;
tab.Simulink_mOhm=R;writetable(tab,'fig10_Simulink_comparison.csv');save('fig10_Simulink_runs.mat','simout','input');
figure('Visible','off','Color','w','Position',[40 40 1000 660]);hold on;cc=turbo(9);temps=sort(unique(tab.Tc_C));
for k=1:numel(temps),m=tab.Tc_C==temps(k);plot(tab.Id_A(m),tab.plotted_Ron_mOhm(m),'.','Color',cc(k,:),'MarkerSize',4,'HandleVisibility','off');plot(tab.Id_A(m),R(m),'Color',cc(k,:),'DisplayName',sprintf('%d C',temps(k)));end
xlabel('Signed drain current (A)');ylabel('R_{on} (m\Omega)');title('Fig10 native Simulink algebraic behavior model | points are public plots');legend('Location','northwest');grid on;
savefig(gcf,'fig10_Simulink.fig');exportgraphics(gcf,'fig10_Simulink.png','Resolution',160);close(gcf);
try,print(['-s' mdl],'-dpng',fullfile(out,[mdl '_diagram.png']));catch,end
close_system(mdl,0);
fid=fopen('Simulink_execution_metrics.json','w');fprintf(fid,'%s',jsonencode(summary));fclose(fid);
fprintf('COMPLETE native Fig10,11,12 simulations and native FIG saved.\n');
end

function build_condition(sub,q)
% Capture and release have separate resistance modes; enable/freeze their
% states in their respective intervals. This realizes the explicit calibrated
% piecewise ODE without any Ron lookup-table or output waveform replay.
add_block('simulink/Sources/Step',[sub '/Stress_applied'],'Time',num2str(q.stress_on_min,17),'Before','0','After','1','Position',[35 65 65 85]);
add_block('simulink/Sources/Step',[sub '/Stress_removed'],'Time',num2str(q.stress_off_min,17),'Before','0','After','1','Position',[35 125 65 145]);
add_block('simulink/Math Operations/Sum',[sub '/Capture_active'],'Inputs','+-','Position',[110 75 130 105]);
add_line(sub,'Stress_applied/1','Capture_active/1');add_line(sub,'Stress_removed/1','Capture_active/2');
build_modes(sub,'Capture',q.capture.tau_capture_min(:),q.capture.A_mOhm(:),0,1,[1 1]);
build_modes(sub,'Release',q.release.tau_release_min(:),q.release.A_mOhm(:),1,0,[1 1]);
add_line(sub,'Capture_active/1','Capture_Enable/2','autorouting','on');add_line(sub,'Stress_removed/1','Release_Enable/2','autorouting','on');
add_block('simulink/Sources/Constant',[sub '/R0'],'Value',num2str(q.pre.R0_mOhm,17),'Position',[670 55 750 80]);
add_block('simulink/Math Operations/Sum',[sub '/R_captured'],'Inputs','++','Position',[820 65 840 100]);
add_line(sub,'R0/1','R_captured/1');add_line(sub,'Capture_Weighted/1','R_captured/2','autorouting','on');
add_block('simulink/Sources/Constant',[sub '/Rinf'],'Value',num2str(q.release.Rinf_mOhm,17),'Position',[670 295 750 320]);
add_block('simulink/Math Operations/Sum',[sub '/R_released'],'Inputs','++','Position',[820 255 840 290]);
add_line(sub,'Rinf/1','R_released/1');add_line(sub,'Release_Weighted/1','R_released/2','autorouting','on');
% Pre-stress baseline state relaxes toward R0+C, initialized from the fitted
% prebranch at -14min; only this branch is selected before stressapplication.
add_block('simulink/Sources/Constant',[sub '/Pre_target'],'Value',num2str(q.pre.Rinf_mOhm,17),'Position',[195 440 255 465]);
add_block('simulink/Math Operations/Sum',[sub '/Pre_error'],'Inputs','+-','Position',[290 440 310 475]);
add_block('simulink/Math Operations/Gain',[sub '/Pre_rate'],'Gain',num2str(1/q.pre.tau_min,17),'Position',[355 440 430 475]);
ic=q.pre.Rinf_mOhm+q.pre.A_mOhm*exp(-(-14-q.pre.start_min)/q.pre.tau_min);
add_block('simulink/Continuous/Integrator',[sub '/Pre_state'],'InitialCondition',num2str(ic,17),'Position',[470 440 520 475]);
add_line(sub,'Pre_target/1','Pre_error/1');add_line(sub,'Pre_state/1','Pre_error/2','autorouting','on');add_line(sub,'Pre_error/1','Pre_rate/1');add_line(sub,'Pre_rate/1','Pre_state/1');
add_block('simulink/Signal Routing/Switch',[sub '/Pre_or_capture'],'Threshold','0.5','Criteria','u2 >= Threshold','Position',[910 95 960 155]);
add_line(sub,'R_captured/1','Pre_or_capture/1','autorouting','on');add_line(sub,'Stress_applied/1','Pre_or_capture/2','autorouting','on');add_line(sub,'Pre_state/1','Pre_or_capture/3','autorouting','on');
add_block('simulink/Signal Routing/Switch',[sub '/Capture_or_release'],'Threshold','0.5','Criteria','u2 >= Threshold','Position',[1030 195 1080 255]);
add_line(sub,'R_released/1','Capture_or_release/1','autorouting','on');add_line(sub,'Stress_removed/1','Capture_or_release/2','autorouting','on');add_line(sub,'Pre_or_capture/1','Capture_or_release/3','autorouting','on');add_line(sub,'Capture_or_release/1','Out1/1');
end

function build_modes(sub,prefix,tau,A,ic,target,unused)
if strcmp(prefix,'Capture'),y=175;else,y=345;end
add_block('simulink/Sources/Constant',[sub '/' prefix '_Target'],'Value',mat2str(target*ones(size(tau)),17),'Position',[190 y 255 y+30]);
add_block('simulink/Math Operations/Sum',[sub '/' prefix '_Error'],'Inputs','+-','Position',[290 y 310 y+35]);
add_block('simulink/Math Operations/Gain',[sub '/' prefix '_Rate'],'Gain',mat2str(diag(1./tau),17),'Multiplication','Matrix(K*u)','Position',[355 y 425 y+35]);
add_block('simulink/Math Operations/Product',[sub '/' prefix '_Enable'],'Inputs','**','Position',[465 y 490 y+35]);
add_block('simulink/Continuous/Integrator',[sub '/' prefix '_State'],'InitialCondition',mat2str(ic*ones(size(tau)),17),'Position',[535 y 580 y+35]);
add_block('simulink/Math Operations/Gain',[sub '/' prefix '_Weighted'],'Gain',mat2str(A',17),'Multiplication','Matrix(K*u)','Position',[620 y 740 y+35]);
add_line(sub,[prefix '_Target/1'],[prefix '_Error/1']);add_line(sub,[prefix '_State/1'],[prefix '_Error/2'],'autorouting','on');
add_line(sub,[prefix '_Error/1'],[prefix '_Rate/1']);add_line(sub,[prefix '_Rate/1'],[prefix '_Enable/1']);add_line(sub,[prefix '_Enable/1'],[prefix '_State/1']);add_line(sub,[prefix '_State/1'],[prefix '_Weighted/1']);
end
