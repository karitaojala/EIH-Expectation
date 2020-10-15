function P = VASScale_v5(P,O,varargin)

KbName('UnifyKeyNames');

if ~nargin
    
    disp('No input arguments provided. Using default trial settings.')
    
    LANGUAGE = 'en'; % de or en
    
    OVERRIDE_SCREEN=1;
    screens                     =  Screen('Screens');                  % Find the number of the screen to be opened
    if isempty(OVERRIDE_SCREEN)
        screenNumber          =  max(screens);                       % The maximum is the second monitor
    else
        screenNumber          =  OVERRIDE_SCREEN;
    end
    screenRes = Screen('resolution',screenNumber);
    commandwindow;
    
    [~, hostname]               = system('hostname');
    hostname                    = deblank(hostname);
    
    %ListenChar(2);
    %clear functions;
    
    keyList                     = KbName('KeyNames');
    
    if strcmp(hostname,'stimpc1')
        keys.left               = KbName('2@'); % yellow button
        keys.right              = KbName('4$'); % red button
        keys.confirm            = KbName('3#'); % green button
        %keys.esc                = KbName('Escape'); % this may have to do with ListenChar
        keys.esc                = KbName('esc'); % this may have to do with ListenChar
    else
        keys.left               = KbName('LeftArrow');
        keys.right              = KbName('RightArrow');
        keys.confirm            = KbName('Return');
        keys.esc                = KbName('Escape'); % this may have to do with ListenChar
    end
    
    if ~isempty(OVERRIDE_SCREEN)
        screenNumber            = OVERRIDE_SCREEN;
    end
    
    backgroundColor = [70 70 70];
    window = Screen('OpenWindow', screenNumber, backgroundColor);
    Screen('Flip',window);
    
    windowRect                  = [0 0 screenRes.width screenRes.height];
    startY                      = screenRes.height/4;
    
    durRating                   = 60;
    defaultRating               = 50;
    scaleType                   = 'Test'; % default 'Test'
    ratingId                    = 1;
    nRating                     = 1;
else
    if O.debug.toggleVisual
        warning('Visuals deactivated, returning RANDOM trial rating.');
        P.currentTrial(P.currentTrial(1).nRating).finalRating = round(rand*100);
        P.currentTrial(P.currentTrial(1).nRating).reactionTime = NaN;
        P.currentTrial(P.currentTrial(1).nRating).response = 0;
        return;
    end
    
    window          = P.display.w;
    windowRect      = P.display.rect;
    durRating       = P.presentation.sMaxRating;
    defaultRating 	= P.log.scaleInitVAS(P.currentTrial(1).N,P.currentTrial(1).nRating);
    backgroundColor = P.style.backgr;
    startY          = P.display.startY;
    keys            = P.keys;
    scaleType       = P.currentTrial(1).trialType;
    ratingId        = P.currentTrial(P.currentTrial(1).nRating).ratingId;
    nRating         = P.currentTrial(1).nRating;
    LANGUAGE        = P.language; % de or en
end

% VASScale_v4([],P.display.wHandle,P.display.rect,P.presentation.sPlateauMaxRating,scaleInitVAS,P.style.backgr,P.style.startY,P.keys,'Pain',1,P.language);

if ~any(strcmp(LANGUAGE,{'de','en'}))
    fprintf('Instruction language "%s" not recognized. Aborting...',LANGUAGE);
    return;
end

%% key settings
keyList = KbName('KeyNames');

% error handling (why is this here? It's nonsensical...)
if isempty(window); error('Please provide window pointer for rating scale!'); end
if isempty(windowRect); error('Please provide window rect for rating scale!'); end
if isempty(durRating); error('Duration of rating has to be specified!'); end

%% Default values
nRatingSteps = 101;
scaleWidth = 700;
textSize = 30; % default 20
lineWidth = 6;
scaleColor = [255 255 255];
activeColor = [255 0 0];
if isempty(defaultRating); defaultRating = round(nRatingSteps/2); end
if isempty(backgroundColor); backgroundColor = 0; end

%% Calculate rects
activeAddon_width = 1.5;
activeAddon_height = 20;
[xCenter, yCenter] = RectCenter(windowRect);
yCenter = startY;
axesRect = [xCenter - scaleWidth/2; yCenter - lineWidth/2; xCenter + scaleWidth/2; yCenter + lineWidth/2];
lowLabelRect = [axesRect(1),yCenter-20,axesRect(1)+6,yCenter+20];
highLabelRect = [axesRect(3)-6,yCenter-20,axesRect(3),yCenter+20];
midLabelRect = [xCenter-3,yCenter-20,xCenter+3,yCenter+20];
ticPositions = linspace(xCenter - scaleWidth/2,xCenter + scaleWidth/2-lineWidth,nRatingSteps);
% ticRects = [ticPositions;ones(1,nRatingSteps)*yCenter;ticPositions + lineWidth;ones(1,nRatingSteps)*yCenter+tickHeight];
activeTicRects = [ticPositions-activeAddon_width;ones(1,nRatingSteps)*yCenter-activeAddon_height;ticPositions + lineWidth+activeAddon_width;ones(1,nRatingSteps)*yCenter+activeAddon_height];
% keyboard

Screen('TextSize',window,textSize);
Screen('TextColor',window,[255 255 255]);
Screen('TextFont', window, 'Arial');
currentRating = defaultRating;
finalRating = currentRating;
reactionTime = 0;
response = 0;
first_flip  = 1;
startTime = GetSecs;
numberOfSecondsRemaining = durRating;
nrbuttonpresses = 0;

if strcmpi(scaleType,'single') % regular 0-100 VAS
    scaleversion=1;
    if ratingId==11 % PAIN
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Bitte bewerten Sie, wie schmerzhaft der Hitzereiz war', '' };
            anchorStrings       = { 'kein', 'Schmerz', 'unertr�glicher' 'Schmerz' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { 'Please rate how painful the heat was', '' };
            anchorStrings       = { 'not', 'painful', 'unbearably' 'painful' };
        end
    elseif ratingId==21 % NOISE
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Bitte bewerten Sie, wie unangenehm der Ton war', '' };
            anchorStrings       = { 'nicht', 'unangenehm', 'unertr�glich', 'unangenehm' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { 'Please rate how loud the tone was', '' };
            anchorStrings       = { 'not', 'unpleasant', 'unbearably', 'unpleasant' };
        end
    elseif ratingId==31 % intensity
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Wie _intensiv_ war der letzte Stimulus?', '' };
            anchorStrings       = { 'unbemerkbar', '', 'extrem', 'intensiv' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { '[Placeholder]', '' };
            anchorStrings       = { '', '', '', '' };
        end
    elseif ratingId==32 % unpleasantness
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Wie _unangenehm_ war der letzte Stimulus?', '' };
            anchorStrings       = { 'nicht', 'unangenehm', 'extrem', 'unangenehm' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { '[Placeholder]', '' };
            anchorStrings       = { '', '', '', '' };
        end
    elseif ratingId==33 % painfulness
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Wie _schmerzhaft_ war der letzte Stimulus?', '' };
            anchorStrings       = { 'nicht', 'schmerzhaft', 'extrem', 'schmerzhaft' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { '[Placeholder]', '' };
            anchorStrings       = { '', '', '', '' };
        end
    elseif ratingId==34 % weirdness
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Wie _merkw�rdig_ war der letzte Stimulus?', '' }; % oder eigenartig?
            anchorStrings       = { 'nicht', 'merkw�rdig', 'extrem', 'merkw�rdig' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { '[Placeholder]', '' };
            anchorStrings       = { '', '', '', '' };
        end
    end
    
    % Screen('FillRect',window,scaleColor,midLabelRect);
    
    for i = 1:length(anchorStrings)
        [~, ~, textBox] = DrawFormattedText(window,char(anchorStrings(i)),0,0,backgroundColor);
        textWidths(i)=(textBox(3)-textBox(1))/2;
    end
    
elseif strcmpi(scaleType,'double') % 0-49/50-100 VAS (includes middle anchor)
    scaleversion=2;
    if ratingId==11 % HEAT
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Bitte bewerten Sie, wie stark der Hitzereiz war', '' };
            anchorStrings       = { 'keine', 'Empfindung', 'minimaler', 'Schmerz', 'unertr�glicher' 'Schmerz' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { 'Please rate how intense the heat was', '' };
            anchorStrings       = { 'no', 'sensation', 'minimally', 'painful', 'unbearably' 'painful' };
        end
    elseif ratingId==21 % SOUND
        if strcmp(LANGUAGE,'de')
            instructionStrings  = { 'Bitte bewerten Sie, wie laut der Ton war', '' };
            anchorStrings       = { 'unh�rbar', 'minimal', 'unangenehm', 'extrem', 'unangenehm' };
        elseif strcmp(LANGUAGE,'en')
            instructionStrings  = { 'Please rate how loud the tone was', '' };
            anchorStrings       = { 'inaudible', 'minimally', 'unpleasant', 'extremely', 'unpleasant' };
        end
    end
    
    for i = 1:length(anchorStrings)
        [~, ~, textBox] = DrawFormattedText(window,char(anchorStrings(i)),0,0,backgroundColor);
        textWidths(i)=(textBox(3)-textBox(1))/2;
    end
    
elseif strcmpi(scaleType,'Test')
    scaleversion=3;
    Screen('FillRect',window,scaleColor,midLabelRect);
%     DrawFormattedText(window, 'VAS scale line 1', 'center',yCenter-100, scaleColor);
%     DrawFormattedText(window, 'VAS scale line 2', 'center',yCenter-70, scaleColor);
    %[textWidths]=DetermineWidths( { 'left', 'anchor', 'right' 'anchor' },window,backgroundColor );
    instructionStrings  = { 'Bitte bewerten Sie, wie stark der Reiz war', '' };
    anchorStrings ={ 'left', 'anchor', 'central', 'anchor', 'right' 'anchor' };
    for i = 1:length(anchorStrings)
        [~, ~, textBox] = DrawFormattedText(window,char(anchorStrings(i)),0,0,backgroundColor);
        textWidths(i)=(textBox(3)-textBox(1))/2;
    end
%         Screen('DrawText',window,stringArray{1},axesRect(1)-textWidths(1)/2,yCenter+25,scaleColor);
%         Screen('DrawText',window,stringArray{2},axesRect(1)-textWidths(2)/2,yCenter+25+textSize,scaleColor);
%         Screen('DrawText',window,stringArray{3},xCenter-textWidths(3)/2,yCenter+25,scaleColor);
%         Screen('DrawText',window,stringArray{4},xCenter-textWidths(4)/2,yCenter+25+textSize,scaleColor);
%         Screen('DrawText',window,stringArray{5},axesRect(3)-textWidths(5)/2,yCenter+25,scaleColor);
%         Screen('DrawText',window,stringArray{6},axesRect(3)-textWidths(6)/2,yCenter+25+textSize,scaleColor);
        
end
yCenter25=yCenter+25;

%%%%%%%%%%%%%%%%%%%%%%% loop while there is time %%%%%%%%%%%%%%%%%%%%%
% tic; % control if timing is as long as durRating
while numberOfSecondsRemaining  > 0
    Screen('FillRect',window,backgroundColor);
    Screen('FillRect',window,scaleColor,axesRect);
    Screen('FillRect',window,scaleColor,lowLabelRect);
    Screen('FillRect',window,scaleColor,highLabelRect);
    Screen('FillRect',window,activeColor,activeTicRects(:,currentRating));
    
    if scaleversion==1
        DrawFormattedText(window, instructionStrings{1}, 'center',yCenter-100, scaleColor);
        DrawFormattedText(window, instructionStrings{2}, 'center',yCenter-70, scaleColor);
        Screen('DrawText',window,anchorStrings{1},axesRect(1)-textWidths(1),yCenter25,scaleColor);
        Screen('DrawText',window,anchorStrings{2},axesRect(1)-textWidths(2),yCenter25+textSize,scaleColor);
        Screen('DrawText',window,anchorStrings{3},axesRect(3)-textWidths(3),yCenter25,scaleColor);
        Screen('DrawText',window,anchorStrings{4},axesRect(3)-textWidths(4),yCenter25+textSize,scaleColor);
    elseif scaleversion>=2
        Screen('FillRect',window,scaleColor,midLabelRect);
        DrawFormattedText(window, instructionStrings{1}, 'center',yCenter-100, scaleColor);
        DrawFormattedText(window, instructionStrings{2}, 'center',yCenter-70, scaleColor);
        Screen('DrawText',window,anchorStrings{1},axesRect(1)-textWidths(1),yCenter25,scaleColor);
        Screen('DrawText',window,anchorStrings{2},axesRect(1)-textWidths(2),yCenter25+textSize,scaleColor);
        Screen('DrawText',window,anchorStrings{3},xCenter-textWidths(3),yCenter25,scaleColor);
        Screen('DrawText',window,anchorStrings{4},xCenter-textWidths(4),yCenter25+textSize,scaleColor);
        Screen('DrawText',window,anchorStrings{5},axesRect(3)-textWidths(5),yCenter25,scaleColor);
        Screen('DrawText',window,anchorStrings{6},axesRect(3)-textWidths(6),yCenter25+textSize,scaleColor);
    end
    
    % Remove this line if a continuous key press should result in a continuous change of the scale; wait what?
    %     while KbCheck; end
    
    if response == 0
        
        % set time 0 (for reaction time)
        if first_flip   == 1
            secs0       = Screen('Flip', window); % output Flip -> starttime rating
            first_flip  = 0;
            % after 1st flip -> just flips without setting secs0 to null
        else
            Screen('Flip', window);
        end
        
        [ keyIsDown, secs, keyCode ] = KbCheck; % this checks the keyboard very, very briefly.
        if keyIsDown % only if a key was pressed we check which key it was
            response = 0; % predefine variable for confirmation button
            nrbuttonpresses = nrbuttonpresses + 1;
            
            if scaleversion==3
                pressed = find(keyCode, 1, 'first');
                fprintf('%s\n',char(keyList(pressed)));
            end
            
            if keyCode(keys.right) % if it was the key we named key1 at the top then...
                currentRating = currentRating + 1;
                finalRating = currentRating;
                response = 0;
                if currentRating > nRatingSteps
                    currentRating = nRatingSteps;
                end
            elseif keyCode(keys.left)
                currentRating = currentRating - 1;
                finalRating = currentRating;
                response = 0;
                if currentRating < 1
                    currentRating = 1;
                end
            elseif keyCode(keys.confirm)
                finalRating = currentRating-1;
                fprintf('Rating %d\n',finalRating);
                response = 1;
                reactionTime = secs - secs0;
                
                if scaleversion==3
                    ListenChar(0);
                    sca;
                end
                
                break;
            end
        end
    end
    
    numberOfSecondsElapsed   = (GetSecs - startTime);
    numberOfSecondsRemaining = durRating - numberOfSecondsElapsed;
    if  nrbuttonpresses && ~response
        finalRating = currentRating - 1;
        reactionTime = durRating;
    end
    
end

if  nrbuttonpresses == 0
    reactionTime = durRating;
    fprintf('Rating %d (NO RESPONSE, NOT CONFIRMED)\n',finalRating)
elseif ~response
    fprintf('Rating %d (NOT CONFIRMED)\n',finalRating)
end

P.currentTrial(nRating).finalRating = finalRating;
P.currentTrial(nRating).reactionTime = reactionTime;
P.currentTrial(nRating).response = response;

if strcmp(scaleType,'Test')
    ListenChar(0);
    sca;
end
