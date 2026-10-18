function plot_circuit()
%PLOT_CIRCUIT Native editable plots of exported LTspice and paper vectors.
% Main plot uses an amplitude zoom. Raw ideal-switch edge peaks are shown
% separately and must not be interpreted as physical GS66508B predictions.
taskDir=fileparts(mfilename('fullpath'));
rootDir=fileparts(taskDir);
outDir=fullfile(rootDir,'figures');if ~isfolder(outDir),mkdir(outDir);end
data={readtable(fullfile(rootDir,'data','conventional_waveforms.csv')), ...
      readtable(fullfile(rootDir,'data','proposed_waveforms.csv'))};
reference=readtable(fullfile(rootDir,'reference','figure13_current.csv'));
colors=[0.14,0.36,0.60;0.78,0.40,0.08];
labels={'Conventional','Proposed'};
timeOrigin_s=2e-6;

f=figure('Visible','off','Color','w','Position',[100,100,1200,1080]);
tl=tiledlayout(f,3,1,'TileSpacing','compact','Padding','compact');
axesList=gobjects(3,1);
for k=1:3
    axesList(k)=nexttile(tl);hold on;
    patch([33.5,38.5,38.5,33.5],[-3,-3,65,65],[0.73,0.87,0.74], ...
        'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
    xline(32.5,':','Color',[0.45,0.45,0.45],'HandleVisibility','off');
    ylim([-3,65]);xlim([-1,43]);grid on;box on;
    set(gca,'FontSize',11,'Layer','top');ylabel('Current (A)');
end
for k=1:2
    D=data{k};time_us=(D.time_s-timeOrigin_s)*1e6;
    plot(axesList(1),time_us,D.dut_load_conduction_A,'Color',colors(k,:),'LineWidth',1.6, ...
        'DisplayName',[labels{k},' DUT load conduction']);
    plot(axesList(2),time_us,D.dut_terminal_current_A,'Color',colors(k,:),'LineWidth',1.6, ...
        'DisplayName',[labels{k},' local shunt current']);
    plot(axesList(3),time_us,D.ls1_current_A,'Color',colors(k,:),'LineWidth',1.6, ...
        'DisplayName',[labels{k},' LS1 drain-to-source']);
end
plot(axesList(2),reference.time_us,reference.conventional_A,'--','Color',colors(1,:), ...
    'LineWidth',1.2,'DisplayName','Conventional paper plotted curve');
plot(axesList(2),reference.time_us,reference.proposed_A,'--','Color',colors(2,:), ...
    'LineWidth',1.2,'DisplayName','Proposed paper plotted curve');
title(axesList(1),'DUT load-conduction pattern; green region is the nominal 5 us measurement');
title(axesList(2),'Local terminal current and original Figure 13 vectors');
title(axesList(3),'Parallel LS1 branch charges the inductor and is off during measurement');
xlabel(axesList(3),'Time from start of inductor charging (us)');
for ax=axesList.'
    legend(ax,'Location','northwest','FontSize',10,'AutoUpdate','off');
end
linkaxes(axesList,'x');
title(tl,{'Figure 13 current mechanism: fixed-Ron functional model', ...
    '150 V / 90 uH / 500 uF; amplitude zoom, full switching peaks shown separately'}, ...
    'FontSize',15,'FontWeight','bold');
savefig(f,fullfile(outDir,'figure13_circuit_comparison.fig'));
exportgraphics(f,fullfile(outDir,'figure13_circuit_comparison.png'),'Resolution',180);
set(f,'PaperPositionMode','auto');
print(f,fullfile(outDir,'figure13_circuit_comparison.svg'),'-dsvg','-painters');
close(f);

f=figure('Visible','off','Color','w','Position',[100,100,1240,560]);
tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
axesList=gobjects(2,1);
for j=1:2
    axesList(j)=nexttile(tl);hold on;
    for k=1:2
        time_us=(data{k}.time_s-timeOrigin_s)*1e6;
        plot(time_us,data{k}.dut_current_A,'Color',colors(k,:),'LineWidth',1.3, ...
            'DisplayName',labels{k});
    end
    ylim([0,2000]);grid on;box on;
    xlabel('Time from charging start (us)');ylabel('Raw channel current (A)');
    set(gca,'FontSize',11);
end
xlim(axesList(1),[-1,43]);xlim(axesList(2),[33.522,33.54]);
title(axesList(1),'Full amplitude, including numerical edge spikes');
title(axesList(2),'Measurement turn-on edge zoom');
legend(axesList(1),'Location','northwest','AutoUpdate','off');
title(tl,{'Nonphysical ideal-switch / assumed-Coss transient', ...
    'Diagnostic only; not a physical GS66508B switching-current prediction'}, ...
    'FontSize',15,'FontWeight','bold');
savefig(f,fullfile(outDir,'model_edge_diagnostic.fig'));
exportgraphics(f,fullfile(outDir,'model_edge_diagnostic.png'),'Resolution',180);
set(f,'PaperPositionMode','auto');print(f,fullfile(outDir,'model_edge_diagnostic.svg'),'-dsvg','-painters');
close(f);
fprintf('Saved PNG, native FIG and SVG plots under %s\n',outDir);
end
