cparpath = cd;
addpath(genpath(cparpath))

% Create a device and open communication with the device.
dev = cparCreate('COM3');
cparOpen(dev);

try
    % Create a stimulus that can be used for temporal summation
    pon = cparRamp(20, 1, 0);
    pon2 = cparPulse(20, 1, 1);
    poff = cparPulse(20, 2, 1.5);
    combined = cparCombined();
    cparCombinedAdd(combined, pon);
    cparCombinedAdd(combined, pon2);
    cparCombinedAdd(combined, poff);

    % Update the device with the created stimulus
    cparSetStimulus(dev, cparCreateStimulus(1, 1, combined));

    % Make sure the other channel is set to zero.
    cparSetStimulus(dev, cparCreateStimulus(2, 1, cparPulse(0, 0.1, 0))); 

    % Start the stimulation
    cparStart(dev, 'b', true);

    % Wait until stimulation has completed
    pause(1);
    while (dev.State == LabBench.Interface.AlgometerState.STATE_STIMULATING)
        fprintf('State: %s\n', dev.State.ToString()); 
        dev.Ping();
        pause(0.2);
    end
    fprintf('State: %s\n', dev.State.ToString()); 

    % Retrive data and plot it.
    data = cparGetData(dev);
    cparPlot(data);
    cparClose(dev);
catch me
    fprintf('Exception %s',me.identifier); 
    cparClose(dev); 
end
