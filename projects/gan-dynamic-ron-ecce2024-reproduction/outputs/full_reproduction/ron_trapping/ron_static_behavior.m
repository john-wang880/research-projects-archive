function R_mOhm=ron_static_behavior(Id_A,Tc_C)
% Public Fig10 behavioral calibration, not an independently validated GaN model.
% Valid only in the plotted15..95C / approximately-50..50A domain at Vgs6V.
p=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'model_parameters.json')));
s=p.static; x=Id_A/50; z=(Tc_C-55)/40;
R_mOhm=zeros(size(x+z)); k=1;
for j=0:s.temperature_degree
    for i=0:s.current_degree
        R_mOhm=R_mOhm+s.coefficients_mOhm(k).*x.^i.*z.^j;k=k+1;
    end
end
end
