function cfg = cec2017_config()
%CEC2017_CONFIG Explicit settings for a NEW, strictly budgeted experiment.
% The archived 5-method data have a separate reproduction entry point.
root = fileparts(mfilename('fullpath'));
cfg.schemaVersion = 1;
cfg.dimension = 30;                 % This compact distribution contains D30 only.
cfg.population = 30;                % Nominal input N, not every effective population.
cfg.maxFEs = 300000;
cfg.runs = 30;
cfg.functions = 1:30;
cfg.algorithms = {'RLDSBO','SBO','DSBO','EESHHO','GDTSCA','ICPA', ...
    'LNPRO','ABHGS','JADE','LSHADE_cnEpSi','SADE','EBOwithCMAR', ...
    'MPEDE','RLDSBO_Rand50','RL_HPSDE'};
cfg.lowerBound = -100;
cfg.upperBound = 100;
cfg.baseSeed = 20261003;
cfg.tracePoints = 100;
cfg.outputDir = fullfile(root,'results','new_30run_experiment');
end
