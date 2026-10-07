function raw = run_cec2017(cfg)
%RUN_CEC2017 Execute/resume a reproducible, explicitly budgeted experiment.
% cfg=cec2017_config(); cfg.functions=[1 10 11 25]; cfg.runs=30;
% raw=run_cec2017(cfg); analyze_results(raw,cfg.outputDir,'RLDSBO');
if nargin==0, cfg=cec2017_config(); end
cfg=repro.validate_config(cfg);
[root,setupGuard]=repro.setup();
for a=1:numel(cfg.algorithms)
    expected=fullfile(root,'algorithms',[cfg.algorithms{a} '.m']);
    assert(strcmpi(which(cfg.algorithms{a}),expected),'repro:ShadowedAlgorithm','Unexpected algorithm on MATLAB path.');
end
if ~isfolder(cfg.outputDir), mkdir(cfg.outputDir); end
checkpointDir=fullfile(cfg.outputDir,'checkpoints');
if ~isfolder(checkpointDir), mkdir(checkpointDir); end
metadataFile=fullfile(cfg.outputDir,'experiment.mat');
signature=repro.source_signature(root);
metadata=struct('cfg',cfg,'signature',signature,'matlab',version, ...
    'computer',computer,'createdUTC',char(datetime('now','TimeZone','UTC')), ...
    'metric','best_feasible_evaluated');
if isfile(metadataFile)
    previous=load(metadataFile,'metadata');
    assert(isequaln(previous.metadata.cfg,cfg) && isequal(previous.metadata.signature,signature), ...
        'repro:ResumeMismatch','Configuration/source changed. Use a different outputDir.');
    assert(strcmp(previous.metadata.matlab,version),'repro:ResumeMismatch','MATLAB version changed. Use a different outputDir.');
else
    assert(isempty(dir(fullfile(checkpointDir,'*.mat'))),'repro:OrphanCheckpoints','Checkpoint files exist without experiment.mat.');
    save(metadataFile,'metadata');
    fid=fopen(fullfile(cfg.outputDir,'experiment.json'),'w','n','UTF-8');
    assert(fid>=0); fprintf(fid,'%s',jsonencode(metadata,'PrettyPrint',true)); fclose(fid);
end
raw=table();
for f=cfg.functions
    for a=1:numel(cfg.algorithms)
        name=cfg.algorithms{a};
        for r=1:cfg.runs
            target=fullfile(checkpointDir,sprintf('F%02d_%s_run%03d.mat',f,name,r));
            if isfile(target)
                saved=load(target,'result'); result=saved.result;
                assert(result.functionId==f && strcmp(result.algorithm,name) && result.run==r ...
                    && result.seed==cfg.baseSeed+10000*f+r && result.actualFEs<=cfg.maxFEs ...
                    && strcmp(result.metric,metadata.metric),'repro:Checkpoint','Invalid checkpoint.');
            else
                fprintf('F%02d %-16s run %d/%d\n',f,name,r,cfg.runs);
                try
                    result=repro.run_one(cfg,name,f,r);
                catch err
                    failure=struct('functionId',f,'algorithm',name,'run',r,'seed',cfg.baseSeed+10000*f+r, ...
                        'identifier',err.identifier,'message',err.message,'report',getReport(err,'extended'));
                    save(fullfile(cfg.outputDir,'last_failure.mat'),'failure');
                    if ~isempty(raw), repro.write_raw_csv(raw,fullfile(cfg.outputDir,'raw_partial.csv')); end
                    rethrow(err); % A failed trial must never disappear from statistics.
                end
                tmp=[target '.tmp.mat']; save(tmp,'result'); movefile(tmp,target,'f');
            end
            raw=[raw; repro.result_row(result)]; %#ok<AGROW>
        end
    end
    repro.write_raw_csv(raw,fullfile(cfg.outputDir,'raw_partial.csv'));
end
repro.write_raw_csv(raw,fullfile(cfg.outputDir,'raw_final_fitness.csv'));
save(fullfile(cfg.outputDir,'raw_results.mat'),'raw','metadata');
fprintf('Saved %d complete run records to %s\n',height(raw),cfg.outputDir);
end
