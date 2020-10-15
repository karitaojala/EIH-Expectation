function cparClearChannel(dev, ch)
% cparClearChannel Clear a pressure channel
%   cparClearChannel(dev, ch)
cparSetStimulus(dev, cparCreateStimulus(ch, 1, cparPulse(0, 0.1, 0))); 

