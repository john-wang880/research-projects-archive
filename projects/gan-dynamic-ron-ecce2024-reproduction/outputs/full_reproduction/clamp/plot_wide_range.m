function plot_wide_range
out=fileparts(mfilename('fullpath'));cd(out);set(groot,'defaultAxesFontName','Arial');set(groot,'defaultAxesFontSize',11);
f=figure('Visible','off','Color','w','Position',[80 80 1260 820]);
subplot(2,2,1);
for s={'pos','neg'}
 d=readmatrix(['wide_150V_' s{1} '5V_waveforms.csv']);plot((d(:,1)-1e-6)*1e9,d(:,3),'LineWidth',1.5);hold on;
end
yline(5,'k:');yline(-5,'k:');xlim([-50 800]);ylim([-6 6]);grid on;xlabel('Time from DUT edge (ns)');ylabel('Measured output (V)');title({'150 V bus / +/-5 V input','Original representative macro model: negative range failure'});legend('+5 V input','-5 V input','Location','best');
subplot(2,2,2);
m=jsondecode(fileread('wide_range_metrics.json'));e=zeros(3,2);for b=1:3,for s=1:2,k=2*(b-1)+s;e(b,s)=100*m(k).steady_error_V/abs(m(k).on_voltage_V);end,end
bar([50 150 400],e);grid on;ylim([-2 16]);yline(2,'k--','2% acceptance');xlabel('DUT off voltage (V)');ylabel('Signed error / 5 V (%)');title('Range boundary retained as failed prediction');legend('-5 V input','+5 V input','Location','best');
subplot(2,2,3);
for b=[50 150 400]
 d=readmatrix(sprintf('wide_%dV_pos5V_waveforms.csv',b));plot((d(:,1)-2e-6)*1e9,d(:,3),'LineWidth',1.4);hold on;
end
xlim([-100 200]);grid on;xlabel('Time from DUT turn-off (ns)');ylabel('Measured output (V)');title('Protection during turn-off at +5 V');legend('50 V','150 V','400 V','Location','best');
subplot(2,2,4);
for b=[50 150 400]
 d=readmatrix(sprintf('wide_%dV_neg5V_waveforms.csv',b));plot((d(:,1)-2e-6)*1e9,d(:,3),'LineWidth',1.4);hold on;
end
xlim([-100 200]);grid on;xlabel('Time from DUT turn-off (ns)');ylabel('Measured output (V)');title('Protection during turn-off at -5 V');legend('50 V','150 V','400 V','Location','best');
sgtitle({'Wide-range check: 50 / 150 / 400 V bus, no fitting to experimental response','ST + Diodes official macros; topology valid near +/-0.48 V, negative limit is diagnosed separately'});
savefig(f,'wide_range_original_models.fig');exportgraphics(f,'wide_range_original_models.png','Resolution',160);close(f);disp('WIDE_RANGE_PLOT_DONE');
end
