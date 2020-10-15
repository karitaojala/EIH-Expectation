function P = InstantiateParameters

P = struct;
P.protocol.sbId     = 03; % de or en
P.protocol.session  = 1;
P.protocol.nRatings = 1;
P.log.ratings       = [];
P.language          = 'en'; % de or en
P.project.name      = 'EIH-Expectation-01';
P.devices.arduino     = 1; % if '' or [], will not try to use Arduino
P.devices.eyetracker    = 0;
P.devices.triggerSetup  = 1; % 1 single parallel port, arduino; rest undefined

P.display.white = [1 1 1];
P.lineheight = 40;
P.display.startY = 0.4;
P.display.Ytext = 0.25;

[~, tmp]                        = system('hostname');
P.env.hostname                  = deblank(tmp);
P.env.hostaddress               = java.net.InetAddress.getLocalHost;
P.env.hostIPaddress             = char( P.env.hostaddress.getHostAddress);

if strcmp(P.env.hostname,'stimpc1')
    %         P.path.scriptBase           = [ 'D:\horing\MATLAB\' ];
    %         P.path.experiment           = [ 'D:\horing\projects\' P.project.name filesep ];
else
    P.path.scriptBase           = cd;
    P.path.experiment           = fullfile(cd,'..','..','calibration',P.project.name);
    P.path.PTB                  = 'C:\Data\Toolboxes\Psychtoolbox';
end
if ~exist(P.path.experiment,'dir')
    mkdir(P.path.experiment);
end

if P.devices.arduino
    if strcmp(P.env.hostname,'stimpc1')
        %             P.com.arduino = 'COM12'; % Mario COM11, Luigi COM12
        %             P.com.thermoinoBaud = 115200;
        %             P.path.arduino = '';
        %             disp('stimpc1');
    else
        P.com.arduino = 'COM3'; % Mario COM3, Luigi COM4 / CPAR: depends on PC - experiment laptop COM3
        P.path.cpar = fullfile(cd,'..','CPAR');
        disp('worklaptop');
    end
end

% stimulus parameters
P.presentation.cueing               = 1; % whether pain stimuli and others will be cued (typically by white/red cross)
P.presentation.sStimPlateauPreexp   = 60;
P.presentation.sStimPlateau         = 60;
P.presentation.sCalibITI            = [10.5 12.5]; % sum of all segments contributing to the ITI (in EquiNox case, that's CS display, choice display, rating

P.presentation.sMaxRating = 8; % Presentation duration of rating scale

P.pain.bT                           = 0; % baseline pressure %baseline temp 32
P.pain.rS                           = 15; % rise speed, temp 15
P.pain.fS                           = 30; % fall speed, temp 15
P.pain.duration                     = 60; % stimulus duration
P.pain.threshold                    = 30; % for sound duration estimation, temp 43
P.pain.cuff_on                      = 1; % which cuff is used for pain (1: left, 2: right - depends on how cuffs plugged into the CPAR unit and put on participant's arm/leg)
P.pain.cuff_off                     = 2; % the other cuff off (only use 1 cuff)
P.pain.repeat                       = 1; % number of repeats of each stimulus

P.cpar.forcedstart                  = true; % CPAR starts even with VAS not at 0 (otherwise false)
P.cpar.stoprule                     = 'b';  % CPAR stops only at button press (not when VAS reaches the maximum, 'v')
