function open_models()
% Open the three primary native models without rebuilding or running them.
base=fileparts(mfilename('fullpath'));
open_system(fullfile(base,'simulink','GaN_Full_Bridge_SPS.slx'));
open_system(fullfile(base,'clamp','GaN_Clamp_Wide_Range_Analog_State.slx'));
open_system(fullfile(base,'tec','TEC_Electrothermal_ClosedLoop.slx'));
end
