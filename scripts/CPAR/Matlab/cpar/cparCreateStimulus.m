function [stimulus] = cparCreateStimulus(channel, repeat, waveform)
% cparCreateStimulus Create a stimulus from a waveform
%    [stimulus] = cparCreateStimulus(channel, repeat, waveform) create
%    a stimulus [stimulus] for channel [channel] in the CPAR algometer, 
%    where channel can be 1 or 2. This stimulus is created from the 
%    waveform [waveform] and will be repeated [repeat] times.
%
%    See also, cparSetStimulus
stimulus.channel = channel;
stimulus.repeat = repeat;
stimulus.waveform = waveform;