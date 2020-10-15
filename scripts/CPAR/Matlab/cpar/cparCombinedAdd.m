function cparCombinedAdd(combined, waveform)
% cparCombinedAdd Add a waveform to a combined waveform
%   [out] = cparCombinedAdd(combined, waveform) add the waveform
%   [waveform] to the combined waveform [combined].
%
% See also, cparPulse, cparRamp, cparCombined, cparCreateStimulus
list = combined.StimulusList;
list.Add(waveform);