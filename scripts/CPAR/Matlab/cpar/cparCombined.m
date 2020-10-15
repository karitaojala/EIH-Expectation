function [combined] = cparCombined()
% cparCombined Create a combined waveform
%   [combined] = cparCombined() this created a combined waveform that
%   can be used to combine other waveforms (Pulse, Ramp, and Combined).
%   with this complex stimulation patterns can be constructed. When
%   created the combined waveform is empty. Use the cparCombinedAdd() 
%   function to add waveforms to the combined waveform.
%
%   Create a stimulus that can be used to set the pressure generation 
%   for a channel with the cparCreateStimulus function.
%
%   Please note that Pulses and Ramps cannot overlap in time.
%
% See also, cparPulse, cparRamp, cparCreateStimulus
combined = LabBench.Interface.Stimuli.CombinedStimulus;