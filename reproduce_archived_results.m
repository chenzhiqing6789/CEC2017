function report = reproduce_archived_results(outputDir)
%REPRODUCE_ARCHIVED_RESULTS Regenerate 5-method statistics without optimization.
root=fileparts(mfilename('fullpath'));
if nargin==0, outputDir=fullfile(root,'results','archived_5alg_statistics'); end
dataDir=fullfile(root,'data','archived_5alg_30runs');
raw=readtable(fullfile(dataDir,'raw_final_fitness.csv'),'TextType','string');
report=analyze_results(raw,outputDir,'RLDSBO');
sampled=readtable(fullfile(dataDir,'sampled_convergence.csv'),'TextType','string');
assert(height(raw)==4500 && height(sampled)==4500,'repro:Archive','Wrong archive size.');
assert(isequal(raw(:,1:3),sampled(:,1:3)) && isequal(raw.Fitness,sampled.Sample40),'repro:Archive','Final fitness and sampled trajectory disagree.');
save(fullfile(outputDir,'archived_raw_results.mat'),'raw','sampled');
expectedRanks=[1.5;1.766666666666667;3.333333333333333;4.966666666666667;3.433333333333333];
assert(max(abs(report.rankSummary.AverageRankOfFunctionMeans-expectedRanks))<1e-10,'repro:ArchiveMismatch','Paper A1 ranks do not match.');
assert(isequal([report.winLoss.Wins report.winLoss.Losses report.winLoss.Nonsignificant], ...
    [6 2 22;29 0 1;30 0 0;27 1 2]),'repro:ArchiveMismatch','Paper A2 counts do not match.');
plot_convergence(fullfile(dataDir,'sampled_convergence.csv'),fullfile(outputDir,'convergence'),[7 8 9 12 18 25]);
fprintf('Verified archived A1 mean ranks and A2 win/loss counts using 4500 records.\n');
end
