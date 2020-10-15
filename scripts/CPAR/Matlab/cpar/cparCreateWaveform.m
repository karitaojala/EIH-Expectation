function [func] = cparCreateWaveform(channel, repeat)
% cparCreateWaveformProgram Create a waveform program
%   [func] = cparCreateWaveformProgram(channel, repeat)
func = LabBench.CPAR.Functions.SetWaveformProgram;
func.Channel = channel - 1;
func.Repeat = repeat;
