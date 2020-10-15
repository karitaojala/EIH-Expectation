function cparSetStimulus(dev, stimulus)
% cparSetStimulus Set the stimulus for a pressure channel
%   cparSetStimulus(dev, stimulus) update the CPAR device [dev]
%   with the stimulus [stimulus].
%
%   See also, cparCreateStimulus
channel = dev.Channels.Item(stimulus.channel - 1);
channel.SetStimulus(stimulus.repeat, stimulus.waveform);