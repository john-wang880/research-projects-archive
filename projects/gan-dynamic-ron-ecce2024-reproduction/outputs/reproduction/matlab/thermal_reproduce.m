function metrics = thermal_reproduce(conventionalCsv, proposedCsv, measureStart_s, measureEnd_s, outputDir, caseLabel)
%THERMAL_REPRODUCE Reproduce the Figure 14 method using LTspice DUT currents.
% Example:
% thermal_reproduce('conventional.csv','proposed.csv',35.5e-6,40.5e-6,'results')
% CSV columns: time_s, dut_current_A. The timing arguments must come from
% the circuit schedule. Do not adjust them to force the paper's 62% result.
% The paper uses constant Rds,on=80 mOhm, not electrothermal feedback.

if nargin<5 || isempty(outputDir), outputDir = fullfile(pwd,'thermal_results'); end
if nargin<6 || isempty(caseLabel), caseLabel = 'LTspice-derived circuit currents'; end
if ~isfolder(outputDir), mkdir(outputDir); end
R = [0.015;0.23;0.24;0.015];
C = [8.0e-5;7.4e-4;6.5e-3;2.0e-3];
Rds = 80e-3; caseTemperature_C = 25;
[tA,iA] = readCurrentCsv(conventionalCsv);
[tB,iB] = readCurrentCsv(proposedCsv);
assert(isfinite(measureStart_s) && isfinite(measureEnd_s) && measureEnd_s>measureStart_s, ...
    'Supply a finite, increasing measurement window in seconds.');
tol = max(1e-15,1e-9*max([tA(end)-tA(1),tB(end)-tB(1)]));
assert(abs(tA(1)-tB(1))<=tol && abs(tA(end)-tB(end))<=tol, ...
    'Both current records must cover the same start and end times.');
assert(measureStart_s>=max(tA(1),tB(1)) && measureEnd_s<=min(tA(end),tB(end)), ...
    'Both current records must cover the measurement window.');
time_s = unique([tA;tB;measureStart_s;measureEnd_s]);
time_s = time_s(time_s>=max(tA(1),tB(1)) & time_s<=min(tA(end),tB(end)));
currentA_A = interp1(tA,iA,time_s,'linear');
currentB_A = interp1(tB,iB,time_s,'linear');
powerA_W = Rds*currentA_A.^2;
powerB_W = Rds*currentB_A.^2;
[riseA_K,diagA] = cauer_temperature(time_s,powerA_W,R,C);
[riseB_K,diagB] = cauer_temperature(time_s,powerB_W,R,C);
kStart = find(time_s==measureStart_s,1); kEnd = find(time_s==measureEnd_s,1);
windowDuration_s = measureEnd_s-measureStart_s;
meanA_K = (diagA.integralTemperature_K_s(kEnd,1)- ...
    diagA.integralTemperature_K_s(kStart,1))/windowDuration_s;
meanB_K = (diagB.integralTemperature_K_s(kEnd,1)- ...
    diagB.integralTemperature_K_s(kStart,1))/windowDuration_s;

metrics = struct;
metrics.method = 'Four-stage Cauer, fixed case, zero initial rise, piecewise-linear I_D^2 R loss';
metrics.inputCase = char(caseLabel);
metrics.sourcePaperDOI = '10.1109/ECCEEurope62508.2024.10751914';
metrics.thermalSource = 'GS66508B datasheet Rev 200402, printed page 14';
metrics.conventionalCurrentSource = char(conventionalCsv);
metrics.proposedCurrentSource = char(proposedCsv);
metrics.measurementStart_s = measureStart_s;
metrics.measurementEnd_s = measureEnd_s;
metrics.caseTemperature_C = caseTemperature_C;
metrics.assumedRdsOn_ohm = Rds;
metrics.Cauer_R_K_per_W = R.';
metrics.Cauer_C_J_per_K = C.';
metrics.initialTemperatureRise_K = [0,0,0,0];
metrics.conventional = summarizeTrace(time_s,currentA_A,powerA_W,riseA_K,diagA,meanA_K,kStart,kEnd);
metrics.proposed = summarizeTrace(time_s,currentB_A,powerB_W,riseB_K,diagB,meanB_K,kStart,kEnd);
metrics.meanTemperatureReduction_percent = 100*(1-meanB_K/meanA_K);
metrics.totalConductionEnergyReduction_percent = 100*(1-diagB.inputEnergy_J(end)/diagA.inputEnergy_J(end));
metrics.paperReference = struct('meanConventional_K',4.7,'meanProposed_K',1.8, ...
    'meanReduction_percent',62,'peakConventional_K',6.1,'peakProposed_K',3.6);
metrics.reproductionLimits = { ...
    'Current input is from the local circuit model, not the unpublished author simulation template.', ...
    'Only I_D^2 times constant 80 mOhm conduction loss is included, matching the paper method.', ...
    'Zero initial thermal rise and fixed case 25 C are explicit local assumptions.', ...
    'Minutes-scale trapping and experimental resistance statistics are not reproduced.'};

waveforms = table(time_s,currentA_A,currentB_A,powerA_W,powerB_W, ...
    riseA_K(:,1),riseB_K(:,1),caseTemperature_C+riseA_K(:,1),caseTemperature_C+riseB_K(:,1), ...
    'VariableNames',{'time_s','conventional_dut_current_A','proposed_dut_current_A', ...
    'conventional_power_W','proposed_power_W','conventional_deltaTj_K','proposed_deltaTj_K', ...
    'conventional_Tj_C','proposed_Tj_C'});
writetable(waveforms,fullfile(outputDir,'thermal_waveforms.csv'));
save(fullfile(outputDir,'thermal_workspace.mat'),'metrics','waveforms','riseA_K','riseB_K','diagA','diagB');
fid = fopen(fullfile(outputDir,'thermal_metrics.json'),'w','n','UTF-8');
assert(fid>=0,'Could not write metrics JSON.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(metrics,'PrettyPrint',true)); clear cleanup;

f = figure('Visible','off','Color','w','Position',[100,100,1200,850]);
tl = tiledlayout(f,3,1,'TileSpacing','compact','Padding','compact');
colors = [0.10,0.32,0.65;0.85,0.30,0.12];
ax1 = nexttile(tl); plot(time_s*1e6,currentA_A,'Color',colors(1,:),'LineWidth',1.5); hold on;
plot(time_s*1e6,currentB_A,'Color',colors(2,:),'LineWidth',1.5);
ylabel('DUT current (A)'); legend({'Conventional DPT','Proposed DPT'},'Location','northwest','AutoUpdate','off');
title({char(caseLabel), 'Conduction-only Cauer response'});
ax2 = nexttile(tl); plot(time_s*1e6,powerA_W,'Color',colors(1,:),'LineWidth',1.5); hold on;
plot(time_s*1e6,powerB_W,'Color',colors(2,:),'LineWidth',1.5); ylabel('DUT power (W)');
ax3 = nexttile(tl); plot(time_s*1e6,riseA_K(:,1),'Color',colors(1,:),'LineWidth',1.5); hold on;
plot(time_s*1e6,riseB_K(:,1),'Color',colors(2,:),'LineWidth',1.5); ylabel('Junction rise (K)'); xlabel('Time (us)');
title(sprintf('Measurement means %.3f K / %.3f K; reduction %.2f%%',meanA_K,meanB_K,metrics.meanTemperatureReduction_percent));
for ax = [ax1,ax2,ax3]
    grid(ax,'on'); box(ax,'on');
    xline(ax,measureStart_s*1e6,'k--','Measurement start','LabelVerticalAlignment','bottom');
    xline(ax,measureEnd_s*1e6,'k--','Measurement end','LabelVerticalAlignment','bottom');
    set(ax,'FontSize',11);
end
linkaxes([ax1,ax2,ax3],'x');
savefig(f,fullfile(outputDir,'figure14_reproduction.fig'));
exportgraphics(f,fullfile(outputDir,'figure14_reproduction.png'),'Resolution',200);
close(f);
fprintf('Mean rise: conventional %.6f K, proposed %.6f K, reduction %.3f%%\n',meanA_K,meanB_K,metrics.meanTemperatureReduction_percent);
fprintf('Peak rise: conventional %.6f K, proposed %.6f K\n',max(riseA_K(:,1)),max(riseB_K(:,1)));
fprintf('Energy balance relative residuals %.3g and %.3g\n',diagA.maximumRelativeEnergyResidual,diagB.maximumRelativeEnergyResidual);
end

function [t,i] = readCurrentCsv(path)
assert(isfile(path),'Current CSV does not exist: %s',path);
T = readtable(path,'VariableNamingRule','preserve');
names = lower(regexprep(string(T.Properties.VariableNames),'[^a-zA-Z0-9]',''));
it = find(ismember(names,["times","time","ts"]),1);
ii = find(ismember(names,["dutcurrenta","iduta","ida","currenta","current"]),1);
if isempty(it) || isempty(ii)
    error('CSV needs numeric time_s and dut_current_A columns: %s',path);
end
t = T{:,it}; i = T{:,ii}; t=t(:); i=i(:);
assert(isnumeric(t) && isnumeric(i) && all(isfinite(t)) && all(isfinite(i)), ...
    'Current CSV columns must be numeric and finite.');
assert(all(diff(t)>=0),'Current CSV times must be increasing.');
[t,k] = unique(t,'last'); i=i(k);
assert(numel(t)>1 && all(diff(t)>0),'Current CSV needs at least two distinct times.');
end

function s = summarizeTrace(t,i,p,rise,d,meanRise,kStart,kEnd)
[peakRise,k] = max(rise(:,1));
s = struct('measurementMeanDeltaTj_K',meanRise, ...
    'measurementMeanTj_C',25+meanRise, ...
    'globalPeakDeltaTj_K',peakRise,'globalPeakTime_s',t(k), ...
    'measurementPeakDeltaTj_K',max(rise(kStart:kEnd,1)), ...
    'measurementMeanCurrent_A',trapz(t(kStart:kEnd),i(kStart:kEnd))/(t(kEnd)-t(kStart)), ...
    'totalConductionEnergy_J',d.inputEnergy_J(end), ...
    'measurementConductionEnergy_J',d.inputEnergy_J(kEnd)-d.inputEnergy_J(kStart), ...
    'peakConductionPower_W',max(p), ...
    'maximumAbsoluteEnergyBalanceResidual_J',d.maximumAbsoluteEnergyResidual_J, ...
    'maximumRelativeEnergyBalanceResidual',d.maximumRelativeEnergyResidual);
end
