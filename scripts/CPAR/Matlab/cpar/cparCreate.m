function [dev] = cparCreate(port)
% Create a CPAR driver
%    [dev] = cparCreate(port) this create a CPAR device [dev] on 
%    serial port [port].
%
%    This function must be the first one called before any other 
%    in the toolbox, as this will load the device driver, which
%    is required for all other functions in the toolbox.
%
% See also, cparOpen, cparClose.

DriverPath = fullfile(fileparts(mfilename('fullpath')),'libs', 'LabBench.CPAR.dll');   
NET.addAssembly(DriverPath);

dev = LabBench.CPAR.CPARDevice;
dev.Location = Inventors.ECP.Location.Parse(port);