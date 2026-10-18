function validation = validate_cauer()
%VALIDATE_CAUER DC, energy-balance and independent ODE checks.
% These analytic inputs verify the numerical solver, not the paper results.
outDir=fileparts(mfilename('fullpath'));
R=[0.015;0.23;0.24;0.015]; C=[8e-5;7.4e-4;6.5e-3;2e-3];
t=(0:2e-6:0.03).'; P=10*ones(size(t));
[T,d]=cauer_temperature(t,P,R,C);
expected=10*[sum(R);sum(R(2:end));sum(R(3:end));R(4)];
dcError=max(abs(T(end,:).'-expected));
assert(dcError<1e-6,'DC equilibrium must equal series thermal resistance.');
assert(d.maximumRelativeEnergyResidual<1e-10,'Thermal energy balance failed.');
tp=unique([(0:0.05e-6:120e-6).';0;30e-6;60e-6;65e-6]);
pp=80*max(0,min((tp-5e-6)/25e-6,1));
pp(tp>60e-6)=80*max(0,(65e-6-tp(tp>60e-6))/5e-6);
[exact,de]=cauer_temperature(tp,pp,R,C);
g=1./R;
G=[g(1),-g(1),0,0;-g(1),g(1)+g(2),-g(2),0; ...
    0,-g(2),g(2)+g(3),-g(3);0,0,-g(3),g(3)+g(4)];
rhs=@(tau,x) (-G*x+[interp1(tp,pp,tau,'linear');0;0;0])./C;
options=odeset('RelTol',1e-9,'AbsTol',1e-11,'MaxStep',0.05e-6);
[~,independent]=ode15s(rhs,tp,zeros(4,1),options);
maxOdeDifference=max(abs(exact-independent),[],'all');
assert(maxOdeDifference<1e-5,'Independent ode15s solution disagrees.');
validation=struct('CauerTopology','C1 at junction; series R1,R2,R3,R4; fixed case after R4', ...
    'dcExpectedRise_K',expected.','dcComputedRise_K',T(end,:), ...
    'dcMaxError_K',dcError, ...
    'stepEnergyBalanceRelativeResidual',d.maximumRelativeEnergyResidual, ...
    'pulseEnergyBalanceRelativeResidual',de.maximumRelativeEnergyResidual, ...
    'maximumIndependentOdeDifference_K',maxOdeDifference, ...
    'passed',true,'testInputType','Analytic verification only; not paper reproduction');
fid=fopen(fullfile(outDir,'thermal_validation_metrics.json'),'w');
fprintf(fid,'%s\n',jsonencode(validation,'PrettyPrint',true));fclose(fid);
disp(validation);
end
