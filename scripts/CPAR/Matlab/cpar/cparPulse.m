function [pulse] = cparPulse(Is, Ts, Tdelay)
% cparPulse Create a rectangular stimulus
pulse = LabBench.Interface.Stimuli.Pulse;
pulse.Is = Is;
pulse.Ts = Ts;
pulse.Tdelay = Tdelay;