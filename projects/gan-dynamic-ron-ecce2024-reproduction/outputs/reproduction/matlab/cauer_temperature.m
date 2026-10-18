function [temperatureRise, diagnostics] = cauer_temperature(time_s, power_W, R_K_per_W, C_J_per_K)
%CAUER_TEMPERATURE Exact integration of a four-node Cauer thermal ladder.
% Junction=C1 -- R1 -- C2 -- R2 -- C3 -- R3 -- C4 -- R4 -- case.
% Every capacitor connects its thermal node to the temperature reference.
% Case temperature is fixed; states are rises above case temperature.
% Power is linearly interpolated between samples. Initial rise is zero.
% No Control System Toolbox is required.

time_s = time_s(:); power_W = power_W(:);
R = R_K_per_W(:); C = C_J_per_K(:);
assert(numel(R)==4 && numel(C)==4 && all(R>0) && all(C>0), ...
    'A positive four-stage Cauer network is required.');
assert(numel(time_s)==numel(power_W) && numel(time_s)>1 && ...
    all(isfinite(time_s)) && all(isfinite(power_W)) && all(diff(time_s)>0), ...
    'Time and power must be finite, equally sized, and time strictly increasing.');

g = 1./R;
G = [g(1), -g(1), 0, 0; ...
    -g(1), g(1)+g(2), -g(2), 0; ...
    0, -g(2), g(2)+g(3), -g(3); ...
    0, 0, -g(3), g(3)+g(4)];
sqrtC = sqrt(C);
S = G ./ (sqrtC*sqrtC.');
[Q,D] = eig((S+S.')/2);
lambda = diag(D);
assert(all(lambda>0), 'Thermal ladder must be asymptotically stable.');
b = Q.' * [1/sqrtC(1); 0; 0; 0];
modalToTemperature = Q ./ sqrtC;

n = numel(time_s);
temperatureRise = zeros(n,4);
integralTemperature_K_s = zeros(n,4);
inputEnergy_J = zeros(n,1);
modal = zeros(4,1);
integralModal = zeros(4,1);
for k = 2:n
    dt = time_s(k)-time_s(k-1);
    decay = exp(-lambda*dt);
    phi0 = -expm1(-lambda*dt)./lambda;
    phi1 = (dt-phi0)./lambda;
    slope = (power_W(k)-power_W(k-1))/dt;
    nextModal = decay.*modal + b.*(power_W(k-1)*phi0+slope*phi1);
    segmentEnergy = (power_W(k-1)+power_W(k))*dt/2;
    % Integral follows directly from dz/dt=-lambda*z+b*power.
    integralModal = integralModal + (b*segmentEnergy-nextModal+modal)./lambda;
    modal = nextModal;
    temperatureRise(k,:) = (modalToTemperature*modal).';
    integralTemperature_K_s(k,:) = (modalToTemperature*integralModal).';
    inputEnergy_J(k) = inputEnergy_J(k-1)+segmentEnergy;
end
storedEnergy_J = temperatureRise*C;
caseEnergy_J = integralTemperature_K_s(:,4)/R(4);
residual_J = inputEnergy_J-storedEnergy_J-caseEnergy_J;
diagnostics = struct('G_W_per_K',G,'C_J_per_K',C, ...
    'A_per_s',-G./C,'modalRates_per_s',lambda, ...
    'integralTemperature_K_s',integralTemperature_K_s, ...
    'inputEnergy_J',inputEnergy_J,'storedEnergy_J',storedEnergy_J, ...
    'caseEnergy_J',caseEnergy_J,'energyResidual_J',residual_J, ...
    'maximumAbsoluteEnergyResidual_J',max(abs(residual_J)), ...
    'maximumRelativeEnergyResidual',max(abs(residual_J))/max(max(abs(inputEnergy_J)),eps));
end
