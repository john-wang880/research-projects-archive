function metrics = run_figure14_reconstruction()
%RUN_FIGURE14_RECONSTRUCTION Reconstruct the explicit Figure 14 input pattern.
% This case is separate from Figure 13 circuit simulation: Figure 14 plots
% a simplified 50 A ramp/flat template rather than Figure 13's ~54 A current.
% No parameter or measurement window is tuned to obtain a 62% reduction.
taskDir = fileparts(mfilename('fullpath'));
taskRoot = fileparts(fileparts(fileparts(taskDir)));
outDir = fullfile(taskDir,'figure14_input_reconstruction');
if ~isfolder(outDir), mkdir(outDir); end
chargeEnd=round(32.5e-6,14); measureStart=round(33.5e-6,14); measureEnd=round(38.5e-6,14);
edge=1e-12; peakCurrent=50;
time_s=unique(round([(-5e-6:10e-9:45e-6).';0; ...
    chargeEnd;chargeEnd+edge;measureStart;measureStart+edge;measureEnd;measureEnd+edge],14));
iA=zeros(size(time_s)); iB=zeros(size(time_s));
ramp=time_s>=0 & time_s<=chargeEnd;
iA(ramp)=peakCurrent*time_s(ramp)/chargeEnd;
window=time_s>measureStart & time_s<=measureEnd;
iA(window)=peakCurrent; iB(window)=peakCurrent;
conventionalCsv=fullfile(outDir,'figure14_conventional_current.csv');
proposedCsv=fullfile(outDir,'figure14_proposed_current.csv');
writetable(table(time_s,iA,'VariableNames',{'time_s','dut_current_A'}),conventionalCsv);
writetable(table(time_s,iB,'VariableNames',{'time_s','dut_current_A'}),proposedCsv);
metrics=thermal_reproduce(conventionalCsv,proposedCsv,measureStart,measureEnd,outDir, ...
    'Figure 14 plotted 50 A input reconstruction');
metrics.inputCase='Figure-input reconstruction, not an LTspice-derived circuit current';
metrics.reproductionLimits{1}='Current input reconstructs the simplified 50 A Figure 14 pattern; the original simulation project is unpublished.';
metrics.template=struct('currentPeak_A',50,'chargeStart_s',0,'chargeEnd_s',chargeEnd, ...
    'freewheelDuration_s',1e-6,'measurementDuration_s',5e-6,'edgeApproximation_s',edge);

% Independently digitized original plot coordinates are optional source QA.
plotCsv=fullfile(taskDir,'..','reference','figure14_temperature.csv');
if ~isfile(plotCsv)
    plotCsv=fullfile(taskRoot,'work','paper_audit','figure14_temperature.csv');
end
if isfile(plotCsv)
    source=readtable(plotCsv);
    local=readtable(fullfile(outDir,'thermal_waveforms.csv'));
    sourceTime=source.time_us*1e-6;
    sourceTimeForIntegral=unique([sourceTime;measureStart;measureEnd]);
    sourceTimeForIntegral=sourceTimeForIntegral(sourceTimeForIntegral>=measureStart & sourceTimeForIntegral<=measureEnd);
    % PDF coordinates end 5.8e-14 s before nominal 38.5 us due to rounding.
    % Linear extrapolation covers this sub-picosecond numerical discrepancy.
    paperA=interp1(sourceTime,source.conventional_K,sourceTimeForIntegral,'linear','extrap');
    paperB=interp1(sourceTime,source.proposed_K,sourceTimeForIntegral,'linear','extrap');
    plotMeanA=trapz(sourceTimeForIntegral,paperA)/(measureEnd-measureStart);
    plotMeanB=trapz(sourceTimeForIntegral,paperB)/(measureEnd-measureStart);
    selection=local.time_s>=0 & local.time_s<=measureEnd;
    sourceA=interp1(sourceTime,source.conventional_K,local.time_s(selection),'linear','extrap');
    sourceB=interp1(sourceTime,source.proposed_K,local.time_s(selection),'linear','extrap');
    localA=local.conventional_deltaTj_K(selection);
    localB=local.proposed_deltaTj_K(selection);
    metrics.originalPlotVerification=struct('source','Original PDF vector trace, extracted independently', ...
        'measurementMeanConventional_K',plotMeanA,'measurementMeanProposed_K',plotMeanB, ...
        'meanReduction_percent',100*(1-plotMeanB/plotMeanA), ...
        'peakConventional_K',max(source.conventional_K),'peakProposed_K',max(source.proposed_K), ...
        'conventionalWaveformRmsDifference_K',sqrt(mean((localA-sourceA).^2)), ...
        'proposedWaveformRmsDifference_K',sqrt(mean((localB-sourceB).^2)), ...
        'comment','The plotted 5 us interval means differ from the printed 4.7 K/1.8 K/62% annotations.');
    overlay=table(local.time_s(selection),localA,sourceA,localB,sourceB, ...
        'VariableNames',{'time_s','local_conventional_K','paper_vector_conventional_K', ...
        'local_proposed_K','paper_vector_proposed_K'});
    writetable(overlay,fullfile(outDir,'original_plot_comparison.csv'));
    f=figure('Visible','off','Color','w','Position',[100,100,1100,650]);
    plot(overlay.time_s*1e6,localA,'b-','LineWidth',1.6);hold on;
    plot(overlay.time_s*1e6,sourceA,'k--','LineWidth',1.1);
    plot(overlay.time_s*1e6,localB,'Color',[0.85,0.3,0.12],'LineWidth',1.6);
    plot(overlay.time_s*1e6,sourceB,'m--','LineWidth',1.1);
    xline(measureStart*1e6,'k:','Measurement start');xline(measureEnd*1e6,'k:','Measurement end');
    xlabel('Time (us)');ylabel('Junction rise (K)');grid on;box on;
    title('Independent Cauer reconstruction versus original Figure 14 vector traces');
    legend({'Local conventional','Paper conventional','Local proposed','Paper proposed'},'Location','northwest');
    savefig(f,fullfile(outDir,'original_plot_comparison.fig'));
    exportgraphics(f,fullfile(outDir,'original_plot_comparison.png'),'Resolution',200);close(f);
end
metrics.printedMeanDiscrepancy=struct('printedMeanConventional_K',4.7,'printedMeanProposed_K',1.8, ...
    'printedReduction_percent',62,'locallyComputedReduction_percent',metrics.meanTemperatureReduction_percent, ...
    'conclusion','Keep the stated 33.5-38.5 us measurement window; do not tune the window to match 62%.');
fid=fopen(fullfile(outDir,'thermal_metrics.json'),'w','n','UTF-8');
fprintf(fid,'%s\n',jsonencode(metrics,'PrettyPrint',true));fclose(fid);
save(fullfile(outDir,'figure14_reconstruction_metrics.mat'),'metrics');
disp(metrics.printedMeanDiscrepancy);
end
