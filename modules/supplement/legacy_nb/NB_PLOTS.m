function NB_PLOTS(root,stage)
% Each trajectory figure uses locked fits, never probe-based early selection.
    base=fullfile(root,stage);fs=dir(fullfile(base,'windowA*','fits','*','fit.mat'));
    out=fullfile(base,'figures');P0_IO('mkdir',out);
    groups={};
    for i=1:numel(fs)
        a=P0_IO('load',fullfile(fs(i).folder,fs(i).name));
        groups{end+1}=sprintf('%s_%s_r%03d',a.record.Dataset,a.record.Condition,a.record.Repeat); %#ok<AGROW>
    end
    keys=unique(groups);
    for g=1:numel(keys)
        f=figure('Visible','off','Color','w');hold on;names={};
        for i=find(strcmp(groups,keys{g}))
            a=P0_IO('load',fullfile(fs(i).folder,fs(i).name));
            if ~isfield(a,'checkpointMetrics'),continue;end
            z=a.checkpointMetrics;plot([z.Seconds],[z.NRE],'-','LineWidth',1.3);
            names{end+1}=a.record.Method; %#ok<AGROW>
        end
        xlabel('Algorithm wall time (s; excludes posthoc evaluation)');ylabel('NRE');
        title(strrep(keys{g},'_',' '));legend(names,'Interpreter','none','Location','best');grid on;
        print(f,fullfile(out,[keys{g} '_NRE_time.png']),'-dpng','-r180');close(f);
    end
end
