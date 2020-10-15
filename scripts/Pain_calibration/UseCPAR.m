% Interface script for CPAR pressure cuff algometer, for use with Arduino software xx.
% 
% dev = UseCPAR(action,varargin)
%
% Available actions: 
%
%       UseCPAR('Init',comport); initialize CPAR, where comport is the COM
%       port (e.g., 'COM3')
%
%       UseCPAR('Set',dev,createdstim); set stimulus for CPAR, where dev is
%       a structure created by cparCreate when initializing CPAR and
%       createdstim is the created stimulus from cparCreateStimulus
%
%       UseCPAR('Trigger',dev,stopmode,forcedstart); start CPAR stimulus,
%       where dev is a structure created by cparCreate when initializing
%       CPAR, stopmode is the mode of stopping CPAR ('b' button press only,
%       'v' also at maximum VAS rating), and forcedstart defines whether
%       CPAR is also started when VAS is not at 0 or not (true/false)
%
%       UseCPAR('Kill',dev); stop CPAR and close COM ports, where dev is a 
%       structure created by cparCreate when initializing CPAR
%
% Version: 1.0
% Author: Karita Ojala, University Medical Center Hamburg-Eppendorf
% Modified from UseThermoino script by Björn Horing
% Date: 2020-09-15

function UseCPAR(action,varargin)

if ~nargin
    help UseCPAR;
    return;
end    

global dev

if strcmpi(action,'init')
    % varargin{1} = COM port
    if isempty(varargin{1})
        error('Need COM port as input in the form: "COMx" where x is COM port number.');
    else
        try
            dev = cparCreate(varargin{1}); % COM port
        catch
            error('Creating Dev structure failed - check that COM port is correct.');
        end
    end
    
    if exist('dev','var') && strcmpi(class(dev),'LabBench.CPAR.CPARDevice')
        try
            cparOpen(dev);
        catch
            error('Opening CPAR failed. Check dev structure from cparCreate and the COM port. Probably COM port in use, reset (restart Matlab).');
        end
    else
        error('Opening CPAR failed: empty or invalid Dev structure. ');
    end
   
elseif strcmpi(action,'kill')

    if ~exist('dev','var') || ~strcmpi(class(dev),'LabBench.CPAR.CPARDevice') % or not correct type
        error('Dev structure containing COM port information required to close COM port.');
    else
        try
            cparClose(dev);
        catch
            error('Closing CPAR and COM port failed. Restart Matlab to close COM port.');
        end
    end
    
elseif strcmpi(action,'set')
    % varargin{1} = pressure in kPa
    % varargin{2} = P, set parameters
    
    if ~exist('dev','var') || ~strcmpi(class(dev),'LabBench.CPAR.CPARDevice') % add: or not correct type
        error('Dev structure containing COM port information from cparCreate required to start CPAR.');
    elseif isempty(varargin{1})
        cparClose(dev);
        error('Input pressure required.');
    elseif ~isnumeric(varargin{1})
        warning('Input pressure needs to be in numeric format. Attempting conversion.');
        try
            pressure_num = str2double(varargin{1});
            varargin{1} = pressure_num;
        catch
            cparClose(dev);
            error('Could not convert input pressure into numeric, try again.');
        end
    elseif isempty(varargin{2})
        cparClose(dev);
        error('Parameter settings structure (P) required.');
    end
    
    try
        pressure = varargin{1}; % target pressure (kPa)
        settings = varargin{2};
        ramp_up_duration = pressure/settings.pain.rS; % duration of ramp-up (target pressure/ramping up speed)
        full_onset = ramp_up_duration; % onset of constant pressure
        %ramp_down_duration = settings.pain.fS*pressure; % duration of ramp-down (ramping down speed * target pressure)
        %offset = full_onset+settings.pain.duration; % offset of constant pressure
        ramp_up = cparRamp(pressure,ramp_up_duration,0); % create ramping up part
        constant_pressure = cparPulse(pressure,settings.pain.duration,full_onset); % create constant pressure part
        %ramp_down = cparPulse(pressure,ramp_down_duration,offset); % create ramping down part
        stimulus = cparCombined();
        cparCombinedAdd(stimulus,ramp_up); % add ramping up to stimulus
        cparCombinedAdd(stimulus,constant_pressure); % add constant pressure
        %cparCombinedAdd(stimulus,ramp_down); % add ramping down
        created_stim_cuff_on = cparCreateStimulus(settings.pain.cuff_on,settings.pain.repeat,stimulus); % combined stimulus
        created_stim_cuff_off = cparCreateStimulus(settings.pain.cuff_off,1,cparPulse(0, 0.1, 0)); % off cuff set to zero
    catch
        cparClose(dev);
        error('Creating stimulus for CPAR failed - check stimulus parameters.');
    end
    
    try
        cparSetStimulus(dev,created_stim_cuff_on); % set pressure stimulus for on cuff
    catch
        cparClose(dev);
        error(['Setting stimulus for Cuff ' num2str(settings.pain.cuff_on) ' for CPAR failed - check created stimulus.']);
    end
    
    try
        cparSetStimulus(dev,created_stim_cuff_off); % set zero stimulus for off cuff
    catch
        cparClose(dev);
        error(['Setting stimulus for Cuff ' num2str(settings.pain.cuff_off) ' for CPAR failed - check created stimulus.']);
    end
    
elseif strcmpi(action,'trigger')
    % varargin{1} = stop mode; 'v' stops when certain VAS rating reached,
    % 'b' only stops when a button pressed
    % varargin{2} = forced start; 'true' start even when VAS is not at 0,
    % 'false' VAS always has to be at 0 for CPAR to start
    if ~exist('dev','var') || ~strcmpi(class(dev),'LabBench.CPAR.CPARDevice') % or not correct type
        error('Dev structure containing COM port information from cparCreate required to start CPAR.');
    elseif ~strcmpi(varargin{1},'b') && ~strcmpi(varargin{1},'v')
        cparClose(dev);
        error('Invalid stopping option for CPAR: has to be either "b" for stopping at button press only, or "v" for stopping also at maximum VAS (10 cm).');
    elseif ~islogical(varargin{2})
        cparClose(dev);
        error('Forced start option for CPAR missing: has to be either TRUE or FALSE.');
    else
        try
            cparStart(dev,varargin{1},varargin{2});
        catch
            cparClose(dev);
            error('Starting CPAR failed.');
        end
    end
end
