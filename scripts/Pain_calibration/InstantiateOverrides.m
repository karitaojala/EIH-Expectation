% these settings are supposed to override those from InstantiateParameters; use is mainly for troubleshooting

function O = InstantiateOverrides

O = struct;
O.startingSession       = 1; % 1 is default; using 2 skips first session
O.startingTrial         = 1; % use for interrupted protocols
O.preserveETCalib       = 0; % 1 to preserve existing eyetracker calibration
O.debug.toggle          = 0; % 0 is default (full protocol)
O.debug.toggleVisual    = 0; % 0 is default (full protocol)
O.language              = 'en';
O.path.experiment       = [];
O.display.screen        = 2; % 2 is default; use [] for one screen setup...
O.sound.deviceId        = [];
O.sound.step2Range      = [];
O.pain.step2Range       = [];
%O.devices.arduino       = 1; % if no override is desired, comment out or rmfield in project-specific scripts (isfield query); ANY entry in this variable will suppress arduino initialization
O.devices.eyetracker    = 0; % if no override is desired, comment out or rmfield in project-specific scripts (isfield query); ANY entry in this variable will suppress eyetracker initialization
