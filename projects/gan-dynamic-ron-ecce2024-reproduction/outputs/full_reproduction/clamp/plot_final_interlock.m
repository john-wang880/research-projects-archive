function plot_final_interlock
out=fileparts(mfilename('fullpath'));cd(out);set(groot,'defaultAxesFontName','Arial');set(groot,'defaultAxesFontSize',11);
f=figure('Visible','off','Color','w','Position',[80 80 1240 830]);
subplot(2,2,1);
n={'wide_150V_neg5V','wide_150V_neg5V_early_btb_release','wide_safe_150V_neg5V'};
for k=1:3,d=readmatrix([n{k} '_waveforms.csv']);plot((d(:,1)-1e-6)*1e9,d(:,3),'LineWidth',1.4);hold on;end
yline(-5,'k:');xlim([-100 800]);ylim([-10 1]);grid on;xlabel('Time from DUT edge (ns)');ylabel('Output (V)');title('Recovery-window and gate-clamp sensitivity');legend('300 Ohm / late release','300 Ohm / early release','2 Ohm / full interlock','Location','best');
subplot(2,2,2);
for b=[50 150 400],for sign={'pos','neg'},d=readmatrix(sprintf('wide_safe_%dV_%s5V_waveforms.csv',b,sign{1}));plot((d(:,1)-1e-6)*1e9,d(:,3),'LineWidth',1.25);hold on;end,end
xlim([-100 250]);grid on;xlabel('Time from DUT edge (ns)');ylabel('Output (V)');title('50 / 150 / 400 V bus: +/-5 V measurement');legend('50 V, +5 V','50 V, -5 V','150 V, +5 V','150 V, -5 V','400 V, +5 V','400 V, -5 V','Location','best');
subplot(2,2,3);
for sign={'pos','neg'},d=readmatrix(['wide_safe_400V_' sign{1} '5V_waveforms.csv']);plot((d(:,1)-2e-6)*1e9,d(:,3),'LineWidth',1.4);hold on;end
xlim([-100 200]);grid on;xlabel('Time from DUT turn-off (ns)');ylabel('Output (V)');title({'400 V output protection','Nominal 8 V TVS has a dynamic clamp voltage'});legend('+5 V input','-5 V input','Location','best');
subplot(2,2,4);
d=readmatrix('diagnostic_wide_negative_strong_waveforms.csv');plot((d(:,1)-2e-6)*1e9,abs(d(:,end)),'LineWidth',1.3);hold on;
d=readmatrix('wide_safe_400V_neg5V_waveforms.csv');plot((d(:,1)-2e-6)*1e9,abs(d(:,4)),'LineWidth',1.4);set(gca,'YScale','log');ylim([1e-5 1e2]);xlim([-100 200]);grid on;xlabel('Time from DUT turn-off (ns)');ylabel('Absolute DUT-source current (A)');title('BTB closes after DUT voltage returns positive');legend('BTB closes while DUT negative','Full interlock','Location','best');
sgtitle({'Native nonlinear circuit: correct interlock preserves signed measurement and avoids the body-diode short','Measured-window error: 58.9-103.7 microV; source loading remains explicit, not assumed negligible'});
savefig(f,'wide_safe_interlock.fig');exportgraphics(f,'wide_safe_interlock.png','Resolution',160);close(f);disp('FINAL_INTERLOCK_PLOT_DONE');
end
