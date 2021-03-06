%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pressure pain test with CPAR cuff algometer online VAS rating
% - Find rough ballpark of pain threshold
% - Test pressure intensities around the rough pain threshold
% - Online VAS rating of pain
% - Save pressure and rating data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Changelog
%
% Version: 1.0
% Author: Karita Ojala, k.ojala@uke.de, University Medical Center Hamburg-Eppendorf
%   Original script for calibrating thermal pain (some parts used here):
%   Bjoern Horing, University Medical Center Hamburg-Eppendorf
% Date: 2020-10-15
%
% Version notes
% 1.0

function [abort,varargout]=TestPressure(P,O)

    if ~nargin
        clear mex global functions;         %#ok<CLMEX,CLFUNC>
        P = InstantiateParameters; % load default parameters for comparable projects (should not ever be changed)
        O = InstantiateOverrides; % load overrides used for testing (e.g., deactivating PTB output or other troubleshooting)
        
        addpath(cd); 
        addpath(P.path.experiment)
        addpath(P.path.PTB)
        if ~O.debug.toggleVisual
            Screen('Preference', 'TextRenderer', 0);
            %Screen('Preference', 'SkipSyncTests', 1);
        end
    end 
   
    P.preExposure_intensities  = [10 20 30 40]; % pressure values (kPa) to test to determine rough ballpark of pain threshold for the participant
    P.test_stepsize = 5;  % +- change in pressure (kPa) from one trial to another
    P.test_range = 10.0:P.test_stepsize:90.0; % pressure range (kPa) for pressure testing procedure
    P.test_start = 30; % starting value (kPa); may be overridden after preexposure check
    P.test_start_increase = 10; % (kPa) if starting value not rated painful in preexposure check
    P.test_trialno = 7; % number of trials for pressure test - 7: starting point, 3 values above, 3 values below

    P.time.stamp = datestr(now,30);
    P.time.scriptStart=GetSecs;    

    if ~isempty(O.language)
        P.language = O.language;
    end
    
    if ~any(strcmp(P.language,{'de','en'}))
        fprintf('Instruction language "%s" not recognized. Aborting...',P.language);
        QuickCleanup(P);
        return;
    end
                    
    if ~P.protocol.sbId % this shouldn't ever be the case since InstantiateParameters provides an sbId (99)
        ListenChar(0); % activate keyboard input
        commandwindow;
        P.protocol.sbId=input('Please enter subject ID.\n');               
        ListenChar(2); % deactivate keyboard input
    else
        ListenChar(2); % deactivate keyboard input
    end
        
    if P.protocol.sbId==99
        O.debug.toggle = 1; % sbId 99 triggers debug mode to reduce number of trials and trial length for faster testing
    end
    
    if ~O.debug.toggle        
        clear functions; %#ok<CLFUNC>
    end    

    [P,O] = SetInput(P,O);    
    [P,O] = SetPTB(P,O); 
    [P,O] = SetParameters(P,O);
    [P,O] = SetPaths(P,O);
    
    %%%%%%%%%%%%%%%%%%%%%%%
    % Section selection (skip sections if desired)
    [abort,P]=StartExperimentAt(P,'Start experiment? ');    
    if abort;QuickCleanup(P);return;end    

    %%%%%%%%%%%%%%%%%%%%%%%
    % EXPERIMENT START
    %%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%
    % PREEXPOSURE
    if P.startSection<2
        [abort]=ShowInstruction(P,O,1,1);    
        if abort;QuickCleanup(P);return;end
        [abort,testStartValue]=Preexposure(P,O); % sends four triggers, waits ITI seconds after each
        if abort;QuickCleanup(P);return;end        
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%
    % PRESSURE TEST
    if P.startSection<3        
        if ~exist('testStartValue','var')
            testStartValue = P.test_start; % take a predefined starting value if no start value from pre-exposure
        end            
        fprintf('\nReady PRESSURE TEST: First stimulus at %1.1f kPa.\n',testStartValue); 
        [abort]=ShowInstruction(P,O,2,1);            
        if abort;QuickCleanup(P);return;end
        P = TestPressureRange(P,O,testStartValue);
        if abort;QuickCleanup(P);return;end 
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%
    % LEAD OUT
    if P.startSection<4
        [abort]=ShowInstruction(P,O,3);
        if abort;QuickCleanup(P);return;end
    end
    
    sca;
    ListenChar(0);
    
    %%%%%%%%%%%%%%%%%%%%%%%
    % END
    %%%%%%%%%%%%%%%%%%%%%%%
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                        FUNCTIONS COLLECTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        

%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALIZATION FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%

function [P,O] = SetInput(P,O)
    
    %===================================
    % input
    P.keys = [];
    P.keys.keyList                 = KbName('KeyNames');    

    if strcmp(P.env.hostname,'stimpc1') % curdes button box single diamond (HID NAR 12345)
        %KbName('UnifyKeyNames');
        P.keys.painful            = KbName('4$');
        P.keys.notPainful         = KbName('2@');                  
        P.keys.pause              = KbName('space');
        P.keys.resume             = KbName('return');
        P.keys.left               = KbName('2@'); % yellow button
        P.keys.right              = KbName('4$'); % red button        
        P.keys.confirm            = KbName('3#'); % green button
        try 
            P.keys.abort              = KbName('esc'); % alias of P.keys.esc
            P.keys.esc                = KbName('esc'); % alias of P.keys.abort
        catch
            P.keys.abort              = KbName('Escape'); 
            P.keys.esc                = KbName('Escape'); 
        end
    else        
        KbName('UnifyKeyNames');  
        P.keys.painful            = KbName('y');
        P.keys.notPainful         = KbName('n');
        P.keys.pause              = KbName('Space');
        P.keys.resume             = KbName('Return');    
        P.keys.confirm            = KbName('Return');
        P.keys.right              = KbName('RightArrow');
        P.keys.left               = KbName('LeftArrow');
        try 
            P.keys.abort              = KbName('Escape'); % alias of P.keys.esc
            P.keys.esc                = KbName('Escape'); % alias of P.keys.abort
        catch
            P.keys.abort              = KbName('esc'); 
            P.keys.esc                = KbName('esc'); 
        end
    end

end

function [P,O] = SetPaths(P,O)
    %===================================
    % output

    if ~isempty(O.path.experiment)
        P.path.experiment = O.path.experiment;
    end
    P.out.dir = [P.path.experiment '\' P.project.part '\logs\sub' sprintf('%03d',P.protocol.sbId) '\pain\'];
    if ~exist(P.out.dir,'dir')
        mkdir(P.out.dir);
    end
        
    P.out.file=['sub' sprintf('%03d',P.protocol.sbId) '_painRatingData.mat']; 
    fprintf('Saving data to %s%s.\n',P.out.dir,P.out.file);

end

%% Set Up the PTB with parameters and initialize drivers (based on function by Selim Onat/Alex Tinnermann)
function [P,O] = SetPTB(P,O)

% Graphical interface vars
screens                     =  Screen('Screens');                  % Find the number of the screen to be opened
if isempty(O.display.screen)
    P.display.screenNumber  =  max(screens);                       % The maximum is the second monitor
else
    P.display.screenNumber  =  O.display.screen;
end
P.display.screenRes = Screen('resolution',P.display.screenNumber);

P.style.fontname                = 'Arial';
P.style.fontsize                = 30;
P.style.linespace               = 10;
P.style.white                   = [255 255 255];
P.style.red                     = [255 0 0];
P.style.backgr                  = [70 70 70];
P.style.widthCross              = 3;
P.style.sizeCross               = 20;

%%%%%%%%%%%%%%%%%%%%%%%%%%% Default parameters
%         Screen('Preference', 'SkipSyncTests', O.debug.toggle);
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'DefaultFontSize', P.style.fontsize);
Screen('Preference', 'DefaultFontName', P.style.fontname);
%Screen('Preference', 'TextAntiAliasing',2);                       % Enable textantialiasing high quality
Screen('Preference', 'VisualDebuglevel', 0);                       % 0 disable all visual alerts
%Screen('Preference', 'SuppressAllWarnings', 0);
beep off;

%%%%%%%%%%%%%%%%%%%%%%%%%%% Open a graphics window using PTB
if ~O.debug.toggleVisual
    P.display.w                     = Screen('OpenWindow', P.display.screenNumber, P.style.backgr);
    Screen('Flip',P.display.w);                                            % Make the bg
end

P.display.rect                  = [0 0 P.display.screenRes.width P.display.screenRes.height];
P.display.midpoint              = [P.display.screenRes.width./2 P.display.screenRes.height./2];   % Find the mid position on the screen.

P.style.startY                = P.display.screenRes.height*P.display.startY;
P.style.lineheight = P.style.fontsize + P.style.linespace;

P.style.whiteFix1 = [P.display.midpoint(1)-P.style.sizeCross P.style.startY-P.style.widthCross P.display.midpoint(1)+P.style.sizeCross P.style.startY+P.style.widthCross];
P.style.whiteFix2 = [P.display.midpoint(1)-P.style.widthCross P.style.startY-P.style.sizeCross P.display.midpoint(1)+P.style.widthCross P.style.startY+P.style.sizeCross];

end

function [P,O] = SetParameters(P,O)

% Apply some overrides
if isfield(O.devices,'arduino') % then no arduino use is desired
    P.devices.arduino = 0;
end

% Define outgoing port address
if strcmp(P.env.hostname,'stimpc1')
    %P.com.lpt.CEDAddressThermode = 888; % CHECK IF STILL ACCURATE
    P.com.lpt.CEDAddressSCR     = 36912; % as per new stimPC; used to be =P.com.lpt.CEDAddressThermode;
else
    P.com.lpt.CEDAddressThermode = 0;
    P.com.lpt.CEDAddressSCR = 888;
end
P.com.lpt.CEDDuration           = 0.005; % wait time between triggers

if strcmp(P.env.hostname,'stimpc1')
    P.com.lpt.pressureOnsetTHE      = 36; % this covers both CHEPS trigger (4) and SCR/Spike (32)
    if P.devices.arduino
        P.com.lpt.pressureOnsetSCR      = 32;
    else % note: without arduino, this is NOT necessary on stimpc setup because there is no separate SCR recording device, just spike; therefore, do it with pressureOnsetTHE
        P.com.lpt.pressureOnsetSCR      = 0;
    end
    P.com.lpt.VASOnset          = 128; % we'll figure this out later
    P.com.lpt.ITIOnset          = 128; % we'll figure this out later
    P.com.lpt.cueOnset          = 128; % we'll figure this out later
else
    P.com.lpt.cueOnset      = 1; % bit 1; CS onset
    P.com.lpt.pressureOnsetTHE  = 255; % pressure trigger for thermode
    P.com.lpt.pressureOnsetSCR  = 2; %4; % bit 3; pressure trigger for SCR
    P.com.lpt.VASOnset      = 3; %8; % bit 5;
    P.com.lpt.ITIOnset      = 4; %16; % bit 6; white fixation cross
end

% Establish parallel port communication.
%         if ~isempty(regexp(computer('arch'),'64','ONCE'))
%             config_io;
%             outp(P.com.lpt.CEDAddressThermode,0);
%             WaitSecs(P.com.lpt.CEDDuration);
%             outp(P.com.lpt.CEDAddressSCR,0);
%             WaitSecs(P.com.lpt.CEDDuration);
%         elseif ~isempty(regexp(computer('arch'),'32','ONCE'))
%             config_io32;
%             outp32(P.com.lpt.CEDAddressThermode,0);
%             WaitSecs(P.com.lpt.CEDDuration);
%             outp32(P.com.lpt.CEDAddressSCR,0);
%             WaitSecs(P.com.lpt.CEDDuration);
%         end

if P.devices.arduino
    try
        P.presentation.thermoinoSafetyDelay = 0.1; % thermoino safety delay for short plateaus; 0.1 seems robust
        addpath(genpath(P.path.cpar))
    catch
        warning('CPAR scripts not found in %s. Aborting.',P.path.cpar);
    end
    
%     % instantiate serial object for CPAR control
%     UseCPAR('Init',P.com.arduino); % initialize arduino/CPAR
end

%% Debugging changes

if O.debug.toggle % if debugging, possibly reduce stimulus durations
    
    % for Preexposure (Section 1)
    P.presentation.sStimPlateauPreexp = 60; % 0 may lead to skipped triggers... but it's debug after all
    
    % for Sections >1
    P.presentation.sStimPlateau = 60;
    
end

end

function [abort,P]=StartExperimentAt(P,query)

abort=0;

P.keys.n1                 = KbName('1!'); % | Preexposure | Testing | Finish
P.keys.n2                 = KbName('2@'); % | Testing
P.keys.n3                 = KbName('3#'); % | Finish
keyN1Str = upper(char(P.keys.keyList(P.keys.n1)));
keyN2Str = upper(char(P.keys.keyList(P.keys.n2)));
keyN3Str = upper(char(P.keys.keyList(P.keys.n3)));
keyEscStr = upper(char(P.keys.keyList(P.keys.esc)));

fprintf('%sIndicate which step you want to start at for\n(%s Preexp => %s Pressure test => %s Finish. [%s] to abort.\n',query,keyN1Str(1),keyN2Str(1),keyN3Str(1),keyEscStr);

P.startSection = 0;
while 1
    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if find(keyCode) == P.keys.n1
            P.startSection=1;
            break;
        elseif find(keyCode) == P.keys.n2
            P.startSection=2;
            break;
        elseif find(keyCode) == P.keys.n3
            P.startSection=3;
            break;
        elseif find(keyCode) == P.keys.esc
            P.startSection=0;
            abort=1;
            break;
        end
    end
end

WaitSecs(0.2); % wait in case of a second query immediately after this

end

%%%%%%%%%%%%%%%%%%%%%%%%%%
% CORE FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%

function [abort]=ShowInstruction(P,O,section,displayDuration)

if ~O.debug.toggleVisual
    Screen('Preference', 'TextRenderer', 0);
end

if nargin<4
    displayDuration = 0; % toggle to display seconds that instructions are displayed in command line
end

abort=0;
upperEight = P.display.screenRes.height*P.display.Ytext;

if ~O.debug.toggleVisual
    
    if section == 1
        
        fprintf('Ready PREEXPOSURE protocol.\n');
        if strcmp(P.language,'de')
            if ~P.presentation.sStimPlateauPreexp; dstr = 'sehr kurzen '; else; dstr = ''; end
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich erhalten Sie über die Manschette eine Reihe an', 'center', upperEight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, [dstr 'Druckereizen, die leicht schmerzhaft sein können.'], 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Wir melden uns gleich, falls Sie noch Fragen haben,', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, 'danach geht es los!', 'center', upperEight+P.style.lineheight, P.style.white);
        elseif strcmp(P.language,'en')
            if ~P.presentation.sStimPlateauPreexp; dstr = 'very brief '; else; dstr = ''; end
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['You will now receive a number of ' dstr 'pressure stimuli,'], 'center', upperEight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'which may or may not be painful for you.', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'We will ask you in a few moments about any remaining questions,', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, 'then the measurement will start!', 'center', upperEight+P.style.lineheight, P.style.white);
        end
        
    elseif section == 2
        
        if strcmp(P.language,'de')
%             if ~P.toggles.doScaleTransl
%                 [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich beginnt Teil 2 der Schmerzschwellenmessung.', 'center', upperEight, P.style.white);
%                 [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
%                 [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Sie werden konstante Druckereize erhalten.', 'center', upperEight+P.style.lineheight, P.style.white);
%             else
%                 [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Sie werden nun weitere konstante Druckereize erhalten.', 'center', upperEight, P.style.white);
%             end
%             [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Bitte bewerten Sie jeden Reiz mithilfe ' keyMoreLessPainful], 'center', upperEight+P.style.lineheight, P.style.white);
%             [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['und bestätigen mit ' keyConfirm '.'], 'center', upperEight+P.style.lineheight, P.style.white);
%             [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
%             [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Es ist SEHR WICHTIG, dass Sie JEDEN der Reize bewerten!', 'center', upperEight+P.style.lineheight, P.style.white);
%             [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
%             [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, 'Gleich geht es los!', 'center', upperEight+P.style.lineheight, P.style.white);
        elseif strcmp(P.language,'en')
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'In a moment, the pressure pain test will start.', 'center', upperEight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'You will receive constant pressure stimuli for 60 seconds, with some time in between.', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Please rate each stimulus continuously using the controller.', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, '"Min" on the left is no pain, "Max" on the right is unbearable pain.', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'It is VERY IMPORTANT that you rate EACH AND EVERY stimulus CONTINUOUSLY!', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.style.lineheight, P.style.white);
            [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, 'Commencing shortly!', 'center', upperEight+P.style.lineheight, P.style.white);
        end
        
    elseif section == 3 % end of the test
        
        if strcmp(P.language,'de')
            [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, 'END', 'center', upperEight, P.style.white);
        elseif strcmp(P.language,'en')
            [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, 'The test has ended. Thank you for your time!', 'center', upperEight, P.style.white);
        end
        
    end
    
    introTextTime = Screen('Flip',P.display.w);
    
else
    
    introTextTime = GetSecs;
    
end

if displayDuration==1 % then hold it!
    fprintf('Displaying instructions... ');
    countedDown=1;
end

fprintf('\nInput [%s] required to continue, [%s] to abort...\n',upper(char(P.keys.keyList(P.keys.resume))),upper(char(P.keys.keyList(P.keys.esc))));

while 1
    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if find(keyCode) == P.keys.resume
            break;
        elseif find(keyCode) == P.keys.esc
            abort=1;
            break;
        end
    end
    
    if displayDuration==1
        tmp=num2str(SecureRound(GetSecs-introTextTime,0));
        [countedDown]=CountDown(GetSecs-introTextTime,countedDown,[tmp ' ']);
    end
end

if displayDuration==1; fprintf('\nInstructions were displayed for %d seconds.\n',SecureRound(GetSecs-introTextTime,0)); end

if ~O.debug.toggleVisual
    Screen('Flip',P.display.w);
end

end

%% Sends three triggers to CED, waits approximate stimulus duration plus ITI after each
function [abort,testStartValue]=Preexposure(P,O,varargin)

if nargin<3
    preExpInts = P.pain.preExposure;
else % override (e.g. for validation sessions)
    preExpInts = varargin{1};
end

abort=0;
preexPainful = NaN;

fprintf('\n==========================\nRunning preexposure sequence.\n');

for i = 1:length(preExpInts)
    
    if ~O.debug.toggleVisual
        Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1);
        Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2);
        tCrossOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog
    else
        tCrossOn = GetSecs;
    end
        
    if i == 1
        fprintf('[Initial trial, showing P.style.white cross for %1.1f seconds, red cross for %1.1f seconds]\n',P.presentation.sPreexpITI,P.presentation.sPreexpCue);
    end

    fprintf('Displaying fixation cross... ');
    SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.ITIOnset);
    
    while GetSecs < tCrossOn + P.presentation.sPreexpITI
        [abort]=LoopBreaker(P);
        if abort; break; end
    end
    
    if ~O.debug.toggleVisual
        Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1);
        Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2);
        Screen('Flip',P.display.w);                      % gets timing of event for PutLog
    else
        GetSecs;
    end
    
    SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.cueOnset);
    fprintf('%1.1f kPa stimulus initiated.',preExpInts(i));
    
    stimDuration=CalcStimDuration(P,preExpInts(i),P.presentation.sStimPlateauPreexp);
    
    countedDown=1;
    tStimStart=GetSecs;
    SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.pressureOnsetSCR);
    
    if P.devices.arduino
        UseCPAR('Init',P.com.arduino); % initialize arduino/CPAR
        UseCPAR('Set',preExpInts(i),stimDuration,P); % set stimulus
        UseCPAR('Trigger',P.cpar.stoprule,P.cpar.forcedstart); % start stimulus
        
        while GetSecs < tStimStart+sum(stimDuration)
            [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
            [abort]=LoopBreaker(P);
            if abort; break; end
        end
        
        UseCPAR('Kill');
        
        fprintf('\n');  
        
    else
        SendTrigger(P,P.com.lpt.CEDAddressThermode,P.com.lpt.pressureOnsetTHE);
        
        while GetSecs < tStimStart+sum(stimDuration)
            [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
            [abort]=LoopBreaker(P);
            if abort; return; end
        end
    end
    
    if ~abort
        fprintf(' concluded.\n');
    else
        break;
    end

    
    if ~O.debug.toggleVisual
        Screen('Flip',P.display.w);
    end
    SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.VASOnset);
    
    if nargin < 3
        preexPainful = QueryPreexPain(P,O);
    end
    
    if preexPainful
        fprintf('Stimulus painful. Stopping procedure... \n');
        testStartValue = preExpInts(i);
        return;
    else
        fprintf('Stimulus not painful. Continuing procedure... \n');
    end
    
end

end

function preexPainful = QueryPreexPain(P,O)

if strcmp(P.env.hostname,'stimpc1')
    if strcmp(P.language,'de')
        keyNotPainful = 'den [linken Knopf]';
        keyPainful = 'den [rechten Knopf]';
    elseif strcmp(P.language,'en')
        keyNotPainful = 'the [left button]';
        keyPainful = 'the [right button]';
    end
else
    if strcmp(P.language,'de')
        keyNotPainful = ['die Taste [' upper(char(P.keys.keyList(P.keys.notPainful))) ']'];
        keyPainful =  ['die Taste [' upper(char(P.keys.keyList(P.keys.painful))) ']'];
    elseif strcmp(P.language,'en')
        keyNotPainful = ['the key [' upper(char(P.keys.keyList(P.keys.notPainful))) ']'];
        keyPainful =  ['the key [' upper(char(P.keys.keyList(P.keys.painful))) ']'];
    end
end

upperEight = P.display.screenRes.height/8;

fprintf('Was this stimulus painful [%s], or not painful [%s]?\n',upper(char(P.keys.keyList(P.keys.painful))),upper(char(P.keys.keyList(P.keys.notPainful))));
if ~O.debug.toggleVisual
    if strcmp(P.language,'de')
        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'War dieser Reiz SCHMERZHAFT für Sie?', 'center', upperEight, P.style.white);
        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Falls ja, drücken Sie bitte ' keyPainful '.'], 'center', upperEight+P.style.lineheight, P.style.white);
        [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, ['Falls nein, drücken Sie bitte ' keyNotPainful '.'], 'center', upperEight+P.style.lineheight, P.style.white);
    elseif strcmp(P.language,'en')
        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Was this stimulus PAINFUL for you?', 'center', upperEight, P.style.white);
        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['If yes, please press ' keyPainful '.'], 'center', upperEight+P.style.lineheight, P.style.white);
        [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, ['If no, please press ' keyNotPainful '.'], 'center', upperEight+P.style.lineheight, P.style.white);
    end
    Screen('Flip',P.display.w);
end

while 1
    [keyIsDown, ~, keyCode] = KbCheck();
    if keyIsDown
        if find(keyCode) == P.keys.painful
            preexPainful=1;
            break;
        elseif find(keyCode) == P.keys.notPainful
            preexPainful=0;
            break;
        end
    end
end

WaitSecs(0.2);

if ~O.debug.toggleVisual
    Screen('Flip',P.display.w);
end

end

function [abort] = TestPressureRange(P,O,varargin)

if P.startSection<3
    
    if nargin<1
        startValue = P.test_start;
    else
        startValue = varargin{1};
    end
    
    abort=0;
    
    fprintf('\n==========================\nRunning pressure test.\n');
    
    stepsEachDirection = (P.test_trials-1)/2; % pressure values to test above and below the starting value
    
    countTrial = 1;
    
    for block = 1:P.test_repeats
        
        % create a vector of test values going up and down from the starting
        % value with a specified step size
        stepOrder = nan(1,P.test_trials-1);
        stepCount = 1;
        for steps = 1:stepsEachDirection
            stepOrder(stepCount) = startValue+steps*P.test_step;
            stepCount = stepCount + 1;
            stepOrder(stepCount) = startValue-steps*P.test_step;
            stepCount = stepCount + 1;
        end
        % randomize the order
        stepOrder = stepOrder(randperm(length(stepOrder)));
        % add starting value to the first place
        stepOrder = [startValue stepOrder]; %#ok<AGROW>
        
        fprintf('\n=======BLOCK %d of %d=======\n',block,P.test_repeats);
        
        fprintf('Displaying instructions... ');
        
        if ~O.debug.toggleVisual
            upperHalf = P.display.screenRes.height/2;
            Screen('TextSize', P.display.w, 50);
            [P.display.screenRes.width, upperHalf]=DrawFormattedText(P.display.w, ['Block ' num2str(block)], 'center', upperHalf, P.style.white);
            [P.display.screenRes.width, upperHalf]=DrawFormattedText(P.display.w, ' ', 'center', upperHalf+P.style.lineheight, P.style.white);
            Screen('TextSize', P.display.w, 30);
            [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, [num2str(P.test_trials) ' stimuli of 60 seconds with breaks in between'], 'center', upperHalf+P.style.lineheight, P.style.white);
            introTextOn = Screen('Flip',P.display.w);
        else
            introTextOn = GetSecs;
        end

        while GetSecs < introTextOn + P.presentation.pressureTestBlockStop
            [abort]=LoopBreaker(P);
            if abort; break; end
        end
    
        fprintf('\nContinue [%s], or abort [%s].\n',upper(char(P.keys.keyList(P.keys.resume))),upper(char(P.keys.keyList(P.keys.esc))));
        
        while 1
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown
                if find(keyCode) == P.keys.resume
                    break;
                elseif find(keyCode) == P.keys.esc
                    abort = 1;
                    break;
                end
            end
        end
        
        WaitSecs(0.2);
        
        if abort; break; end
        
        if ~O.debug.toggleVisual
            Screen('Flip',P.display.w);
        end
    
        for nStepTrial = 1:numel(stepOrder)
            
            fprintf('\n=======TRIAL %d of %d=======\n',nStepTrial,numel(stepOrder));
            
            [abort]=ApplyStimulus(P,O,stepOrder(nStepTrial),countTrial); % VAS rating during the stimulus
            countTrial = countTrial+1;
            if abort; return; end
            
        end
    
        if ~O.debug.toggleVisual
            upperHalf = P.display.screenRes.height/2;
            [P.display.screenRes.width, ~]=DrawFormattedText(P.display.w, 'Please return the slider to zero now.', 'center', upperHalf, P.style.white);
            outroTextOn = Screen('Flip',P.display.w);
        else
            outroTextOn = GetSecs;
        end
        
        while GetSecs < outroTextOn + P.presentation.pressureTestReturnVAS
            [abort]=LoopBreaker(P);
            if abort; break; end
        end
            
    end
        
end
    
end

function [abort]=ApplyStimulus(P,O,trialTemp,countTrial)

abort=0;

if ~O.debug.toggleVisual
    Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1);
    Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2);
    tCrossOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog
else
    tCrossOn = GetSecs;
end

SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.ITIOnset);
fprintf('Displaying fixation cross... ');

while GetSecs < tCrossOn + P.presentation.pressureTestITI
    [abort]=LoopBreaker(P);
    if abort; break; end
end

if ~O.debug.toggleVisual
    Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1);
    Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2);
    %tCueOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog
    Screen('Flip',P.display.w);   
else
    %tCueOn = GetSecs;
    GetSecs;
end

SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.cueOnset);
fprintf('%1.1f kPa stimulus initiated.',trialTemp);

stimDuration=CalcStimDuration(P,trialTemp,P.presentation.sStimPlateau);
    
countedDown=1;
tStimStart=GetSecs;
SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.pressureOnsetSCR);

if P.devices.arduino
    UseCPAR('Init',P.com.arduino); % initialize arduino/CPAR
    UseCPAR('Set',trialTemp,stimDuration,P); % set stimulus
    UseCPAR('Trigger',P.cpar.stoprule,P.cpar.forcedstart); % start stimulus
    
    while GetSecs < tStimStart+sum(stimDuration)
        [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
        [abort]=LoopBreaker(P);
        if abort; break; end
    end
    
    fprintf('\n');
    
    trialData = UseCPAR('Data'); % retrieve data
    SaveData(P,trialData,countTrial); % save data for this trial

    UseCPAR('Kill');
    
else
    SendTrigger(P,P.com.lpt.CEDAddressThermode,P.com.lpt.pressureOnsetTHE);
    
    while GetSecs < tStimStart+sum(stimDuration)
        [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
        [abort]=LoopBreaker(P);
        if abort; return; end
    end
end
if ~abort
    fprintf(' concluded.\n');
else
    return;
end

end

function SaveData(P,trialData,countTrial)

    try
        dataFile = fullfile(P.out.dir,P.out.file);
        if exist(dataFile,'file')
            loadedData = load(dataFile);
            cparData = loadedData.cparData;
        end
        
        cparData(countTrial).data = trialData;
        
        if ~isempty(cparData) && ~isempty(trialData)
            save(dataFile,'cparData');
        end
    catch
        fprintf(['Saving trial ' num2str(countTrial) 'data failed.\n']);
    end
    
end
    
%%%%%%%%%%%%%%%%%%%%%%%%%
% AUXILIARY FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%

%% Returns a vector with riseTime, P.presentation.sStimPlateau and fallTime for the target stimulus
function [stimDuration] = CalcStimDuration(P,temp,sStimPlateau)
%diff=abs(temp-P.pain.bT);
%riseTime=diff/P.pain.rS;
riseTime = temp/P.pain.rS;
%fallTime=diff/P.pain.fS;
%stimDuration=[riseTime sStimPlateau fallTime];
stimDuration = [riseTime sStimPlateau];% only rise time 
end

%% Set Marker for CED and BrainVision Recorder
function SendTrigger(P,address,port) %#ok<INUSD>
% Send pulse to CED for SCR, thermode, digitimer
%       [handle, errmsg] = IOPort('OpenSerialport',num2str(port));
%         if ~isempty(regexp(computer('arch'),'64','ONCE'))
%             outp(address,port);
%             WaitSecs(P.com.lpt.CEDDuration);
%             outp(address,0);
%             WaitSecs(P.com.lpt.CEDDuration);
%         elseif ~isempty(regexp(computer('arch'),'32','ONCE'))
%             outp32(address,port);
%             WaitSecs(P.com.lpt.CEDDuration);
%             outp32(address,0);
%             WaitSecs(P.com.lpt.CEDDuration);
%         end

end

%% display string during countdown
function [countedDown]=CountDown(secs, countedDown, countString)
if secs>countedDown
    fprintf('%s', countString);
    countedDown=ceil(secs);
end
end

%% Use so the experiment can be aborted with proper key presses
function [abort]=LoopBreaker(P)
abort=0;
[keyIsDown, ~, keyCode] = KbCheck();
if keyIsDown
    if find(keyCode) == P.keys.esc
        abort=1;
        return;
    elseif find(keyCode) == P.keys.pause
        fprintf('\nPaused, press [%s] to resume.\n',upper(char(P.keys.keyList(P.keys.resume))));
        while 1
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown
                if find(keyCode) == P.keys.resume
                    break;
                end
            end
        end
    end
end
end
    
%% Make sure round works across MATLAB versions
function [y]=SecureRound(X, N)
try
    y=round(X,N);
catch EXC %#ok<NASGU>
    %disp('Round function  pre 2014 !');
    y=round(X*10^N)/10^N;
end
end

%% Cleanup when aborting script
function QuickCleanup(P)

fprintf('\nAborting...');
if P.devices.arduino
    UseCPAR('Kill');
end
sca; % close window; also closes io64
ListenChar(0); % use keys again
commandwindow;
end
