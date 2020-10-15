function P = InstantiateParameters

P = struct;
P.protocol.sbId     = 01; % subject ID
P.protocol.session  = 1;
P.protocol.nRatings = 1;
P.log.ratings       = [];
P.language          = 'en'; % de or en
P.project.name      = 'EIH-Expectation-01';
P.project.part      = 'Pilot-01';
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
P.env.hostIPaddress             = char(P.env.hostaddress.getHostAddress);

if strcmp(P.env.hostname,'stimpc1')

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
        %             P.path.arduino = '';
        %             disp('stimpc1');
    else
        P.com.arduino = 'COM3'; % CPAR: depends on PC - experiment laptop COM3
        P.path.cpar = fullfile(cd,'..','CPAR');
        disp('worklaptop');
    end
end

% stimulus parameters
P.pain.preExposure          = [10 20 30 40 50]; % preexposure pressure intensities (kPa) to test the rough ballpark of pain threshold of the participant
P.test_range                = 10.0:1:90.0; % possible pressure range (kPa) for pressure pain test
P.test_start                = 30; % starting value (kPa); may be overridden after preexposure check
P.test_step                 = 3;  % +- pressure change (kPa) from starting value or pressure pain test
P.test_trials               = 7;  % number of trials for the pressure test
P.test_repeats              = 3;  % number of times the whole set of stimuli is repeated (with different randomized order)

P.pain.rS                            = 15; % rise speed

%P.presentation.cueing                = 1; % whether pain stimuli and others will be cued (typically by white/red cross)
P.presentation.initialTrials         = [1 1+P.test_trials 1+P.test_trials*2];
P.presentation.sStimPlateauPreexp    = 60; % duration of the constant pressure plateau after rise time for pre-exposure (part 1)
P.presentation.sPreexpITI            = 30; % pre-exposure ITI
P.presentation.sPreexpCue            = P.presentation.sStimPlateauPreexp/P.pain.rS+P.presentation.sStimPlateauPreexp; % pre-exposure cue duration (stimulus duration with rise time included)
P.presentation.sStimPlateau          = 60; % duration of the constant pressure plateau after rise time for pressure test (part 2)
P.presentation.pressureTestITI       = 20; % pressure test ITI
P.presentation.pressureTestReturnVAS = 10; % time to return VAS to zero
P.presentation.pressureTestTotalITI  = 30; % total ITI between trials
P.presentation.pressureTestBlockStop = 2;  % time to stop at the block display
%P.presentation.pressureTestCue       = P.presentation.sStimPlateau/P.pain.rS+P.presentation.sStimPlateau;

P.presentation.sMaxRating            = 8; % Presentation duration of rating scale

P.pain.cuff_on                       = 1; % which cuff is used for pain (1: left, 2: right - depends on how cuffs plugged into the CPAR unit and put on participant's arm/leg)
P.pain.cuff_off                      = 2; % the other cuff off (only use 1 cuff)
P.pain.repeat                        = 1; % number of repeats of each stimulus

P.cpar.forcedstart                   = true; % CPAR starts even with VAS not at 0 (otherwise false)
P.cpar.stoprule                      = 'b';  % CPAR stops only at button press (not when VAS reaches the maximum, 'v')

end

