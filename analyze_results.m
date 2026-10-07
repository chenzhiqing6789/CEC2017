function report = analyze_results(input, outputDir, reference)
%ANALYZE_RESULTS Statistics on complete paired independent-run records.
% Paired run-index signrank tests are two-sided; p values are unadjusted.
% Friedman blocks are FUNCTIONS and entries are per-function mean fitness.
% Historical recorded fitness and new best-evaluated fitness cannot be mixed.
if nargin<3, reference='RLDSBO'; end
if ischar(input)||isstring(input)
    raw=readtable(input,'TextType','string');
else
    raw=input;
end
assert(istable(raw)&&all(ismember({'Function','Algorithm','Run','Fitness','Metric'},raw.Properties.VariableNames)), ...
    'repro:Data','Expected Function, Algorithm, Run, Fitness, Metric columns.');
assert(~isempty(raw),'repro:Data','Empty input.');
raw.Algorithm=string(raw.Algorithm); raw.Metric=string(raw.Metric);
assert(numel(unique(raw.Metric))==1 && all(~ismissing(raw.Metric)),'repro:MixedMetric','Do not mix different fitness definitions.');
assert(all(isfinite(raw.Fitness)) && all(isfinite(raw.Function)) && all(isfinite(raw.Run)), ...
    'repro:Data','Missing/nonfinite values are not silently omitted.');
assert(all(raw.Run>=1 & raw.Run==fix(raw.Run)) && all(raw.Function>=1 & raw.Function<=30 & raw.Function==fix(raw.Function)), ...
    'repro:Data','Invalid function/run indices.');
assert(height(unique(raw(:,{'Function','Algorithm','Run'}),'rows'))==height(raw),'repro:Duplicate','Duplicate function/algorithm/run key.');
functions=unique(raw.Function); algorithms=unique(raw.Algorithm,'stable'); runs=unique(raw.Run);
assert(numel(runs)>=2 && isequal(runs(:),(1:numel(runs))'),'repro:Data','Runs must be complete consecutive indices starting at 1.');
assert(all(~ismissing(algorithms)),'repro:Data','Missing algorithm name.');
assert(height(raw)==numel(functions)*numel(algorithms)*numel(runs),'repro:Incomplete','Incomplete function/algorithm/run grid.');
if ismember('Status',raw.Properties.VariableNames)
    assert(all(ismember(string(raw.Status),["completed","budget_reached","returned_early"])), ...
        'repro:FailedRun','Failed runs may not be analyzed as successes.');
end
ref=find(algorithms==string(reference)); assert(isscalar(ref),'repro:Reference','Reference algorithm absent.');
F=numel(functions); A=numel(algorithms); R=numel(runs);
values=nan(F,R,A); means=nan(F,A); stds=means; medians=means;
for fi=1:F
    for ai=1:A
        rows=raw(raw.Function==functions(fi)&raw.Algorithm==algorithms(ai),:);
        rows=sortrows(rows,'Run');
        assert(isequal(rows.Run,runs),'repro:Incomplete','Mismatched run indices.');
        values(fi,:,ai)=rows.Fitness;
        means(fi,ai)=mean(rows.Fitness); stds(fi,ai)=std(rows.Fitness,0); medians(fi,ai)=median(rows.Fitness);
    end
end
[fg,ag]=ndgrid(functions,1:A);
summary=table(fg(:),algorithms(ag(:)),repmat(R,F*A,1),means(:),stds(:),medians(:), ...
    'VariableNames',{'Function','Algorithm','Runs','Mean','Std','Median'});
ranks=nan(F,A); for fi=1:F, ranks(fi,:)=tiedrank(means(fi,:)); end
rankSummary=table(algorithms,mean(ranks,1)','VariableNames',{'Algorithm','AverageRankOfFunctionMeans'});
rankByFunction=array2table([functions ranks],'VariableNames',[{'Function'} cellstr(algorithms')]);
comparisons=table(); counts=zeros(A-1,3); ci=0;
for ai=1:A
    if ai==ref, continue; end
    ci=ci+1;
    for fi=1:F
        x=reshape(values(fi,:,ref),[],1); y=reshape(values(fi,:,ai),[],1);
        if all(x==y), p=1; else, p=signrank(x,y,'tail','both'); end
        outcome="nonsignificant";
        if p<0.05 && means(fi,ref)<means(fi,ai), outcome="win"; counts(ci,1)=counts(ci,1)+1;
        elseif p<0.05 && means(fi,ref)>means(fi,ai), outcome="loss"; counts(ci,2)=counts(ci,2)+1;
        else, counts(ci,3)=counts(ci,3)+1; end
        comparisons=[comparisons;table(functions(fi),string(reference),algorithms(ai),p,outcome, ...
            'VariableNames',{'Function','Reference','Comparator','PValueUnadjusted','Outcome'})]; %#ok<AGROW>
    end
end
others=algorithms(algorithms~=string(reference));
winLoss=table(others,counts(:,1),counts(:,2),counts(:,3),'VariableNames',{'Comparator','Wins','Losses','Nonsignificant'});
if F<2 || A<2
    friedmanP=NaN; friedmanTable={}; friedmanStats=struct();
elseif all(all(means==means(:,1)))
    friedmanP=1; friedmanTable={}; friedmanStats=struct('meanranks',mean(ranks,1));
else
    [friedmanP,friedmanTable,friedmanStats]=friedman(means,1,'off');
    assert(max(abs(friedmanStats.meanranks-mean(ranks,1)))<1e-10,'repro:Ranks','Unexpected Friedman block definition.');
end
report=struct('summary',summary,'rankSummary',rankSummary,'rankByFunction',rankByFunction, ...
    'comparisons',comparisons,'winLoss',winLoss,'friedmanP',friedmanP,'friedmanTable',{friedmanTable}, ...
    'friedmanStats',friedmanStats,'metric',char(unique(raw.Metric)),'reference',reference, ...
    'functions',functions,'algorithms',algorithms,'runs',R,'values',values);
if nargin>=2 && ~isempty(outputDir)
    if ~isfolder(outputDir), mkdir(outputDir); end
    writetable(summary,fullfile(outputDir,'mean_std.csv'));
    writetable(rankSummary,fullfile(outputDir,'average_ranks.csv'));
    writetable(rankByFunction,fullfile(outputDir,'ranks_by_function.csv'));
    writetable(comparisons,fullfile(outputDir,'wilcoxon_signed_rank.csv'));
    writetable(winLoss,fullfile(outputDir,'win_loss_counts.csv'));
    writetable(table(friedmanP,F,A,R,'VariableNames',{'PValue','FunctionBlocks','Algorithms','RunsPerMean'}),fullfile(outputDir,'friedman_test.csv'));
    save(fullfile(outputDir,'statistics.mat'),'report');
end
end
