# LabBench.CPAR

PLEASE NOTE, THIS LIBRARY IS CURRENTLY VERY MUCH IN DEVELOPMENT, AND IS NOT RELEASED FOR GENERAL USE.
USE AT YOUR OWN RISK.

LabBench Device driver for the Cuff Pressure Algometer Research (CPAR). This driver can be used
for using the CPAR device in .NET applications or with Matlab.

This library requires CPAR to run firmware version 7.0.0 or higher. If your CPAR device does not run
this version of the firmware, which will be the case for all CPAR devices currently in use as this library
and corresponding firmware is still in development. If you are interested in testing this library then
please contact the team behind the CPAR software on krhe@hst.aau.dk to obtain instructions on how to upgrade
the firmware of your CPAR device.

## .NET Applications

To Be Written

## Matlab

### Installation

For installation copy the Matlab/cpar directory in the current repository and add this directory
to the path of Matlab.

### Using the CPAR device from Matlab

The example Matlab code for creating a temporal summation:

```matlab
% Create a device and open communication with the device.
dev = cparCreate('COM18');
cparOpen(dev);

% Create a stimulus that can be used for temporal summation
pon = cparPulse(50, 2, 0);
poff = cparPulse(0, 4, 2);
combined = cparCombined();
cparCombinedAdd(combined, pon);
cparCombinedAdd(combined, poff);
stimulus = cparCreateStimulus(1, 5, combined);

% Update the device with the created stimulus
cparSetStimulus(dev, stimulus);

% Make sure the other channel is set to zero.
cparSetStimulus(dev, cparCreateStimulus(2, 1, cparPulse(0, 0.1, 0))); 

% Start the stimulation
cparStart(dev, 'b', true);

% Wait until stimulation has completed
pause(1);
while (dev.State == LabBench.Interface.AlgometerState.STATE_STIMULATING)
    fprintf('State: %s\n', dev.State.ToString()); 
    pause(1);
end
fprintf('State: %s\n', dev.State.ToString()); 

% Retrive data and plot it.
data = cparGetData(dev);
cparPlot(data);
cparClose(dev);
```
