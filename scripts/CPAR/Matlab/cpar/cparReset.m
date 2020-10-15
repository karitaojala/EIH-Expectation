function cparReset(dev)
% cparReset Reset collection of pressure and VAS from the CPAR device.
%   cparReset(dev) this resets/clear the data collected by the CPAR device.
%
%   See also, cparGetData, cparPlot
dev.Reset();