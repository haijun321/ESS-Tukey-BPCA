function P0_PLOTS(C,module,R)
% All error bars are SD across repeats, not confidence bands.
% PDF and 300-dpi JPG; TIFF optional. No fitted outputs are synthesized here.
    out=fullfile(C.outputRoot,module,'figures');P0_IO('mkdir',out);
    if any(strcmp(module,{'core_synthetic','main_synthetic'}))
        ids=unique({R.MethodID},'stable');types={'sample','impulse','block_random','block_coherent'};
        names={'Samplewise','Impulse','Random blocks','Coherent blocks'};
        metrics={'NRE','ErrSubNorm'};
        for strength=[2 4]
            for mm=1:numel(metrics)
                metric=metrics{mm};fig=newfig(17.8,12.8);colors=lines(numel(ids));
                for t=1:4
                    ax=subplot(2,2,t);hold(ax,'on');
                    for j=1:numel(ids)
                        z=R(strcmp({R.MethodID},ids{j})&strcmp({R.Type},types{t})&[R.Strength]==strength);
                        rates=unique([z.NominalRate]);mu=nan(size(rates));sd=mu;
                        for k=1:numel(rates),v=[z(abs([z.NominalRate]-rates(k))<1e-12).(metric)];mu(k)=mean(v);sd(k)=std(v);end
                        errorbar(ax,rates*100,mu,sd,'-o','Color',colors(j,:),'MarkerSize',3,'LineWidth',1);
                    end
                    title(ax,sprintf('(%s) %s',char('A'+t-1),names{t}),'FontWeight','normal');
                    xlabel(ax,'Nominal contamination (%)');ylabel(ax,metric);style(ax);
                    if t==1,legend(ax,ids,'Location','best','Interpreter','none','FontSize',7);end
                end
                savefigure(fig,fullfile(out,sprintf('%s_k%d',metric,strength)),C);
            end
        end
    elseif ~isempty(strfind(module,'solver')) %#ok<STREMP>
        ids=unique({R.MethodID},'stable');fig=newfig(17.8,7);ax=subplot(1,2,1);hold(ax,'on');colors=lines(numel(ids));values=[];
        for j=1:numel(ids)
            new=R(strcmp({R.MethodID},ids{j})&strcmp({R.SolverVersion},'v2'));
            old=R(strcmp({R.MethodID},ids{j})&strcmp({R.SolverVersion},'legacy'));
            x=[];y=[];
            for k=1:numel(new)
                ix=find(strcmp({old.Dataset},new(k).Dataset)&strcmp({old.Condition},new(k).Condition)&[old.Repeat]==new(k).Repeat);
                if numel(ix)==1,x(end+1)=old(ix).NRE;y(end+1)=new(k).NRE;end %#ok<AGROW>
            end
            plot(ax,x,y,'o','Color',colors(j,:),'MarkerSize',4);values=[values x y]; %#ok<AGROW>
        end
        if ~isempty(values),lim=[min(values) max(values)];if diff(lim)==0,lim=lim+[-.01 .01];end;plot(ax,lim,lim,'k--');end
        xlabel(ax,'Legacy NRE');ylabel(ax,'Revised NRE');title(ax,'(A) Paired representation error','FontWeight','normal');style(ax);
        legend(ax,ids,'Location','best','Interpreter','none','FontSize',7);
        ax=subplot(1,2,2);labels=unique({R.Status});v=zeros(numel(labels),2);
        for j=1:numel(labels)
            v(j,1)=sum(strcmp({R.Status},labels{j})&strcmp({R.SolverVersion},'legacy'));
            v(j,2)=sum(strcmp({R.Status},labels{j})&strcmp({R.SolverVersion},'v2'));
        end
        bar(ax,v);set(ax,'XTick',1:numel(labels),'XTickLabel',labels,'XTickLabelRotation',35,'TickLabelInterpreter','none');
        ylabel(ax,'Fits');title(ax,'(B) Recorded termination events','FontWeight','normal');legend(ax,{'Legacy','Revised'},'Location','best');style(ax);
        savefigure(fig,fullfile(out,'solver_paired'),C);
    elseif any(strcmp(module,{'core_real','extension_real','tune_real','pilot_real'}))
        datasets=unique({R.Dataset});ids=unique({R.MethodID},'stable');fig=newfig(17.8,7);colors=lines(numel(ids));
        for d=1:numel(datasets)
            ax=subplot(1,numel(datasets),d);hold(ax,'on');z=R(strcmp({R.Dataset},datasets{d}));conds=unique({z.Condition},'stable');
            for j=1:numel(ids)
                mu=nan(1,numel(conds));sd=mu;
                for k=1:numel(conds),ix=strcmp({z.MethodID},ids{j})&strcmp({z.Condition},conds{k});v=[z(ix).NRE];if ~isempty(v),mu(k)=mean(v);sd(k)=std(v);end;end
                errorbar(ax,1:numel(conds),mu,sd,'-o','Color',colors(j,:),'MarkerSize',3,'LineWidth',1);
            end
            set(ax,'XTick',1:numel(conds),'XTickLabel',conds);ylabel(ax,'Clean-probe NRE');
            title(ax,sprintf('(%s) %s',char('A'+d-1),datasets{d}),'FontWeight','normal');style(ax);
            if d==1,legend(ax,ids,'Location','best','Interpreter','none','FontSize',7);end
        end
        savefigure(fig,fullfile(out,'real_NRE'),C);
    end
end

function f=newfig(w,h)
    f=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 w h]);
    set(f,'PaperUnits','centimeters','PaperPosition',[0 0 w h],'PaperSize',[w h]);
end
function style(ax)
    set(ax,'FontName','Helvetica','FontSize',9,'LineWidth',.7,'Box','on');grid(ax,'on');
end
function savefigure(f,path,C)
    cleanup=onCleanup(@()close(f));
    print(f,[path '.pdf'],'-dpdf','-painters');print(f,[path '.jpg'],'-djpeg','-r300');
    if C.exportTIFF,print(f,[path '.tiff'],'-dtiff','-r300');end
    savefig(f,[path '.fig']);clear cleanup;
end
