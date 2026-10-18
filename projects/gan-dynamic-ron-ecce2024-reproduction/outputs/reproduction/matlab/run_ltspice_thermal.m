function comparison = run_ltspice_thermal(conventionalWaveformsCsv, proposedWaveformsCsv, measureStart_s, measureEnd_s)
%RUN_LTSPICE_THERMAL Two transparent thermal interpretations of LTspice data.
% Main case: I(LLOAD) gated by V(g_dut)>3 V, a conduction-pattern approximation
% matching the paper's Figure 14 method. Sensitivity: raw I(VDUT) includes
% ideal-switch Coss discharge spikes and is not a validated switching loss.
% Default times follow this reproduction's T0=2 us circuit schedule.
taskDir=fileparts(mfilename('fullpath'));
if nargin<1 || isempty(conventionalWaveformsCsv)
    conventionalWaveformsCsv=fullfile(taskDir,'..','data','conventional_waveforms.csv');
end
if nargin<2 || isempty(proposedWaveformsCsv)
    proposedWaveformsCsv=fullfile(taskDir,'..','data','proposed_waveforms.csv');
end
if nargin<3 || isempty(measureStart_s), measureStart_s=35.5e-6; end
if nargin<4 || isempty(measureEnd_s), measureEnd_s=40.5e-6; end
data={readtable(conventionalWaveformsCsv),readtable(proposedWaveformsCsv)};
labels={'conventional','proposed'};
loadDir=fullfile(taskDir,'ltspice_conduction_case');
rawDir=fullfile(taskDir,'ltspice_channel_sensitivity');
if ~isfolder(loadDir),mkdir(loadDir);end
if ~isfolder(rawDir),mkdir(rawDir);end
pathsLoad=cell(1,2);pathsRaw=cell(1,2);
inputChecks=struct;
for k=1:2
    T=data{k};
    required={'time_s','dut_current_A','inductor_current_A','gate_dut_V'};
    assert(all(ismember(required,T.Properties.VariableNames)), ...
        'Input waveform CSV must include time, raw DUT current, load current and DUT gate.');
    gateOn=T.gate_dut_V>3;
    loadCurrent=T.inductor_current_A.*gateOn;
    rawCurrent=T.dut_current_A;
    providedConduction=fullfile(taskDir,'..','data',[labels{k},'_conduction.csv']);
    if isfile(providedConduction)
        provided=readtable(providedConduction);
        assert(height(provided)==height(T) && max(abs(provided.time_s-T.time_s))<1e-15 && ...
            max(abs(provided.dut_current_A-loadCurrent))<1e-8, ...
            'Provided conduction CSV must match I(LLOAD) gated by DUT on state.');
        pathsLoad{k}=providedConduction;
    else
        pathsLoad{k}=fullfile(loadDir,[labels{k},'_current.csv']);
        writetable(table(T.time_s,loadCurrent,'VariableNames',{'time_s','dut_current_A'}),pathsLoad{k});
    end
    if k==1,pathsRaw{k}=conventionalWaveformsCsv;else,pathsRaw{k}=proposedWaveformsCsv;end
    inputChecks.(labels{k})=struct('rawPeakCurrent_A',max(abs(rawCurrent)), ...
        'loadConductionPeakCurrent_A',max(abs(loadCurrent)), ...
        'gateThreshold_V',3,'gateOnSampleCount',sum(gateOn));
end
loadMetrics=thermal_reproduce(pathsLoad{1},pathsLoad{2},measureStart_s,measureEnd_s,loadDir, ...
    'LTspice load current gated by DUT on state');
rawMetrics=thermal_reproduce(pathsRaw{1},pathsRaw{2},measureStart_s,measureEnd_s,rawDir, ...
    'LTspice raw channel current sensitivity');
loadMetrics.inputCase='Load/conduction approximation: I(LLOAD) when gate_dut >3 V';
loadMetrics.originalWaveformSources={char(conventionalWaveformsCsv),char(proposedWaveformsCsv)};
loadMetrics.reproductionLimits{end+1}= ...
    'Load current gated by DUT on state excludes Coss switching-edge current; it is a conduction-only approximation, not switching-loss validation.';
rawMetrics.inputCase='Raw I(VDUT) sensitivity including ideal-switch capacitance-discharge spikes';
rawMetrics.originalWaveformSources={char(conventionalWaveformsCsv),char(proposedWaveformsCsv)};
rawMetrics.reproductionLimits{end+1}= ...
    'Ideal-switch, constant-200pF Coss edge peaks are not realistic device switching currents; this case only quantifies their numerical energy sensitivity.';
writeJson(fullfile(loadDir,'thermal_metrics.json'),loadMetrics);
writeJson(fullfile(rawDir,'thermal_metrics.json'),rawMetrics);
metrics=loadMetrics;save(fullfile(loadDir,'thermal_workspace.mat'),'metrics','-append');
metrics=rawMetrics;save(fullfile(rawDir,'thermal_workspace.mat'),'metrics','-append');
comparison=struct('mainCase','Gated load-current conduction-only approximation', ...
    'sensitivityCase','Raw channel-current ideal Coss switching-edge sensitivity', ...
    'measurementWindow_s',[measureStart_s,measureEnd_s], ...
    'nominalCapacitance_F',200e-12,'nominalBusVoltage_V',150, ...
    'nominalStoredCossEnergyPer150VEdge_J',0.5*200e-12*150^2, ...
    'inputChecks',inputChecks,'loadConduction',loadMetrics,'rawChannel',rawMetrics, ...
    'rawMinusLoadConventionalEnergy_J',rawMetrics.conventional.totalConductionEnergy_J-loadMetrics.conventional.totalConductionEnergy_J, ...
    'rawMinusLoadProposedEnergy_J',rawMetrics.proposed.totalConductionEnergy_J-loadMetrics.proposed.totalConductionEnergy_J, ...
    'rawMinusLoadConventionalMeanRise_K',rawMetrics.conventional.measurementMeanDeltaTj_K-loadMetrics.conventional.measurementMeanDeltaTj_K, ...
    'rawMinusLoadProposedMeanRise_K',rawMetrics.proposed.measurementMeanDeltaTj_K-loadMetrics.proposed.measurementMeanDeltaTj_K);
writeJson(fullfile(taskDir,'circuit_thermal_sensitivity.json'),comparison);
save(fullfile(taskDir,'circuit_thermal_sensitivity.mat'),'comparison');
fprintf('Load-gated means %.6f/%.6f K, %.3f%% reduction\n', ...
    loadMetrics.conventional.measurementMeanDeltaTj_K,loadMetrics.proposed.measurementMeanDeltaTj_K,loadMetrics.meanTemperatureReduction_percent);
fprintf('Raw-minus-load mean rise %.6g/%.6g K\n',comparison.rawMinusLoadConventionalMeanRise_K,comparison.rawMinusLoadProposedMeanRise_K);
end

function writeJson(path,value)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0,'Could not open metrics output.');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
