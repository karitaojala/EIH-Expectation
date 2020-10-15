function [ramp] = cparRamp(Is, Ts, Tdelay)
% cparRamp Create a ramp waveform
%   [ramp] = cparRamp(Is, Ts, Tdelay)
ramp = LabBench.Interface.Stimuli.Ramp;
ramp.Is = Is;
ramp.Ts = Ts;
ramp.Tdelay = Tdelay;