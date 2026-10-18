function run_all()
% Rebuild and run all 11 native models from the published parameters.
% Run in a fresh MATLAB batch. Requires R2022b, Simulink and Simscape Electrical.
base=fileparts(mfilename('fullpath'));previous=pwd;previousPath=path;
cleanup=onCleanup(@() restore_session(previous,previousPath));
folders={'simulink','scrc','clamp','ron_trapping','tec','integration'};
for k=1:numel(folders),addpath(fullfile(base,folders{k}));end
addpath(fullfile(fileparts(base),'reproduction','matlab'));
% A short temporary folder avoids Windows' 260-character generated-code limit.
cache=tempname;
Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'cache'), ...
    'CodeGenFolder',fullfile(cache,'codegen'),'createDir',true);
tasks={'build_and_run_simulink','build_run_scrc','build_clamp_simulink', ...
    'build_wide_clamp_simulink','build_run_ron_models','verify_coupled_model', ...
    'build_run_tec','verify_pwm_convergence','run_integrated_snapshots'};
status=struct('started',datestr(now,30),'MATLAB',version,'complete',false,'stages',struct([]));
for k=1:numel(tasks)
    fprintf('\n[%d/%d] START %s\n',k,numel(tasks),tasks{k});tic;
    try
        feval(tasks{k});
        status.stages(k).function=tasks{k};status.stages(k).passed=true;
        status.stages(k).seconds=toc;
        fprintf('[%d/%d] PASS %s (%.1f s)\n',k,numel(tasks),tasks{k},status.stages(k).seconds);
    catch errorInfo
        status.stages(k).function=tasks{k};status.stages(k).passed=false;
        status.stages(k).seconds=toc;status.stages(k).error=getReport(errorInfo,'extended','hyperlinks','off');
        write_status(base,status);rethrow(errorInfo);
    end
    write_status(base,status);
end
models=dir(fullfile(base,'**','*.slx'));assert(numel(models)==11,'Expected 11 delivered SLX models');
thermal=jsondecode(fileread(fullfile(base,'simulink','thermal_metrics.json')));
assert(abs(thermal.meanReduction_percent-51.737126)<0.02);
coupling=jsondecode(fileread(fullfile(base,'integration','integration_metrics.json')));
assert(numel(coupling.cases)==6);
status.model_count=numel(models);status.complete=true;status.finished=datestr(now,30);
write_status(base,status);fprintf('\nALL NATIVE MODEL STAGES PASSED: %d SLX models.\n',numel(models));
end

function write_status(base,status)
fid=fopen(fullfile(base,'unified_run_status.json'),'w','n','UTF-8');
assert(fid>0);c=onCleanup(@() fclose(fid));fprintf(fid,'%s\n',jsonencode(status,'PrettyPrint',true));
end
function restore_session(previous,previousPath)
cd(previous);path(previousPath);
end
