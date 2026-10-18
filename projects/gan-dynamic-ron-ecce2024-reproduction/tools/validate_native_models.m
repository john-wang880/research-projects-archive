function validate_native_models()
% Run the published self-contained SLX files without rebuilding/saving them.
root=fileparts(fileparts(mfilename('fullpath')));full=fullfile(root,'outputs','full_reproduction');
prior=pwd;restore=onCleanup(@() cd(prior));
for f={'simulink','scrc','clamp','ron_trapping','tec','integration'},addpath(fullfile(full,f{1}));end
cache=tempname; % Keep generated code paths short on Windows.
Simulink.fileGenControl('set','CacheFolder',fullfile(cache,'cache'),'CodeGenFolder',fullfile(cache,'codegen'),'createDir',true);
models=dir(fullfile(full,'**','*.slx'));assert(numel(models)==11);
records=struct([]);
for k=1:numel(models)
    filename=fullfile(models(k).folder,models(k).name);[~,name]=fileparts(filename);
    fprintf('PUBLIC MODEL %d/%d: %s\n',k,numel(models),name);tic;
    load_system(filename);result=sim(name);
    records(k).model=strrep(filename,[root filesep],'');
    records(k).seconds=toc;records(k).stop_event=result.SimulationMetadata.ExecutionInfo.StopEvent;
    assert(strcmp(records(k).stop_event,'ReachedStopTime'));
    close_system(name,0);
end
result=struct('models_executed',numel(models),'all_reached_stop_time',true,'MATLAB',version,'records',records);
fid=fopen(fullfile(root,'validation_native_models.json'),'w');c=onCleanup(@() fclose(fid));fwrite(fid,jsonencode(result,'PrettyPrint',true));
fprintf('PASS: all 11 public SLX models reached their requested terminal time.\n');
end
