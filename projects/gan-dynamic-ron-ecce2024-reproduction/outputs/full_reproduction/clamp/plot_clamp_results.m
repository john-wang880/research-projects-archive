function plot_clamp_results
out=fileparts(mfilename('fullpath'));cd(out);set(groot,'defaultAxesFontName','Arial');set(groot,'defaultAxesFontSize',11);
base={'improved_positive','blocking_positive','current_mirror_reduced'};
f=figure('Visible','off','Color','w','Position',[80 80 1220 820]);
subplot(2,2,1);
for k=1:3
 d=readmatrix([base{k} '_waveforms.csv']);plot((d(:,1)-1e-6)*1e9,d(:,3),'LineWidth',1.4);hold on;
end
xlim([-80 400]);ylim([-9 9]);grid on;xlabel('Time from DUT edge (ns)');ylabel('Output (V)');title('Nonlinear LTspice circuit simulation');legend('BTB 4.5 V / 20 Ohm','BTB held OFF','Ideal mirror ports + BAS21','Location','best');
subplot(2,2,2);
names={'improved_positive','improved_strong_drive_positive','improved_slow_release_positive'};
for k=1:3,d=readmatrix([names{k} '_waveforms.csv']);plot((d(:,1)-1e-6)*1e9,d(:,3),'LineWidth',1.4);hold on;end
xlim([-80 400]);grid on;xlabel('Time from DUT edge (ns)');ylabel('Output (V)');title('BTB gate charge / driver sensitivity');legend('4.5 V / 20 Ohm','10 V / 2 Ohm','4.5 V / 300 Ohm','Location','best');
subplot(2,2,3);
names={'improved_positive','improved_negative','blocking_positive','blocking_negative'};
for k=1:4,d=readmatrix([names{k} '_waveforms.csv']);plot((d(:,1)-1e-6)*1e9,d(:,3),'LineWidth',1.3);hold on;end
xlim([-30 180]);grid on;xlabel('Time from DUT edge (ns)');ylabel('Output (V)');title('Signed voltage measurement capability');legend('BTB +0.48 V','BTB -0.48 V','OFF +0.48 V','OFF -0.48 V','Location','best');
subplot(2,2,4);
for k=1:3,d=readmatrix([base{k} '_waveforms.csv']);plot((d(:,1)-2e-6)*1e9,d(:,3),'LineWidth',1.4);hold on;end
xlim([-100 200]);grid on;xlabel('Time from DUT turn-off (ns)');ylabel('Output (V)');title('Off-state protection and diode recovery');legend('BTB 4.5 V / 20 Ohm','BTB held OFF','Ideal mirror ports + BAS21','Location','best');
sgtitle({'Fig.5 mechanism with official representative semiconductor models','Illustrative timing / parasitics; original Fig.6 275 / 160 / 120 ns not fitted'});
savefig(f,'clamp_ltspice_comparison.fig');exportgraphics(f,'clamp_ltspice_comparison.png','Resolution',160);close(f);

f=figure('Visible','off','Color','w','Position',[70 60 1100 920]);
labels={'Id','improved','blocking','current_mirror'};response=[nan 275 160 120];sigma=[nan 90.3 525.4 695];
for k=1:4
 d=readmatrix(['fig6_digitized_' labels{k} '.csv']);subplot(4,1,k);plot(d(:,1),d(:,2),'LineWidth',1.3);grid on;xlim([-250 500]);
 if k==1,ylabel('Current (A)');title('Original Fig.6 trace digitization (reference, not simulation)');else,ylabel('Voltage (V)');title(sprintf('%s: published response %g ns; sigmaRon %g microOhm',strrep(labels{k},'_',' '),response(k),sigma(k)));end
 if k==4,xlabel('Time (ns)');end
end
savefig(f,'fig6_source_digitized.fig');exportgraphics(f,'fig6_source_digitized.png','Resolution',160);close(f);

% Uniform quantization floor is a budget, not reproduction of the measured noise.
span=[1.6 20 8];I=10;bits=12;labels={'Improved','Blocking FET','Current mirror'};
lsb=span/2^bits;sigma_quant_R=lsb/sqrt(12)/I;gain_error_R=.005*span/I;
published_sigma=[90.3 525.4 695];
budget=struct('illustrative_span_V',span,'nominal_bits',bits,'illustrative_current_A',I,'sigma_uniform_quantization_uOhm',sigma_quant_R*1e6,'gain_0p5percentFS_bound_mOhm',gain_error_R*1e3,'published_sigmaRon_uOhm',published_sigma,'published_noise_ratio_to_improved',published_sigma/published_sigma(1),'actual_author_fullscale','not stated','measurement_filter','20 MHz bandwidth plus unspecified noise filter','limitation','ideal 12 bit budget excludes analog noise, current uncertainty, offset, ENOB and overshoot recovery');
fid=fopen('noise_range_budget.json','w');fprintf(fid,'%s',jsonencode(budget));fclose(fid);
writetable(table(labels',span',lsb',sigma_quant_R'*1e6,gain_error_R'*1e3,published_sigma','VariableNames',{'Circuit','AssumedSpanV','Nominal12bitStepV','UniformQuantNoiseMicroOhm','GainBoundMilliOhm','PublishedSigmaMicroOhm'}),'noise_range_budget.csv');
f=figure('Visible','off','Color','w','Position',[80 90 1120 520]);
subplot(1,2,1);bar(categorical(labels,labels),[sigma_quant_R'*1e6 published_sigma']);set(gca,'YScale','log');grid on;ylabel('Equivalent resistance noise (microOhm)');title({'Assumed span: 1.6 / 20 / 8 V, I = 10 A','Quantization budget versus published measurement'});legend('Ideal uniform 12 bit floor','Published Fig.6 sigma','Location','northwest');
subplot(1,2,2);fs=logspace(-1,2,300);loglog(fs,fs/2^12/sqrt(12)/10*1e6,'LineWidth',1.7);grid on;xlabel('Assumed total voltage span (V)');ylabel('Uniform quantization sigmaR (microOhm)');title({'Range sets the nominal ADC floor','Unknown analog noise limits exact reproduction'});
savefig(f,'noise_range_budget.fig');exportgraphics(f,'noise_range_budget.png','Resolution',160);close(f);
fprintf('CLAMP_PLOTS_COMPLETE\n');
end
