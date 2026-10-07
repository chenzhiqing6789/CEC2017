function plot_convergence(input, outputDir, functions)
%PLOT_CONVERGENCE Plot mean absolute fitness; never invent historical FE labels.
% input: historical sampled_convergence.csv OR a new experiment directory.
if nargin<3, functions=[1 10 11 25]; end
if ~isfolder(outputDir), mkdir(outputDir); end
historical=isfile(input);
if historical
    curves=readtable(input,'TextType','string');
    algorithms=unique(curves.Algorithm,'stable');
else
    meta=load(fullfile(input,'experiment.mat'),'metadata');
    cfg=meta.metadata.cfg; algorithms=string(cfg.algorithms);
end
for f=functions
    fig=figure('Visible','off','Color','w'); guard=onCleanup(@() close(fig));
    hold on;
    for ai=1:numel(algorithms)
        name=algorithms(ai);
        if historical
            selected=curves(curves.Function==f & curves.Algorithm==name,:);
            assert(~isempty(selected),'repro:Plot','No curve records.');
            x=1:40; y=mean(selected{:,4:end},1);
        else
            ys=[]; x=[];
            for r=1:cfg.runs
                saved=load(fullfile(input,'checkpoints',sprintf('F%02d_%s_run%03d.mat',f,name,r)),'result');
                if isempty(x), x=saved.result.traceFEs; end
                assert(isequal(x,saved.result.traceFEs),'repro:Plot','Inconsistent/early-ended traces; plot separately.');
                ys(r,:)=saved.result.traceFitness; %#ok<AGROW>
            end
            y=mean(ys,1);
        end
        plot(x,y,'LineWidth',1.3,'DisplayName',char(name));
    end
    if historical, xlabel('Recorded sample index (exact FE times unavailable)');
    else, xlabel('Actual function evaluations'); end
    set(gca,'YScale','log'); % All supplied CEC2017 absolute fitness values are positive.
    ylabel('Mean absolute objective value (log scale)'); title(sprintf('CEC2017 F%d, D = 30',f));
    legend('Location','best','Interpreter','none'); grid on; box on;
    exportgraphics(fig,fullfile(outputDir,sprintf('F%02d.png',f)),'Resolution',180);
    exportgraphics(fig,fullfile(outputDir,sprintf('F%02d.pdf',f)),'ContentType','vector');
    clear guard
end
end
