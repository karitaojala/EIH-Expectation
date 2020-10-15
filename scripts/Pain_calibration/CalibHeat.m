%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Probabilistic pain threshold detection
% Perithreshold calibration
% - Scale translation
% - Psychometric perceptual scaling
% - Fixed intensity target regression
% - Fixed VAS target regression
% - Adaptive VAS target regression
% Perithreshold validation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Probandenvergütung: https://www.nin.uke.uni-hamburg.de:8009/ninpa.php
%
% 1.1.1 changelog
% *added several variables to InstantiateParameters
% *line 45: added Screen('Preference', 'SkipSyncTests', 1);
% *replaced all lineheight with P.lineheight
% *line 1149: replaced targetVAS with P.currentTrial.targetVAS
%
% Version: 1.1
% Author: Bjoern Horing, University Medical Center Hamburg-Eppendorf
%   Expanded, modified and annotated code 
%   including code developed by Christian Sprenger, and conceptual work by Friedemann Awiszus,
%   TMS and threshold hunting, Awiszus et al.(2003), Suppl Clin Neurophysiol. 2003;56:13-23.
% Date: 2020-07-16
%
% Version notes
% 1.0 & prior
% - [pre version tracking]
% 1.1 2020-07-16
% - complete overhaul
% - restructured to utilize P struct, removed global variable architecture
% - TODO: validation
% - TODO: add function to catch O.debug.toggleVisual (avoid if loops)

function [abort,varargout]=CalibHeat(P,O)

    if ~nargin
        clear mex global functions;        
        P = InstantiateParameters; % load default parameters for comparable projects (should not ever be changed)
        O = InstantiateOverrides; % load overrides used for testing (e.g., deactivating PTB output or other troubleshooting)
        
        addpath(cd); % for VASScale_v6, CalibValidation, FitData
        addpath( [P.path.scriptBase 'calibration\_cogent etc for triggering'] )
        Screen('Preference', 'SkipSyncTests', 1);
    end 

    %%%%%%%%%%%%%%%%%%%%%%%
    % Manual variable definition (hardcoded toggles)
    P.toggles.doPainOnly       = 1;
    P.toggles.doScaleTransl    = 1; % scale translation from binary via two-dimensional to uni-dimensional (only needed for P.toggles.doPainOnly==1)
    P.toggles.doPsyPrcScale    = 1; % psychometric-perceptual scaling; either this is REQUIRED, or numel(step2Range)>2
    P.toggles.doFixedInts      = 0;
    P.toggles.doPredetInts     = 1;
    P.toggles.doAdaptive       = 1; % adaptive procedure to fill up bins
    P.toggles.doConfirmAdaptive = 1;

    %%%%%%%%%%%%%%%%%%%%%%%
    % Automated variable instantiation
    P.painCalibData = []; % output struct; instantiate so it's returned empty if abort
    P.painCalibData.notes{1} = 'Instantiated';
    P.painCalibData.PeriThrN = 0;
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
        clear functions;
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
        [abort,preexPainful]=Preexposure(P,O); % sends four triggers, waits ITI seconds after each
        if abort;QuickCleanup(P);return;end        
    else
        preexPainful = 1; % then we start with the conservative assumption that the top preexposure temp was experienced as painful
    end

    %%%%%%%%%%%%%%%%%%%%%%%
    % THRESHOLDING
    if P.startSection<3        
        if preexPainful==0
            P.awiszus.mu = 44.0;
        else
            P.awiszus.mu = 43.0;
        end            
        fprintf('\nReady FIRST THRESHOLD at %1.1f°C.\n',P.awiszus.mu); 

        [abort]=ShowInstruction(P,O,2,1);            
        if abort;QuickCleanup(P);return;end
        P = DoAwiszus(P,O);
    else
        P = GetAwiszus(P);
    end

    %%%%%%%%%%%%%%%%%%%%%%%
    % PERITHRESHOLDING
    P=DetermineSteps(P);
    %[P.presentation.plateauITIs,P.presentation.plateauCues]=DetermineITIsAndCues(numel(P.plateaus.step2Order),P.presentation.sMinMaxPlateauITIs,P.presentation.sMinMaxPlateauCues); % DEPRECATED, use if balanced ITIs/Cues are desired; currently, everything is random within the range defined by P.presentation.sMinMaxPlateau*
    P.presentation.firstPlateauITI = 5; % override, no reason for this to be so long
    P.presentation.firstPlateauCue = max(P.presentation.sMinMaxPlateauCues);
    
    WaitSecs(0.2);
    if ~O.debug.toggleVisual
        Screen('Flip',P.display.w);   
    end
    
    P.time.plateauStart=GetSecs;        
    
    [abort,P]=TrialControl(P,O);     
    if abort;QuickCleanup(P);return;end  

    %%%%%%%%%%%%%%%%%%%%%%%
    % REPORTING
    P.time.scriptEnd=GetSecs;    
    PrintDurations(P); % simple output function to see how long the calibration took

    %%%%%%%%%%%%%%%%%%%%%%%
    % LEAD OUT
    ShowInstruction(P,O,4);
    
    sca;
    ListenChar(0);

    if nargout>1
        varargout{1} = P.painCalibData;
    end

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
    P.out.dir = [P.path.experiment 'logs\sub' sprintf('%03d',P.protocol.sbId) '\pain\'];
    if ~exist(P.out.dir,'dir')
        mkdir(P.out.dir);
    end
        
    P.out.file=['sub' sprintf('%03d',P.protocol.sbId) '_painCalibData_' P.time.stamp]; 
    fprintf('Saving calibration data to %s%s.\n',P.out.dir,P.out.file);

end

%% Set Up the PTB with parameters and initialize drivers (based on function by Selim Onat/Alex Tinnermann)
    function [P,O] = SetPTB(P,O)

        % Graphical interface vars
        screens                     =  Screen('Screens');                  % Find the number of the screen to be opened
        if isempty(O.display.screen)
            P.display.screenNumber          =  max(screens);                       % The maximum is the second monitor
        else
            P.display.screenNumber          =  O.display.screen;   
        end
        P.display.screenRes = Screen('resolution',P.display.screenNumber);
        
        P.style.fontname                = 'Arial';
        P.style.fontsize                = 30; %30; %18;
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
        P.style.P.lineheight = P.style.fontsize + P.style.linespace;
        
        P.style.whiteFix1 = [P.display.midpoint(1)-P.style.sizeCross P.style.startY-P.style.widthCross P.display.midpoint(1)+P.style.sizeCross P.style.startY+P.style.widthCross];
        P.style.whiteFix2 = [P.display.midpoint(1)-P.style.widthCross P.style.startY-P.style.sizeCross P.display.midpoint(1)+P.style.widthCross P.style.startY+P.style.sizeCross];

    end        


% Here it's just the trigger definitions, but will include more eventually
    function [P,O] = SetParameters(P,O)
       
        % Apply some overrides
        if isfield(O.devices,'thermoino') % then no thermoino use is desired
            P.devices.thermoino = 0;
        end

        % Define outgoing port address
        if strcmp(P.env.hostname,'stimpc1')
            P.com.lpt.CEDAddressThermode = 888; % CHECK IF STILL ACCURATE
            P.com.lpt.CEDAddressSCR     = 36912; % as per new stimPC; used to be =P.com.lpt.CEDAddressThermode;     
        else            
            P.com.lpt.CEDAddressThermode = 0;
            P.com.lpt.CEDAddressSCR = 888;
        end
        P.com.lpt.CEDDuration           = 0.005; % wait time between triggers    

        if strcmp(P.env.hostname,'stimpc1')
            P.com.lpt.heatOnsetTHE      = 36; % this covers both CHEPS trigger (4) and SCR/Spike (32)
            if P.devices.thermoino
                P.com.lpt.heatOnsetSCR      = 32; 
            else % note: without thermoino, this is NOT necessary on stimpc setup because there is no separate SCR recording device, just spike; therefore, do it with heatOnsetTHE
                P.com.lpt.heatOnsetSCR      = 0; 
            end
            P.com.lpt.VASOnset          = 128; % we'll figure this out later
            P.com.lpt.ITIOnset          = 128; % we'll figure this out later
            P.com.lpt.cueOnset          = 128; % we'll figure this out later
        else            
            P.com.lpt.cueOnset      = 1; % bit 1; CS onset
            P.com.lpt.heatOnsetTHE  = 255; % heat trigger for thermode
            P.com.lpt.heatOnsetSCR  = 2; %4; % bit 3; heat trigger for SCR                
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

        if P.devices.thermoino        
            try
                P.presentation.thermoinoSafetyDelay = 0.1; % thermoino safety delay for short plateaus; 0.1 seems robust
                addpath(P.path.thermoino)
            catch
                warning('Thermoino scripts not found in %s. Aborting.',P.path.thermoino);
                return;        
            end                

            % instantiate serial object for thermoino control
            UseThermoino('Kill');
            UseThermoino('Init',P.com.thermoino,P.com.thermoinoBaud,P.pain.bT,P.pain.rS); % returns handle of serial object
        end

        %% CORE VARIABLES: Heat pain threshold determination parameters
        if ~O.debug.toggle
            P.awiszus.N=8;           % number of trials for threshold estimation
        else
            P.awiszus.N=2;
        end
        P.awiszus.X   = 41.0:0.01:47.0;  % temperature range (°C) 
        P.awiszus.mu  = 43.0;     % starting value, based on assumed population mu forearm; may be overridden after preexposure check
        P.awiszus.sd  = 1.2;  % assumed sd of threshold (population level) 
        P.awiszus.sp  = 0.4;  % assumed spread of threshold (individual level); we started at 0.8

        if ~O.debug.toggle
            % for Preexposure (Section 1)
            P.pain.preExposure=[42 42.5 43 43.5]; % vector of intensities used for preexposure, intended to lead to binary decision "were any of these painful y/n"
            P.presentation.sStimPlateauPreexp; % as per InstantiateParameters; modify if desired        

            % for Sections >1
            P.presentation.sStimPlateau; % as per InstantiateParameters; modify if desired

            % for Thresholding (Section 2)
            P.presentation.sMinMaxThreshITIs = [12 16]; % seconds between stimuli; will be randomized between two values - to use constant ITI, use two identical values
            P.presentation.sMinMaxThreshCues = [0.5 2]; % jittered time prior to the stimulus that the white cross turns red; can be [0 0] (to turn off red cross altogether), but else MUST NOT BE LOWER THAN 0.5

            % for Sections >2
            P.presentation.sMinMaxPlateauITIs = P.presentation.sCalibITI; % overrides the old values from thresholding [9 11]
            P.presentation.sMinMaxPlateauCues = [0.5 2]; % should correspond to overrides the old values from thresholding   

            % for Validation (Section 6)
            P.presentation.NValidationSessions = 0;
        else
            % for Preexposure (Section 1)
            P.pain.preExposure = 42;
            P.presentation.sStimPlateauPreexp = 0; % 0 may lead to skipped triggers... but it's debug after all        

            % for Sections >1
            P.presentation.sStimPlateau = 3; 

            % for Thresholding (Section 2)
            P.presentation.sMinMaxThreshITIs = [6 6];
            P.presentation.sMinMaxThreshCues = [1 3]; 

            % for Sections >2
            P.presentation.sMinMaxPlateauITIs = [6 6];
            P.presentation.sMinMaxPlateauCues = [1 3];               

            % for Validation (Section 6)
            P.presentation.NValidationSessions = 0;
        end
        [P.presentation.thresholdITIs,P.presentation.thresholdCues]=DetermineITIsAndCues(P.awiszus.N,P.presentation.sMinMaxThreshITIs,P.presentation.sMinMaxThreshCues);    
        P.presentation.firstThresholdITI = 5; 
        P.presentation.firstThresholdCue = max(P.presentation.sMinMaxThreshCues);

        P.presentation.sPreexpITI = 5; 
        P.presentation.sPreexpCue = 2;        

        % Plateau vars      

        P.presentation.scaleInitVASRange = [20 81];     

        % HARDCODED STUFF THAT SHOULD NOT BE HARDCODED
        P.plateaus.step1Seq = [0.5 1.0 2.0 1.0]; % FOR USE WITH VARIABLE PROCEDURE
    %     if ~isempty(O.pain.step1Seq)
    %         step1Seq = O.pain.step1Seq;
    %     end 

        if P.toggles.doFixedInts
    %         P.plateaus.step2Seq = [0.1 0.9 -2.0 0.4 -0.6 -0.2 1.6 -1.2]; % Example sequence for fixed intensities; legacy: PMParam
    %         P.plateaus.step2Seq = [0.1 1.6 -1.2 0.9]; % Example sequence for fixed intensities
            if ~isempty(O.pain.step2Range)
                P.plateaus.step2Seq = O.pain.step2Range;
            end
        else
            P.plateaus.step2Seq = []; % in this case, the entire section will be skipped
        end

        P.plateaus.step3TarVAS = [10 30 90]; % FOR USE WITH FIXED RATING TARGET PROCEDURE
    %     if ~isempty(O.pain.step3TarVAS)
    %         step3TarVAS = O.pain.step3TarVAS;
    %     end   

        % OPTION TO VALIDATE CALIBRATION RESULTS
        % if P.presentation.NValidationSessions>0, n sessions will be performed using step5 info; THESE DATA WILL BE SAVED TO PLATEAULOG, AS WELL!
        % (not to plateauResultsLog, however). This is for your convenience, until the time where it shall not be convenient any longer.
        % This will include preexposure, because it only makes    
        P.plateaus.step5SeqF = [20 80]; % these will not be shuffled (F=fixed), intended to be applied after preexposure
        P.plateaus.step5SeqR = [10 30:10:70 90]; % these will be shuffled (R=random), and concatenated to step5SeqF
        P.plateaus.step5Preexp = [-20 -10 0 0]; % note: negative values can lead to weird stimulus intensities using sigmoid fit

        P.plateaus.VASTargets = [25,35,45,55,65,75]; % this is mostly for export/display purposes

        P.presentation.sBlank = 0.5; 

    end



    function [abort,P]=StartExperimentAt(P,query)  

        abort=0;

        P.keys.n1                 = KbName('1!'); % | Preexposure | Thresholding | ScaleTrans | RegTraining | Regression | Validation
        P.keys.n2                 = KbName('2@'); % | Thresholding | ScaleTrans | RegTraining | Regression | Validation
        P.keys.n3                 = KbName('3#'); % | ScaleTrans | RegTraining | Regression | Validation
        P.keys.n4                 = KbName('4$'); % | RegTraining | Regression | Validation
        P.keys.n5                 = KbName('5%'); % | Regression | Validation
        P.keys.n6                 = KbName('6^'); % | Validation
        keyN1Str = upper(char(P.keys.keyList(P.keys.n1)));
        keyN2Str = upper(char(P.keys.keyList(P.keys.n2)));
        keyN3Str = upper(char(P.keys.keyList(P.keys.n3)));
        keyN4Str = upper(char(P.keys.keyList(P.keys.n4)));
        keyN5Str = upper(char(P.keys.keyList(P.keys.n5)));
        keyN6Str = upper(char(P.keys.keyList(P.keys.n6)));
        keyEscStr = upper(char(P.keys.keyList(P.keys.esc)));

        fprintf('%sIndicate which step you want to start at for\n(%s Preexp => %s Thresh => %s ScaleTrans => %s RegressTraing => %s Regress => %s Valid). [%s] to abort.\n',query,keyN1Str(1),keyN2Str(1),keyN3Str(1),keyN4Str(1),keyN5Str(1),keyN6Str(1),keyEscStr);
        
        %ListenChar(2);
        
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
                elseif find(keyCode) == P.keys.n4
                    P.startSection=4;
                    break;                        
                elseif find(keyCode) == P.keys.n5
                    P.startSection=5;
                    break;    
                elseif find(keyCode) == P.keys.n6
                    P.startSection=6;
                    break;                        
                elseif find(keyCode) == P.keys.esc
                    P.startSection=0;
                    abort=1;
                    break;                
                end
            end        
        end        
        
        %ListenChar(0);
        
        WaitSecs(0.2); % wait in case of a second query immediately after this
        
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%
% CORE FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%

    function [abort]=ShowInstruction(P,O,section,displayDuration)
        
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
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich erhalten Sie über die Thermode eine Reihe an', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, [dstr 'Hitzereizen, die leicht schmerzhaft sein können.'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Wir melden uns gleich, falls Sie noch Fragen haben,', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'danach geht es los!', 'center', upperEight+P.lineheight, P.style.white);
                elseif strcmp(P.language,'en')
                    if ~P.presentation.sStimPlateauPreexp; dstr = 'very brief '; else; dstr = ''; end
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['You will now receive a number of ' dstr 'heat stimuli,'], 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'which may or may not be painful for you.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'We will ask you in a few moments about any remaining questions,', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'then the measurement will start!', 'center', upperEight+P.lineheight, P.style.white);            
                end

            elseif section == 2

                if strcmp(P.env.hostname,'stimpc1') 
                    if strcmp(P.language,'de')
                        keyNotPainful = '[linker Knopf]';
                        keyPainful = '[rechter Knopf]';
                    elseif strcmp(P.language,'en')
                        keyNotPainful = '[left button]';
                        keyPainful = '[right button]';                
                    end
                else 
                    keyNotPainful = [ '[' upper(char(P.keys.keyList(P.keys.notPainful))) ']' ];
                    keyPainful = [ '[' upper(char(P.keys.keyList(P.keys.painful)))  ']' ];
                end
                if strcmp(P.language,'de')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich beginnt Teil 1 der Schmerzschwellenmessung.', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Sie werden konstante Hitzereize erhalten.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Bitte geben Sie nach jedem Reiz an, ob dieser', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['NICHT SCHMERZHAFT ' keyNotPainful ' oder'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['(mindestens) LEICHT SCHMERZHAFT ' keyPainful ' war.'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    %[P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Wir melden uns gleich, falls Sie noch Fragen haben,', 'center', upperEight+P.lineheight, P.style.white);
                    %[P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'danach geht es los!', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich geht es los!', 'center', upperEight+P.lineheight, P.style.white);
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'In a moment, part 1 of the pain threshold calibration will start.', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'You will receive constant heat stimuli.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Please indicate after each stimulus whether it was', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['NOT PAINFUL ' keyNotPainful ' or'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['(at least) SLIGHTLY PAINFUL ' keyPainful ], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    %[P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Wir melden uns gleich, falls Sie noch Fragen haben,', 'center', upperEight+P.lineheight, P.style.white);
                    %[P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'danach geht es los!', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Commencing shortly!', 'center', upperEight+P.lineheight, P.style.white);            
                end

            elseif section == 3

                if strcmp(P.env.hostname,'stimpc1') 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'des [linken/rechten Knopfes]';
                        keyConfirm = 'dem [mittleren oberen Knopf]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right button]';
                        keyConfirm = 'the [middle upper button]';                
                    end
                else 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'der [linken/rechten Cursortaste]';
                        keyConfirm = 'der [Eingabetaste]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right cursor key]';
                        keyConfirm = '[Enter]';     
                    end
                end                        
                if strcmp(P.language,'de')
                    if ~P.toggles.doScaleTransl 
                        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich beginnt Teil 2 der Schmerzschwellenmessung.', 'center', upperEight, P.style.white);
                        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Sie werden konstante Hitzereize erhalten.', 'center', upperEight+P.lineheight, P.style.white);                    
                    else
                        [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Sie werden nun weitere konstante Hitzereize erhalten.', 'center', upperEight, P.style.white);
                    end
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Bitte bewerten Sie jeden Reiz mithilfe ' keyMoreLessPainful], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['und bestätigen mit ' keyConfirm '.'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Es ist SEHR WICHTIG, dass Sie JEDEN der Reize bewerten!', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich geht es los!', 'center', upperEight+P.lineheight, P.style.white);
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'In a moment, part 2 of pain threshold calibration will start.', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'You will receive constant heat stimuli.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Please rate each stimulus using ' keyMoreLessPainful], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['and confirm with ' keyConfirm '.'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'It is VERY IMPORTANT that you rate EACH AND EVERY stimulus!', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Commencing shortly!', 'center', upperEight+P.lineheight, P.style.white);            
                end

            elseif section == 4 % final section, to initiate wait after calibration

                if strcmp(P.language,'de')            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich geht es weiter...', 'center', upperEight, P.style.white);
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Continuing shortly...', 'center', upperEight, P.style.white);
                end

            elseif section == 5 % added to cover the validation part ("step 5")

                if strcmp(P.env.hostname,'stimpc1') 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'des [linken/rechten Knopfes]';
                        keyConfirm = 'dem [mittleren oberen Knopf]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right button]';
                        keyConfirm = 'the [middle upper button]';                
                    end
                else 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'der [linken/rechten Cursortaste]';
                        keyConfirm = 'der [Eingabetaste]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right cursor key]';
                        keyConfirm = '[Enter]';     
                    end
                end                        
                if strcmp(P.language,'de')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich geht es weiter...', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Sie werden konstante Hitzereize erhalten.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Bitte bewerten Sie jeden Reiz mithilfe ' keyMoreLessPainful], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['und bestätigen mit ' keyConfirm '.'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich geht es los!', 'center', upperEight+P.lineheight, P.style.white);
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Continuing shortly...', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'You will receive constant heat stimuli via the thermode.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Please rate each stimulus using ' keyMoreLessPainful], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['and confirm with ' keyConfirm '.'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Commencing shortly!', 'center', upperEight+P.lineheight, P.style.white);            
                end 

            elseif section == 6 % added to announce thermode (re)placement

                if strcmp(P.language,'de')            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Die Versuchsleitung wird nun die Thermode umsetzen,', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'dann geht es weiter.', 'center', upperEight+P.lineheight, P.style.white);                
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'The experimenter will now move the thermode,', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'then the session will continue.', 'center', upperEight+P.lineheight, P.style.white); 
                end

            elseif section == 7

                img = imread(sprintf('%s%s_%s.png',P.path.experiment,'img\scaleTranslation1_rgb',lower(P.language))); % 'C:\Users\horing\Documents\MATLAB\projects\P7_EquiNox\
                tex = Screen('MakeTexture', P.display.w, img);            
                padPx = 15;

                if strcmp(P.env.hostname,'stimpc1') 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'des [linken/rechten Knopfes]';
                        keyConfirm = 'dem [mittleren oberen Knopf]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right button]';
                        keyConfirm = 'the [middle upper button]';                
                    end
                else 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'der [linken/rechten Cursortaste]';
                        keyConfirm = 'der [Eingabetaste]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right cursor key]';
                        keyConfirm = '[Enter]';     
                    end
                end                        
                if strcmp(P.language,'de')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich beginnt Teil 2 der Schmerzschwellenmessung.', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);                
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Sie erhalten nun konstante Hitzereize um Ihre eben ermittelt Schmerzschwelle herum.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Bitte bewerten Sie jeden Reiz mithilfe ' keyMoreLessPainful], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['und bestätigen mit ' keyConfirm ' auf dieser Skala:'], 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    Screen('DrawTexture', P.display.w, tex, [], [P.display.midpoint(1)-475 upperEight+padPx P.display.midpoint(1)+475 upperEight+150+padPx]);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight+150, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Die Schmerzschwelle ist als "minimaler Schmerz" in der Mitte der Skala gekennzeichnet.', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Gleich geht es los!', 'center', upperEight+P.lineheight, P.style.white);
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, '[Placeholder section 7]', 'center', upperEight, P.style.white);
                end

            elseif section == 8

                img = imread(sprintf('%s%s_%s.png',P.path.experiment,'img\scaleTranslation2_rgb',lower(P.language)));
                tex = Screen('MakeTexture', P.display.w, img);            
                padPx = 15;

                if strcmp(P.env.hostname,'stimpc1') 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'des [linken/rechten Knopfes]';
                        keyConfirm = 'dem [mittleren oberen Knopf]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right button]';
                        keyConfirm = 'the [middle upper button]';                
                    end
                else 
                    if strcmp(P.language,'de')
                        keyMoreLessPainful = 'der [linken/rechten Cursortaste]';
                        keyConfirm = 'der [Eingabetaste]';
                    elseif strcmp(P.language,'en')
                        keyMoreLessPainful = 'the [left/right cursor key]';
                        keyConfirm = '[Enter]';     
                    end
                end                        
                if strcmp(P.language,'de')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Die Skala, nach der Sie die Reize bewerten,', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'ändert sich im folgenden Abschnitt so:', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight, P.style.white);
                    Screen('DrawTexture', P.display.w, tex, [], [P.display.midpoint(1)-475 upperEight+padPx P.display.midpoint(1)+475 upperEight+343+padPx]);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ' ', 'center', upperEight+P.lineheight+343, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Ist ein Reiz unterhalb der Schmerzschwelle, würden Sie ihn also', 'center', upperEight+P.lineheight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'ganz am linken Ende der Skala bewerten und nicht mehr in der Mitte.', 'center', upperEight+P.lineheight, P.style.white);
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, '[Placeholder section 8]', 'center', upperEight, P.style.white);
                end

            end

            introTextTime = Screen('Flip',P.display.w);

        else

            introTextTime = GetSecs;

        end

        fprintf('\nInput [%s] required to continue, [%s] to abort...\n',upper(char(P.keys.keyList(P.keys.resume))),upper(char(P.keys.keyList(P.keys.esc))));
        
        if displayDuration==1 % then hold it!
            fprintf('Displaying instructions... ');
            countedDown=1;
        end
        
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

    %% sends three triggers to CED, waits approximate stimulus duration plus ITI after each
    function [abort,preexPainful]=Preexposure(P,O,varargin)
        
        if nargin<3
            preExpInts = P.pain.preExposure;
        else % override (e.g. for validation sessions)
            preExpInts = varargin{1};
        end
        
        abort=0;
        preexPainful = NaN;
        
        fprintf('\n==========================\nRunning preexposure sequence.\n');
        fprintf('[Initial trial, showing P.style.white cross for %1.1f seconds, red cross for %1.1f seconds]\n',P.presentation.sPreexpITI,P.presentation.sPreexpCue);

        if ~O.debug.toggleVisual
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1); 
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2); 
            tCrossOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog                        
        else
            tCrossOn = GetSecs;
        end
        while GetSecs < tCrossOn + P.presentation.sPreexpITI-P.presentation.sPreexpCue 
            [abort]=LoopBreaker(P);
            if abort; break; end
        end

        if ~O.debug.toggleVisual
            Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1); 
            Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2); 
            tCueOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog
        else
            tCueOn = GetSecs;
        end
        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.cueOnset);
        
        while GetSecs < tCueOn + P.presentation.sPreexpCue 
            [abort]=LoopBreaker(P);
            if abort; break; end
        end
        
        for i = 1:length(preExpInts)
            if i>1 % preexposure ITIs
                if ~O.debug.toggleVisual
                    Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1); 
                    Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2); 
                    tCrossOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog
                else
                    tCrossOn = GetSecs;
                end
                SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.ITIOnset);
                
                while GetSecs < tCrossOn + P.presentation.sPreexpITI 
                    [abort]=LoopBreaker(P);
                    if abort; break; end
                end            

                if ~O.debug.toggleVisual
                    Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1); 
                    Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2); 
                    tCueOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog
                else
                    tCueOn = GetSecs;
                end
                SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.cueOnset);
                
                while GetSecs < tCueOn + P.presentation.sPreexpCue
                    [abort]=LoopBreaker(P);
                    if abort; break; end
                end            
            end
            
            fprintf('%1.1f°C stimulus initiated.',preExpInts(i));
            stimDuration=CalcStimDuration(P,preExpInts(i),P.presentation.sStimPlateauPreexp);  
                        
            countedDown=1;
            SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.heatOnsetSCR);
            
            if P.devices.thermoino                
                UseThermoino('Trigger'); % start next stimulus
                UseThermoino('Set',preExpInts(i)); % open channel for arduino to ramp up  
                tStimStart=GetSecs; % this makes the Thermoino plateau issue handled more conservatively

                while GetSecs < tStimStart+sum(stimDuration(1:2))+P.presentation.thermoinoSafetyDelay
                    [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
                    [abort]=LoopBreaker(P);
                    if abort; break; end % only break because we want the temperature to return to BL before we quit
                end
                
                UseThermoino('Set',P.pain.bT); % open channel for arduino to ramp down        
                
                if ~abort
                    while GetSecs < tStimStart+sum(stimDuration)
                        [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
                        [abort]=LoopBreaker(P);
                        if abort; return; end
                    end 
                else
                    return;
                end             
            else                
                SendTrigger(P,P.com.lpt.CEDAddressThermode,P.com.lpt.heatOnsetTHE);                
                tStimStart=GetSecs;
                
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
        end
        
        if ~O.debug.toggleVisual
            Screen('Flip',P.display.w);                  
        end
        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.VASOnset);
        
        if ~nargin % only then do we have the conventional preexposure, else we come from validation (step5), for example
            preexPainful = QueryPreexPain(P,O);
        end
        
    end


    function preexPainful = QueryPreexPain(P)

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

        if length(preExpInts)>1
            fprintf('Were any of these %d stimuli painful [%s], or none [%s]?\n',length(preExpInts),upper(char(P.keys.keyList(P.keys.painful))),upper(char(P.keys.keyList(P.keys.notPainful))));
            if ~O.debug.toggleVisual
                if strcmp(P.language,'de')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'War einer dieser Reize (mindestens) LEICHT SCHMERZHAFT für Sie?', 'center', upperEight, P.style.white);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Falls ja, drücken Sie bitte ' keyPainful '.'], 'center', upperEight+P.lineheight, P.style.white);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Falls nein, drücken Sie bitte ' keyNotPainful '.'], 'center', upperEight+P.lineheight, P.style.white);            
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Was one of these stimuli (at least) SLIGHTLY PAINFUL for you?', 'center', upperEight, P.style.white);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['If yes, please press ' keyPainful '.'], 'center', upperEight+P.lineheight, P.style.white);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['If no, please press ' keyNotPainful '.'], 'center', upperEight+P.lineheight, P.style.white);                        
                end
            end
        else
            fprintf('Was this stimulus painful [%s], or not painful [%s]?\n',upper(char(P.keys.keyList(P.keys.painful))),upper(char(P.keys.keyList(P.keys.notPainful))));
            if ~O.debug.toggleVisual
                if strcmp(P.language,'de')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'War dieser Reiz (mindestens) LEICHT SCHMERZHAFT für Sie?', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Falls ja, drücken Sie bitte ' keyPainful '.'], 'center', upperEight+P.lineheight, P.style.white);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['Falls nein, drücken Sie bitte ' keyNotPainful '.'], 'center', upperEight+P.lineheight, P.style.white);            
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, 'Was this stimulus (at least) SLIGHTLY PAINFUL for you?', 'center', upperEight, P.style.white);
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['If yes, please press ' keyPainful '.'], 'center', upperEight+P.lineheight, P.style.white);            
                    [P.display.screenRes.width, upperEight]=DrawFormattedText(P.display.w, ['If no, please press ' keyNotPainful '.'], 'center', upperEight+P.lineheight, P.style.white); 
                end
            end
        end

        if ~O.debug.toggleVisual
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

    function [P] = DoAwiszus(P,O)

        painful=[];

        P.time.threshStart=GetSecs;

        P = Awiszus('init',P); 

        % iteratively increase or decrease the target temperature to approximate pain threshold    
        P.awiszus.nextX = P.awiszus.mu; % start with assumed population mean
        for awn = 1:P.awiszus.N
            P.awiszus.nextX = round(P.awiszus.nextX,1); % al gusto

            [abort]=DisplayStimulus(P,O,awn,P.awiszus.nextX);            
            if abort; break; end
            [painful,tThresholdRating]=BinaryRating(P,O,awn);
            P.awiszus.threshRatings(awn,1) = P.awiszus.nextX;
            P.awiszus.threshRatings(awn,2) = painful;

            if ~O.debug.toggle
                if painful==0
                    awstr = 'not painful';
                elseif painful==1
                    awstr = 'painful';
                elseif painful==-1 
                    break; % yeah let's not do that anymore...
                end
            else 
                awstr = 'painful';
                painful=1;
            end
            fprintf('Stimulus rated %s.\n',awstr);

            P = Awiszus('update',P,painful); % awP,awPost,awNextX,painful      
            [abort]=WaitRemainingITI(P,O,awn,tThresholdRating);
            if abort; break; end
        end

        if abort;QuickCleanup(P);return;end        
        
        P.painCalibData.AwThrTemps = P.awiszus.threshRatings(:,1);
        P.painCalibData.AwThrResponses = P.awiszus.threshRatings(:,2);        
        P.painCalibData.AwThr = P.awiszus.nextX; 

        if painful==-1
            fprintf('No rating provided for temperature %1.1f. Please restart program. Resuming at the current break point not yet implemented.\n',P.painCalibData.AwThr);
            return;
        else
            save([P.out.dir P.out.file], 'P');
            fprintf('\n\nThreshold determined around %1.1f°C, after %d trials.\nThreshold data and results saved under %s%s.mat.\n',P.painCalibData.AwThr,P.awiszus.N,P.out.dir,P.out.file);        
        end

        P.time.threshEnd=GetSecs;

    end

    % when skipping parts of the calibration in StartExperimentAt, try to obtain existing calib data
    function [P] = GetAwiszus(P)

        P.time.threshStart=GetSecs;                

        painCFiles = cellstr(ls(P.out.dir));   
        painCFiles = painCFiles(contains(painCFiles,'painCalibData'));
        
        if isempty(painCFiles)
            warning('Previous calibration data file not found. Crash out (Ctrl+C) or indicate custom threshold.');
            P.painCalibData.AwThr = input('Thresholding data not found. Please enter pain threshold (awTT).');
            P.painCalibData.notes{end+1} = 'Custom threshold (awTT)';
        else
            if numel(painCFiles)>1
                warning('Multiple calibration data files found. Proceeding with most recent one (%s).',cell2mat(painCFiles))
            end
            painCFiles = painCFiles(end);
            existP = load([P.out.dir cell2mat(painCFiles)]); % load existing parameters
            existP = existP.P;
            P.painCalibData.AwThrTemps = existP.painCalibData.AwThrTemps;
            P.painCalibData.AwThrResponses = existP.painCalibData.AwThrResponses;
            try
                P.painCalibData.AwThr = existP.painCalibData.AwThr;
            catch % for opening old log files
                P.painCalibData.AwThr = existP.painCalibData.ResThrAw;
            end
            P.painCalibData.notes{end+1} = sprintf('Thresholding data imported from %s',[P.out.dir cell2mat(painCFiles)]);
        end

        P.time.threshEnd=GetSecs; 
 
    end

    %% sends trigger to CED and waits approximate stimulus duration
    function [abort]=DisplayStimulus(P,O,nTrial,temp)

        abort=0;
        
        [stimDuration]=CalcStimDuration(P,temp,P.presentation.sStimPlateau);
        fprintf('\n=======TRIAL %d of %d=======\n',nTrial,P.awiszus.N);
                   
        if nTrial == 1 % Turn on the fixation cross for the first trial (no ITI to cover this)
            fprintf('[Initial trial, showing white cross for %1.1f seconds, red cross for %1.1f seconds]\n',P.presentation.firstThresholdITI-P.presentation.firstThresholdCue,P.presentation.firstThresholdCue);
            
            if ~O.debug.toggleVisual
                Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1); 
                Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2); 
                tCrossOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog                        
            else
                tCrossOn = GetSecs;
            end
            SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.ITIOnset);
            
            while GetSecs < tCrossOn + P.presentation.firstThresholdITI-P.presentation.firstThresholdCue 
                [abort]=LoopBreaker(P);
                if abort; return; end
            end
            
            if P.presentation.cueing==1 && ~O.debug.toggleVisual
                Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1); 
                Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2); 
                tCueOn = Screen('Flip',P.display.w);                      % gets timing of event for PutLog
                while GetSecs < tCueOn + P.presentation.firstThresholdCue 
                    [abort]=LoopBreaker(P);
                    if abort; return; end
                end
            end
        end

        fprintf('%1.1f°C stimulus initiated',temp);
        
        tStimStart=GetSecs;
        countedDown=1;
        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.heatOnsetSCR);
        
        if P.devices.thermoino        
            UseThermoino('Trigger'); % start next stimulus
            UseThermoino('Set',temp); % open channel for arduino to ramp up      

            while GetSecs < tStimStart+sum(stimDuration(1:2)) % changed for thermoino, because we need to trigger the return, too
                [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
                [abort]=LoopBreaker(P);
                if abort; break; end % only break because we want the temp to be set to baseline before we crash out
            end
      
            fprintf('\n');
            UseThermoino('Set',P.pain.bT); % open channel for arduino to ramp down        

            if ~abort
                while GetSecs < tStimStart+sum(stimDuration) % consider only fall time for wait
                    [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
                    [abort]=LoopBreaker(P);
                    if abort; return; end
                end      
            else
                return;
            end
        else
            SendTrigger(P,P.com.lpt.CEDAddressThermode,P.com.lpt.heatOnsetTHE);
            
            while GetSecs < tStimStart+sum(stimDuration)
                [countedDown]=CountDown(GetSecs-tStimStart,countedDown,'.');
                [abort]=LoopBreaker(P);
                if abort; return; end
            end            
        end
        fprintf(' concluded.\n');

    end

    function [painful,tThresholdRating]=BinaryRating(P,O,nTrial)
        
        painful=-1;
        upperEight = P.display.screenRes.height*P.display.Ytext;
        
        % await rating within a time frame that leaves enough time to adjust the stimulus
        tRatingStart=GetSecs;
        fprintf('Not painful [%s] or painful [%s]?\n',P.keys.notPainful,P.keys.painful);

        nY = P.display.screenRes.height/8;
        if strcmp(P.env.hostname,'stimpc1') 
            if strcmp(P.language,'de')
                keyNotPainful = '[linker Knopf]';
                keyPainful = '[rechter Knopf]';
            elseif strcmp(P.language,'en')
                keyNotPainful = '[left button]';
                keyPainful = '[right button]';
            end
        else 
            keyNotPainful = [ '[' P.keys.notPainful ']' ];
            keyPainful = [ '[' P.keys.painful ']' ];
        end                
        if ~O.debug.toggleVisual
            if strcmp(P.language,'de')
                [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, ['Nicht schmerzhaft ' keyNotPainful ' oder (mindestens) leicht schmerzhaft ' keyPainful '?'], 'center', upperEight, P.style.white); 
            elseif strcmp(P.language,'en')
                [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, ['Not painful ' keyNotPainful ' oder (at least) slightly painful ' keyPainful '?'], 'center', upperEight, P.style.white); 
            end

            Screen('Flip',P.display.w);  
        end

        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.VASOnset);
        
        WaitSecs(P.presentation.sBlank);
        %KbQueueRelease;

        while 1 % there is no escape...
            [keyIsDown, ~, keyCode] = KbCheck();
            if keyIsDown
                if find(keyCode) == P.keys.painful
                    painful=1;
                    break;
                elseif find(keyCode) == P.keys.notPainful
                    painful=0;
                    break;                
                elseif find(keyCode) == P.keys.abort
                    painful=-1;
                    break;
                end
            end

            nY = P.display.screenRes.height/8;
            if ~O.debug.toggleVisual && GetSecs > tRatingStart+P.presentation.thresholdITIs(nTrial)
                if strcmp(P.language,'de')
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, ['Nicht schmerzhaft ' keyNotPainful ' oder (mindestens) leicht schmerzhaft ' keyPainful '?'], 'center', upperEight, P.style.white); 
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, ' ', 'center', nY+P.lineheight, P.style.white); 
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, ' ', 'center', nY+P.lineheight, P.style.white); 
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, 'Eingabe erforderlich', 'center', nY+P.lineheight, P.style.red); 
                elseif strcmp(P.language,'en')
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, ['Not painful ' keyNotPainful ' oder (at least) slightly painful ' keyPainful '?'], 'center', upperEight, P.style.white); 
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, '', 'center', nY+P.lineheight, P.style.white); 
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, '', 'center', nY+P.lineheight, P.style.white); 
                    [P.display.screenRes.width, nY]=DrawFormattedText(P.display.w, '^ ^ ^ Input required ^ ^ ^', 'center', nY+P.lineheight, P.style.red);                     
                end   
                
                Screen('Flip',P.display.w); 
            end
        end       
                
        tThresholdRating=GetSecs-tRatingStart;                      
       
    end
    
    function [abort]=WaitRemainingITI(P,O,nTrial,tThresholdRating)    
        WaitSecs(P.presentation.sBlank); 
        abort=0;
        
        % no need to have an ITI after the last stimulus
        if nTrial==P.awiszus.N
            return;
        end
        
        if ~O.debug.toggleVisual
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1); 
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2); 
            Screen('Flip',P.display.w);  % gets timing of event for PutLog                    
        end
        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.ITIOnset);
        
        sITIRemaining=P.presentation.thresholdITIs(nTrial)-tThresholdRating; 
          
        tITIStart=GetSecs;             
        fprintf('Remaining ITI %1.0f seconds (press [%s] to pause, [%s] to abort)...\n',sITIRemaining,upper(char(P.keys.keyList(P.keys.pause))),upper(char(P.keys.keyList(P.keys.esc))));
        countedDown=1;        
        while GetSecs < tITIStart+sITIRemaining
            [abort]=LoopBreaker(P);
            if abort; return; end
            [countedDown]=CountDown(GetSecs-tITIStart,countedDown,'.');
                            
            % switch on red cross and wait a bit so it won't get switched on a thousand times
            if P.presentation.cueing==1 && ~O.debug.toggleVisual % else we don't want the red cross
                if GetSecs>tITIStart+sITIRemaining-P.presentation.thresholdCues(nTrial) && GetSecs<tITIStart+sITIRemaining-P.presentation.thresholdCues(nTrial)+P.presentation.sBlank
                    fprintf('[Cue at %1.1fs]... ',P.presentation.thresholdCues(nTrial));
                    Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1); 
                    Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2); 
                    Screen('Flip',P.display.w); 
                    SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.cueOnset);
                    WaitSecs(P.presentation.sBlank);
                end
            end
        end
        
        fprintf('\n');
        
    end

    %% starting from the Awiszus-derived threshold temperature, we determine (and shuffle) the plateau intensities
    function P=DetermineSteps(P)
        
        P.plateaus.step1Order = P.painCalibData.AwThr+P.plateaus.step1Seq;
        P.plateaus.step2Order = P.painCalibData.AwThr+P.plateaus.step2Seq;
        
        % display plateaus for protocol creation and as sanity check
        fprintf('\nPrepare protocol using %1.1f°C as threshold with the following specifications:\n--\n',P.painCalibData.AwThr);
        for nTrial = 1:length(P.plateaus.step2Order)
            fprintf('Step %02d: %1.1f°C\n',nTrial,P.plateaus.step2Order(nTrial));
        end
        fprintf('--\nRepeat, awTT is %1.1f°C\n',P.painCalibData.AwThr);
        
    end

    function [abort,P]=TrialControl(P,O)

        abort=0;
        plateauLog = [];

        % SEGMENT -1 (yeah yeah): SCALE TRANSLATION; data NOT saved
        if P.startSection<4
            if P.toggles.doScaleTransl && P.toggles.doPainOnly
                P.toggles.doPainOnly = 0; % this is the whole point here, to translate the y/n binary via the two-dimensional VAS to the unidimensional

                [abort]=ShowInstruction(P,O,7,1);            
                if abort;QuickCleanup(P);return;end  

                step0Order = [P.painCalibData.AwThr P.painCalibData.AwThr+0.2 P.painCalibData.AwThr-0.2]; % provide some perithreshold intensities
                fprintf('\n=================================');
                fprintf('\n========SCALE TRANSLATION========\n');
                for nStep0Trial = 1:numel(step0Order)
                    fprintf('\n=======TRIAL %d of %d=======\n',nStep0Trial,numel(step0Order));
                    [abort]=ApplyStimulus(P,O,step0Order(nStep0Trial));
                    if abort; return; end
                    P=InstantiateCurrentTrial(P,O,-1,step0Order(nStep0Trial),-1);
                    P=PlateauRating(P,O);
                    [abort]=ITI(P,O,P.currentTrial.reactionTime);
                    if abort; return; end
                end

                P.toggles.doPainOnly = 1; % RESET
                
                [abort]=ShowInstruction(P,O,8,1);            
                if abort;QuickCleanup(P);return;end                  
                WaitSecs(0.5);

            end
        end        

        if P.startSection<6
            [abort]=ShowInstruction(P,O,3,1);            
            if abort;QuickCleanup(P);return;end  
        end
        
        % SEGMENT 0: RATING TRAINING; data NOT saved
        if P.startSection<5
            step0Order = repmat(P.painCalibData.AwThr,1,2);
            fprintf('\n=================================');
            fprintf('\n=========RATING TRAINING=========\n');
            for nStep0Trial = 1:numel(step0Order)
                fprintf('\n=======TRIAL %d of %d=======\n',nStep0Trial,numel(step0Order));
                [abort]=ApplyStimulus(P,O,step0Order(nStep0Trial));
                if abort; return; end
                P=InstantiateCurrentTrial(P,O,0,step0Order(nStep0Trial));
                P=PlateauRating(P,O);
                [abort]=ITI(P,O,P.currentTrial.reactionTime);
                if abort; return; end
            end
            
            if any(P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType==0)>25) % 25 being an arbitrary threshold
                fprintf('\nSb rated training stimuli at threshold (%1.1f°C) that should be rated VAS~0\nat',P.painCalibData.AwThr)
                fprintf('\t%d',P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType==0));
                fprintf('\n');
                fprintf('This does not impact the regression, but could be a sign of poor understanding of the instructions.\n');
                fprintf('Reinstruct if desired, then continue [%s] or abort [%s] (for new calibration)?\n',upper(char(P.keys.keyList(P.keys.resume))),upper(char(P.keys.keyList(P.keys.abort))));
                commandwindow;

                while 1
                    abort=0;
                    [keyIsDown, ~, keyCode] = KbCheck();
                    if keyIsDown
                        if find(keyCode) == P.keys.abort
                            abort=1;
                            return;
                        elseif find(keyCode) == P.keys.resume
                            break;
                        end
                    end         
                end
                
                WaitSecs(0.5);
            end
        end
        
        if P.startSection<6 % from this point on, data will be saved and integrated into regression analyses
            % SEGMENT 1: PSYCHOMETRIC-PERCEPTUAL SCALING
            if P.toggles.doPsyPrcScale
                fprintf('\n=================================');
                fprintf('\n=PSYCHOMETRIC-PERCEPTUAL SCALING=\n');
                for nStep1Trial = 1:numel(P.plateaus.step1Order)
                    fprintf('\n=======TRIAL %d of %d=======\n',nStep1Trial,numel(P.plateaus.step1Order));
                    [abort]=ApplyStimulus(P,O,P.plateaus.step1Order(nStep1Trial));
                    if abort; return; end
                    P=InstantiateCurrentTrial(P,O,1,P.plateaus.step1Order(nStep1Trial));
                    P=PlateauRating(P,O);
                    [abort]=ITI(P,O,P.currentTrial.reactionTime);
                    if abort; return; end
                end
            end

            % SEGMENT 2: FIXED INTENSITIES
            if P.toggles.doFixedInts
                fprintf('\n===============================');
                fprintf('\n=======FIXED INTENSITIES=======\n');
                for nStep2Trial = 1:length(P.plateaus.step2Order)
                    fprintf('\n=======TRIAL %d of %d=======\n',nStep2Trial,length(P.plateaus.step2Order));
                    [abort]=ApplyStimulus(P,O,P.plateaus.step2Order(nStep2Trial));
                    if abort; return; end                    
                    P=InstantiateCurrentTrial(P,O,2,P.plateaus.step2Order(nStep2Trial));
                    P=PlateauRating(P,O);
                    if nStep2Trial<length(P.plateaus.step2Order)
                        [abort]=ITI(P,O,P.currentTrial.reactionTime);
                        if abort; return; end
                    end
                end        
            end

            % SEGMENT 3: PRE-ESTIMATED INTENSITIES
            if P.toggles.doPredetInts         
                fprintf('\n===============================');
                fprintf('\n=====FIXED TARGET RATINGS======\n');

                x = P.painCalibData.PeriThrStimTemps(P.painCalibData.PeriThrStimType>0); % could restrict to ==1, but the more info the better
                y = P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType>0);
                [P.plateaus.step3Order,~] = FitData(x,y,P.plateaus.step3TarVAS,2);

                P = BetterGuess(P); % option to change FTRs if regression was off...
                for nStep3Trial = 1:length(P.plateaus.step3Order)
                    fprintf('\n=======TRIAL %d of %d=======\n',nStep3Trial,length(P.plateaus.step3Order));
                    [abort]=ApplyStimulus(P,O,P.plateaus.step3Order(nStep3Trial));
                    if abort; return; end
                    P=InstantiateCurrentTrial(P,O,3,P.plateaus.step3Order(nStep3Trial),P.plateaus.step3TarVAS(nStep3Trial));
                    P=PlateauRating(P,O);
                    [abort]=ITI(P,O,P.currentTrial.reactionTime);
                    if abort; return; end            
                end
            end

            % SEGMENT 4: ADAPTIVE PROCEDURE
            if P.toggles.doAdaptive
                fprintf('\n===============================');
                fprintf('\n====VARIABLE TARGET RATINGS====\n');
                nextStim = 1; % just so it isn't empty... 
                varTrial = 0;
                nH = figure;
                while ~isempty(nextStim)                        
                    ex = P.painCalibData.PeriThrStimTemps(P.painCalibData.PeriThrStimType>1);
                    ey = P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType>1);
                    if varTrial<2 % lin is more robust for the first additions; in the worst case [0 X 100], sig will get stuck in a step fct
                        linOrSig = 'lin';
                    else
                        linOrSig = 'sig';
                    end
                    [nextStim,~,tValidation,targetVAS] = CalibValidation(ex,ey,[],[],linOrSig,P.toggles.doConfirmAdaptive,1,0,nH,num2cell([zeros(1,numel(ex)-1) varTrial]),['s' num2str(numel(varTrial)+1)]);
                    if ~isempty(nextStim)           
                        varTrial = varTrial+1;
                        fprintf('\n=======VARIABLE TRIAL %d=======\n',varTrial);
                        [abort]=ApplyStimulus(P,O,nextStim);            
                        if abort; return; end
                        % note: ITI could additionally subtract tValidation!
                        P=InstantiateCurrentTrial(P,O,4,nextStim,P.currentTrial.targetVAS);
                        P=PlateauRating(P,O);
                        [abort]=ITI(P,O,P.currentTrial.reactionTime); % +tValidation
                        if abort; return; end
                    end
                end      
            end

            P = GetRegressionResults(P);
        else
            P = GetExistingCalibData(P);
            if isempty(plateauLog)
                error('Calibration data not found at %s. Aborting.',P.out.dir);
            end
        end
            
        if P.presentation.NValidationSessions
            for nv = 1:P.presentation.NValidationSessions
                [abort]=ShowInstruction(P,O,6,1); % announce thermode placement
                if abort;QuickCleanup(P);return;end  
                
                [abort]=ShowInstruction(P,O,1,1);    
                if abort;QuickCleanup(P);return;end  
    
                % REPEAT PREEXPOSURE with informed subthreshold intensities
                x = P.painCalibData.PeriThrStimTemps(P.painCalibData.PeriThrStimType>1 & P.painCalibData.PeriThrStimType<5);
                y = P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType>1 & P.painCalibData.PeriThrStimType<5);
                [P.plateaus.step5PreexpOrder,~] = FitData(x,y,P.plateaus.step5Preexp,2);

                [abort,~] = Preexposure(P,O,P.plateaus.step5PreexpOrder); 
                if abort;QuickCleanup(P);return;end  
    
                [abort]=ShowInstruction(P,O,5,1);     
                if abort;QuickCleanup(P);return;end  
                
                % SEGMENT 5: [usually trial purposes - validate calibrated temps, e.g. at fresh skin patch]
                fprintf('\n===============================');
                fprintf('\n=====VALIDATION WITH FIXED TARGET RATINGS======\n');
                                
                step5SeqR = Shuffle(step5SeqR);
                step5Seq  = [step5SeqF step5SeqR]; % concatenate fixed order with shuffled order                              
                
                x = P.painCalibData.PeriThrStimTemps(P.painCalibData.PeriThrStimType>1 & P.painCalibData.PeriThrStimType<5);
                y = P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType>1 & P.painCalibData.PeriThrStimType<5);
                [~,P.plateaus.step5Order] = FitData(x,y,step5Seq,2);

                InitialTrial(P,O);
                for nStep5Trial = 1:length(P.plateaus.step5Order)
                    fprintf('\n=======TRIAL %d of %d=======\n',nStep5Trial,length(P.plateaus.step5Order));
                    [abort]=ApplyStimulus(P,O,P.plateaus.step5Order(nStep5Trial));
                    if abort; return; end                    
                    P=InstantiateCurrentTrial(P,O,5,P.plateaus.step5Order(nStep5Trial));
                    P=PlateauRating(P,O);
                    [abort]=ITI(P,O,P.currentTrial.reactionTime);
                    if abort; return; end            
                end        
                
                WaitSecs(0.2);
                
            end
        end
        
    end

    function [abort]=ApplyStimulus(P,O,trialTemp)

        abort=0;
        [stimDuration]=CalcStimDuration(P,trialTemp,P.presentation.sStimPlateau);
        
        if P.painCalibData.PeriThrN==1 % Turn on the fixation cross for the first trial (no ITI to cover this)
            InitialTrial(P,O);
        end  
        
        fprintf('%1.1f°C stimulus initiated.',trialTemp); 

        tHeatOn = GetSecs;
        countedDown=1;
        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.heatOnsetSCR);
        
        if P.devices.thermoino        
            UseThermoino('Trigger'); % start next stimulus
            UseThermoino('Set',trialTemp); % open channel for arduino to ramp up      
            
            while GetSecs < tHeatOn + sum(stimDuration(1:2))
                [countedDown]=CountDown(GetSecs-tHeatOn,countedDown,'.');
                [abort]=LoopBreaker(P);
                if abort; break; end            
            end            
            
            fprintf('\n');
            UseThermoino('Set',P.pain.bT); % open channel for arduino to ramp down              
            
            if ~abort
                while GetSecs < tHeatOn + sum(stimDuration)
                    [countedDown]=CountDown(GetSecs-tHeatOn,countedDown,'.');
                    [abort]=LoopBreaker(P);
                    if abort; return; end            
                end      
            else
                return;
            end
        else
            SendTrigger(P,P.com.lpt.CEDAddressThermode,P.com.lpt.heatOnsetTHE);
            
            while GetSecs < tHeatOn + sum(stimDuration)
                [countedDown]=CountDown(GetSecs-tHeatOn,countedDown,'.');
                [abort]=LoopBreaker(P);
                if abort; return; end            
            end
        end                
        fprintf(' concluded.\n');

    end

    function InitialTrial(P,O)

        fprintf('[Initial trial, white fixation cross for %1.1f seconds, red cross for %1.1f seconds]\n',P.presentation.firstPlateauITI-P.presentation.firstPlateauCue,P.presentation.firstPlateauCue);

        if ~O.debug.toggleVisual
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1); 
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2); 
            tCrossOn = Screen('Flip',P.display.w); % gets timing of event for PutLog                   
        else
            tCrossOn = GetSecs;
        end
        while GetSecs < tCrossOn + P.presentation.firstPlateauITI-P.presentation.firstPlateauCue
            [abort]=LoopBreaker(P);
            if abort; return; end
        end

        if P.presentation.cueing==1 % else we don't want the red cross
            if ~O.debug.toggleVisual
                Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1); 
                Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2); 
                tCrossOn = Screen('Flip',P.display.w); % gets timing of event for PutLog
            else
                tCrossOn = GetSecs;
            end
            SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.cueOnset);
            
            while GetSecs < tCrossOn + P.presentation.firstPlateauCue
                [abort]=LoopBreaker(P);
                if abort; return; end                
            end
        end
    end

    function P=InstantiateCurrentTrial(P,O,stepId,trialTemp,varargin)

        P.painCalibData.PeriThrN = P.painCalibData.PeriThrN+1;

        P.currentTrial = struct; % reset
        P.currentTrial.N = P.painCalibData.PeriThrN;        
        P.currentTrial.nRating = 1; % currently, CalibHeat contains only one rating scale; cf P11_WindUp for expanding this
        P.currentTrial.ratingId = 11; % 11 = heat/pain VAS
        if P.toggles.doPainOnly      
            P.currentTrial.trialType = 'single'; 
        else
            P.currentTrial.trialType = 'double'; 
        end
        P.currentTrial.stepId = stepId;
        P.currentTrial.temp = trialTemp;

        if nargin>4
            P.currentTrial.targetVAS = varargin{1}; % include predicted VAS in log file (redundancy)
        else
            P.currentTrial.targetVAS = -1;
        end        

        P.currentTrial.sITI = round(P.presentation.sMinMaxPlateauITIs(1) + (P.presentation.sMinMaxPlateauITIs(2)-P.presentation.sMinMaxPlateauITIs(1))*rand,1); % note: this is RANDOM in a range, since it's just the calibration; could revert to balanced sITIs
        P.currentTrial.sCue = round(P.presentation.sMinMaxPlateauCues(1) + (P.presentation.sMinMaxPlateauCues(2)-P.presentation.sMinMaxPlateauCues(1))*rand,1); % note: this is RANDOM in a range, since it's just the calibration; could revert to balanced sCues

        P.log.scaleInitVAS(P.currentTrial.N,1) = randi(P.presentation.scaleInitVASRange); % different starting value for each trial; legacy log

    end

    % obtain rating for this trial
    function P=PlateauRating(P,O)

        if ~O.debug.toggleVisual
            % brief blank screen prior to rating
            tBlankOn = Screen('Flip',P.display.w);
        else
            tBlankOn = GetSecs;
        end
        while GetSecs < tBlankOn + 0.5 end                

        % VAS
        fprintf('VAS... ');
        
        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.VASOnset);
        if P.toggles.doPainOnly
            P = VASScale_v6(P,O);
        else
            P = VASScale_v6(P,O);
        end
        P = PutRatingLog(P);

        if ~O.debug.toggleVisual
            Screen('Flip',P.display.w);
        end
        
    end

    % save rating and other info for this trial
    function P = PutRatingLog(P)   
                
        n = P.painCalibData.PeriThrN;
        P.painCalibData.PeriThrStimType(n) = P.currentTrial.stepId; % legacy plateauLog(:,8);
        P.painCalibData.PeriThrStimOffs(n) = P.currentTrial.temp-P.painCalibData.AwThr; % legacy plateauLog(:,3);
        P.painCalibData.PeriThrStimTemps(n) = P.currentTrial.temp; % legacy plateauLog(:,4);
        P.painCalibData.PeriThrStimRatings(n) = P.currentTrial.finalRating; % legacy plateauLog(:,5);
        P.painCalibData.PeriThrReactionTime(n) = P.currentTrial.reactionTime; % legacy plateauLog(:,7);
        P.painCalibData.PeriThrResponseGiven(n) = P.currentTrial.response; % legacy plateauLog(:,6);
        P.painCalibData.PeriThrRatingTime(n) = GetSecs; % legacy plateauLog(:,11);
        P.painCalibData.PeriThrStimTarVAS(n) = P.currentTrial.targetVAS; % legacy plateauLog(:,12);
        P.painCalibData.PeriThrStimScaleInitVAS(n) = P.log.scaleInitVAS(P.currentTrial.N,1); % legacy plateauLog(:,13);
        % check if ITIs are worth saving here

        save([P.out.dir P.out.file], 'P');                
        
    end

    % wait for remainder of ITI after subtracting rating time
    function [abort] = ITI(P,O,tPlateauRating)
        
        abort=0;
        
        if ~O.debug.toggleVisual
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix1); 
            Screen('FillRect', P.display.w, P.style.white, P.style.whiteFix2);    
            Screen('Flip',P.display.w);  
        end        

        % contrast the time spent on the rating with the maximum time available for the rating
        % calculate required ITI for this trial from there                
        sITIRemaining=(P.presentation.sMaxRating-tPlateauRating)+P.currentTrial.sITI; 
        if sITIRemaining<P.currentTrial.sCue
            sITIRemaining = P.currentTrial.sCue; % we at least want to have the cue
        end
            
        % wait for remainder of ITI
        fprintf('ITI (%1.1fs)',sITIRemaining);        
        tITIOn = GetSecs;

        countedDown=1;
        SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.ITIOnset);
        
        while GetSecs < tITIOn + sITIRemaining
            [countedDown]=CountDown(GetSecs-tITIOn,countedDown,'.');                             
            [abort]=LoopBreaker(P);
            if abort; return; end
                
            % switch on red cross and wait a bit so it won't get switched on a thousand times
            if P.presentation.cueing==1 % else we don't want the red cross
                if GetSecs>tITIOn+sITIRemaining-P.currentTrial.sCue && GetSecs<tITIOn+sITIRemaining-P.currentTrial.sCue+P.presentation.sBlank
                    fprintf(' [Red cross at %1.1fs]',P.currentTrial.sCue);
                    if ~O.debug.toggleVisual
                        Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix1); 
                        Screen('FillRect', P.display.w, P.style.red, P.style.whiteFix2); 
                        Screen('Flip',P.display.w);  
                    end
                    SendTrigger(P,P.com.lpt.CEDAddressSCR,P.com.lpt.cueOnset);
                    WaitSecs(P.presentation.sBlank);
                end
            end
        end
        fprintf('\n'); 
                
    end

    function P = GetRegressionResults(P)
  
        if P.toggles.doPainOnly
            thresholdVAS = 0;
        else
            thresholdVAS = 50;
        end
        x = P.painCalibData.PeriThrStimTemps(P.painCalibData.PeriThrStimType>1 & P.painCalibData.PeriThrStimType<5);
        y = P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType>1 & P.painCalibData.PeriThrStimType<5);
        [predTempsLin,predTempsSig,predTempsRob,betaLin,betaSig,betaRob] = FitData(x,y,[thresholdVAS P.plateaus.VASTargets],2);

        painThresholdLin = predTempsLin(1);
        painThresholdSig = predTempsSig(1);
        predTempsLin(1) = []; % remove threshold temp, retain only VASTargets
        predTempsSig(1) = []; % remove threshold temp, retain only VASTargets
        
        if betaLin(2)<0 
            warning(sprintf('\n\n********************\nNEGATIVE SLOPE. This is physiologically highly implausible. Exclude participant.\n********************\n'));
        end        
            
        % construct regression results output file

        P.painCalibData.ResInterLin = betaLin(1); % lin intercept
        P.painCalibData.ResSlopeLin = betaLin(2); % lin slope
        P.painCalibData.ResInterSig = betaSig(1); % sig intercept
        P.painCalibData.ResSlopeSig = betaSig(2); % sig slope
        P.painCalibData.ResThrAw = P.painCalibData.AwThr; % as per Awiszus thresholding
        P.painCalibData.ResThrLin = painThresholdLin; % as per linear regression for VAS 50 (pain threshold) 
        P.painCalibData.ResThrSig = painThresholdSig; % as per nonlinear regression for VAS 50 (pain threshold)

        fprintf('\n\n==========REGRESSION RESULTS==========\n');
        fprintf('>>> Linear intercept %1.1f, slope %1.1f. <<<\n',betaLin);        
        fprintf('>>> Sigmoid intercept %1.1f, slope %1.1f. <<<\n',betaSig);        
        fprintf('To achieve VAS50, use %1.1f%°C (lin) or %1.1f°C (sig).\n',painThresholdLin,painThresholdSig);
        fprintf('This yields for\n');

        for vas = 1:numel(P.plateaus.VASTargets)        
            fprintf('- VAS%d: %1.1f°C (lin), %1.1f°C (sig)\n',P.plateaus.VASTargets(vas),predTempsLin(vas),predTempsSig(vas)); 
        end
        
        save([P.out.dir P.out.file], 'P');         
        
    end
    
%%%%%%%%%%%%%%%%%%%%%%%%%
% AUXILIARY FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%

    function [ITIs,cues] = DetermineITIsAndCues(nStims,mMITIJ,mMCJ)
        
        ITIs = [];
        cues = [];
        
        if isempty(nStims) || ~nStims            
            return;
        end
        
        nITIJitter                      = (max(mMITIJ)-min(mMITIJ))/(nStims-1); % yields the increment size required for length(sequence) trials
        sITIJitter                      = min(mMITIJ):nITIJitter:max(mMITIJ);
        nCueJitter                      = (max(mMCJ)-min(mMCJ))/(nStims-1); % yields the increment size required for length(sequence) trials
        sCueJitter                      = min(mMCJ):nCueJitter:max(mMCJ);
        
        if isempty(sITIJitter) sITIJitter(nStims)=mean(mMITIJ); end % then max(mMITIJ)==min(mMITIJ)
        if isempty(sCueJitter) sCueJitter(nStims)=mean(mMCJ); end % then max(mMCJ)==min(mMCJ)
        
        % construct ITI list matching the stimulus sequence        
        ITIs = sITIJitter(randperm(length(sITIJitter)));
        cues = sCueJitter(randperm(length(sCueJitter)));       
        
    end

%% returns a vector with riseTime, P.presentation.sStimPlateau and fallTime for the target stimulus
    function [stimDuration] = CalcStimDuration(P,temp,sStimPlateau)
        diff=abs(temp-P.pain.bT);
        riseTime=diff/P.pain.rS;
        fallTime=diff/P.pain.fS;
        
        stimDuration=[riseTime sStimPlateau fallTime];
    end

% when skipping parts of the calibration in StartExperimentAt, try to obtain existing calib data
    function P = GetExistingCalibData(P)       

        painCFiles = cellstr(ls(P.out.dir));   
        painCFiles = painCFiles(painCFiles,'painCalibData');
        
        if isempty(painCFiles)
            error('Previous calibration data file not found in %s. Aborting.',P.out.dir);
        elseif numel(painCFiles)>1
            painCFiles = painCFiles(end);
            warning('Multiple calibration data files found. Proceeding with most recent one (%s).',cell2mat(painCFiles))
            existP = load([P.out.dir cell2mat(painCFiles)]); % load existing parameters
            existP = existP.P;

            try 
                P.painCalibData.PeriThrN = existP.painCalibData.PeriThrStimType;
                P.painCalibData.PeriThrReactionTime = existP.painCalibData.PeriThrReactionTime;
                P.painCalibData.PeriThrResponseGiven = existP.painCalibData.PeriThrResponseGiven;
                P.painCalibData.PeriThrStimScaleInitVAS = existP.painCalibData.PeriThrStimScaleInitVAS;
            catch % for old log files
                warning('Old log file, some non-critical data not available.');
                P.painCalibData.PeriThrN = size(existP.painCalibData.PeriThrStimType,1);
                P.painCalibData.PeriThrReactionTime = NaN(size(existP.painCalibData.PeriThrStimType));
                P.painCalibData.PeriThrResponseGiven = NaN(size(existP.painCalibData.PeriThrStimType));
                P.painCalibData.PeriThrStimScaleInitVAS = NaN(size(existP.painCalibData.PeriThrStimType));
            end
            P.painCalibData.PeriThrStimType = existP.painCalibData.PeriThrStimType;
            P.painCalibData.PeriThrStimOffs = existP.painCalibData.PeriThrStimOffs; 
            P.painCalibData.PeriThrStimTemps = existP.painCalibData.PeriThrStimTemps; 
            P.painCalibData.PeriThrStimRatings = existP.painCalibData.PeriThrStimRatings; 
            P.painCalibData.PeriThrRatingTime = existP.painCalibData.PeriThrRatingTime;
            P.painCalibData.PeriThrStimTarVAS = existP.painCalibData.PeriThrStimTarVAS;

            P.painCalibData.ResInterLin = existP.painCalibData.ResInterLin;
            P.painCalibData.ResSlopeLin = existP.painCalibData.ResSlopeLin;
            P.painCalibData.ResInterSig = existP.painCalibData.ResInterSig;
            P.painCalibData.ResSlopeSig = existP.painCalibData.ResSlopeSig;
            P.painCalibData.ResThrAw = existP.painCalibData.ResThrAw;
            P.painCalibData.ResThrLin = existP.painCalibData.ResThrLin;
            P.painCalibData.ResThrSig = existP.painCalibData.ResThrSig;

            P.painCalibData.notes{end+1} = sprintf('Perithresholding data imported from %s',[P.out.dir cell2mat(painCFiles)]);
        end             

    end

%% Set Marker for CED and BrainVision Recorder
    function SendTrigger(P,address,port)
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

%% use so the experiment can be aborted with proper key presses
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
        catch EXC
            %disp('Round function  pre 2014 !');   
            y=round(X*10^N)/10^N;
        end
    end
   
    function QuickCleanup(P)
        fprintf('\nAborting...');
        if P.devices.thermoino            
            UseThermoino('Kill');
        end        
        sca; % close window; also closes io64
        ListenChar(0); % use keys again
        commandwindow;        
    end   

    function P = BetterGuess(P)
        
        fprintf('Ratings so far were for\n');
        fprintf('%1.1f\t',P.painCalibData.PeriThrStimTemps(P.painCalibData.PeriThrStimType>0));
        fprintf('\n');
        fprintf('%d\t',P.painCalibData.PeriThrStimRatings(P.painCalibData.PeriThrStimType>0));
        fprintf('\n\n');

        fprintf('Suggested target intensities for\n');
        fprintf('%d\t',P.plateaus.step3TarVAS);
        fprintf('\n');
        fprintf('%1.1f\t',P.plateaus.step3Order);
        
        fprintf('\nWhen in doubt, try [42.5 43.5 44.5]\n(this pattern MUST be 2 digits dot 1 digit, e.g. 44.0 NOT just 44)\nComputes _all_ chars, so if backspace or cursor were used, enter an x and press Enter, then re-enter.\n\n');

        ListenChar(0);
        
        % this weird construct is necessary because some lingering keyboard input just skips the first input() apparently...
%         fprintf('Please press [Return] once...\n');
%         KbWait([], 2)
%         WaitSecs(0.5);
%
%         override = input(sprintf('Press [Return] to continue, or enter full vector (length %d) to override.\n',numel(step3Order)));
        
        commandwindow;
        override = 'x';
        while ( ~isempty(regexp(override,'x','ONCE')) || length(override)~=16 ) && ~isempty(override)
            override = GetString();
        end
        if ~isempty(override)
            override=regexprep(override,'[\[\]]','');
            override=regexp(override,'\d{2}\.\d{1}','MATCH');
            override=str2double(override);
            P.plateaus.step3Order = override;
        end
        
        ListenChar(2);

    end


    function PrintDurations(P)

        durationTotal=P.time.scriptEnd-P.time.scriptStart;
        durationExp=P.time.scriptEnd-P.time.threshStart;
        durationThresholding=P.time.threshEnd-P.time.threshStart;
        durationPlateaus=P.time.scriptEnd-P.time.plateauStart;    

        fprintf('\n--\n');
        fprintf('Total minutes since script start: %1.1f\n',SecureRound(durationTotal/60,1));
        fprintf('Minutes since start of experiment proper: %1.1f\n',SecureRound(durationExp/60,1));
        fprintf('Minutes thresholding: %1.1f\n',SecureRound(durationThresholding/60,1));
        fprintf('Minutes plateaus: %1.1f\n',SecureRound(durationPlateaus/60,1));

    end
