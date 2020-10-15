%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ADAPTIVE CALIBRATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% This function suggests stimulus intensities that are informative for either a linear or a sigmoid fit,
% to ensure even sampling in a number of predefined bins. For example, if all ratings/data points from a 
% calibration procedure on a 0-100 fell below 50, the routine would suggest temperatures likely to yield
% ratings above 50 VAS.
%
% It was originally designed for pain perception calibration, but (apart from the odd output) is agnostic
% towards which numbers you give it, so it works for every VAS-scaled responses...
%
% Input variables
% x is a 1xk vector of stimulus intensities (predictor)
% y is a 1xk vector of ratings (criterion)
% (optional) bins are the VAS ranges desired to be sampled (default 0:20:100; don't get too narrow here)
% (optional) minNInBins is the number of data points desired per bin (default 1)
% (optional) varargin{1} is confirm, that is, output intensity nextStim will be displayed and can be modified or rejected (0 or 1; default 0)
% (optional) varargin{2} is verbosity, i.e. some supplementary output in the commandline (0 or 1; default 0)
% (optional) varargin{3} is showFig (0 or 1; default 0)
% (optional) varargin{4} is a figure handle on which showFig can be applied; if not set, a new figure will be created
% (optional) varargin{5} is a cell vector the size of x|y, if ~0 then data point will be filled in with the contents of the array instead of the circle, 
%                        intended for tracking data points while using a single figure
% (optional) varargin{6} is a string used to denote the suggested next stimulus (nextStim)

% Examples
% [nextStim,~] = CalibValidation([43.0 43.8 -40.9 43.3],[61 67 39 70]);
% [nextStim,~] = CalibValidation(x,y,[],[],1); % 
% [nextStim,~] = CalibValidation(x,y,[],[],1,1,1); % full output (verbose feedback and new figure per iteration)
% [nextStim,~] = CalibValidation(x,y,[],[],1,1,1,F); % full output with figure handle

% To do
% Joint linear/sigmoid analysis with option to decide which one to base the estimate on

% 2019-06-03
% Bjoern Horing, University Medical Center Hamburg-Eppendorf

function [nextStim,varargout] = CalibValidation(x,y,bins,minNInBins,linOrSig,varargin)
    
    [~, hostname]                   = system('hostname');
    hostname                        = deblank(hostname);
    
%     if strcmp(hostname,'stimpc1')        
%         addpath('D:\horing\MATLAB\includes');
%     else
%         addpath('C:\Users\horing\Documents\MATLAB\includes');
%     end

    sStart = GetSecs;
    
    %----------------------------------------------
    % HARDCODED VARIABLES
    % basic and security functions
    vargPos = 5; % position of varargins; TODO
    TOLERANCE = 100; % tolerance (originally for °C, so it needs to be overwritten for other physical intensities)
    % linOrSig = 'sig'; % toggle for 'lin'ear or 'sig'moid regression
    
    % parameters for outlier removal
    outRemParams{1} = 'cookd'; % distance measure; for example, 'cookd' or 'dffit'; for now, only cookd implemented (because it's easy to get from fitnlm
    outRemParams{2} = 2; % sd of distance measure; >=2 is recommended, but subject to further experience with the measure
    
    %----------------------------------------------
    % Possible input variables
    if ~nargin || ( isempty(x) && isempty(y) )% get some defaults
        x = [5  7 -3 10]+30; % not sure of these for pressure
        y = [61 67 39 70];
    end    
    if nargin<3 || ( nargin>2 && isempty(bins) )
        bins = 0:20:100; % coverage criteria
    end
    if nargin<4 || ( nargin>3 && isempty(minNInBins) )
         minNInBins = 1; % coverage criteria  
    end
    
    confirm     = 0;
    verbosity   = 0;
    showFig     = 0;
    if nargin==6
        confirm     = varargin{1};
    elseif nargin==7
        confirm     = varargin{1};
        verbosity   = varargin{2};
    elseif nargin==8
        confirm     = varargin{1};
        verbosity   = varargin{2};
        showFig     = varargin{3};        
    elseif nargin>8
        confirm     = varargin{1};
        verbosity   = varargin{2};
        showFig     = varargin{3};
        try        
            figure(varargin{4});
        catch
            warning('Figure handle could not be processed. Opening new figure.');
            nH = figure;
        end
    end
    dispDataText = [];
    dispSuggText = [];
    nHLW = 2;
    nHFA = 0.3;
    if nargin>9 % some design adjustments if we want to have the numerical data points
        if numel(varargin{5})<numel(x)
            warning('Fewer labels provided than there are data points. Continuing without labels.');
        else
            dispDataText = varargin{5}; 
        end
    end
    if nargin>10
        dispSuggText = varargin{6};        
    end
    if nargin>11 % this is an afterthought, I should switch to named vars and if exist('bla') eventually
        xl = varargin{7}; 
    else
        xl = 20:1:100; % xlim AND the range in which predicted values will be calculated for visualization
    end

    if ~isempty(dispDataText) || ~isempty(dispSuggText)
        nHLW = 1; % regression curve line width
        nHFA = 0.1; % patch face alpha
    end
    
    % variable preparation
    if any(diff(bins)<=0)
        error('Bins have to be monotonically increasing.');
    end
    binMeans = bins(1:end-1)+diff(bins)/2;        
    
    if nargin<9 && showFig
        nH = figure;
    end
    
    % CORE ANALYSIS
    if strcmp(linOrSig,'lin')
        regs = regstats(x,y,'linear');
    elseif strcmp(linOrSig,'sig')
        beta0 = [mean(x) 1];        
        nlm = fitnlm(x,y,@localsigfun,beta0); 
        regs.beta(1) = nlm.Coefficients.Estimate(1);
        regs.beta(2) = nlm.Coefficients.Estimate(2);        
        regs.cookd = nlm.Diagnostics.CooksDistance;
    else
        error('Unknown regression type.');
    end

% troubleshooting: normalized identical; still does not yield the same results
%     iregs = regstats(y,x,'linear'); % leaving it in to demonstrate how these do not yield the same results
%     regs = regstats(zscore(x),zscore(y),'linear');
%     iregs = regstats(zscore(y),zscore(x),'linear');    
%     regs.beta
%     iregs.beta
    
    if showFig        
        title(sprintf('Calib results w %d stimuli',numel(x)));
        xlim([min(xl) max(xl)]);
        ylim([0 100]);    
        for b = 1:numel(bins)
            line(xlim,[bins(b) bins(b)],'LineStyle',':','Color',[0.5 0.5 0.5]);
        end
        hold on;
        if isempty(dispDataText)
            scatter(x,y);
        else % else we have to write every data point separately
            for xx = 1:numel(x)
                if dispDataText{xx}==0
                    scatter(x(xx),y(xx),'b','LineWidth',1.5);
                else
                    scatter(x(xx),y(xx),10,[0 0 0],'o','filled')
                    if isnumeric(dispDataText{xx})
                        t = num2str(dispDataText{xx});
                    else
                        t = dispDataText{xx};
                    end
                    text(x(xx),y(xx),t,'FontSize',12,'FontWeight','bold')                    
                end
            end
        end
        xlabel('Stimulus intensity');
        ylabel('Pain rating (VAS)');
        
        if strcmp(linOrSig,'lin')
            plot(regs.beta(1)+regs.beta(2).*[0:100],0:100,'LineWidth',nHLW,'Color',[0 0 1]);        
            % plot(xl(1):xl(2),iregs.beta(1)+iregs.beta(2).*[xl(1):xl(2)],'LineWidth',2,'Color',[1 0 0]); % NOTE: THESE RESULTS ARE NOT THE SAME!    
        elseif strcmp(linOrSig,'sig')
            plot(xl,localsigfun(regs.beta,xl),'LineWidth',nHLW,'Color',[0 0 1]);
        end
    end
    
    % check distance of data points in bins
    noBin = [];    
    for b = 2:numel(bins) % start with seconds to get diffs
        inBin = find(y>=bins(b-1) & y<bins(b)); % indices for all VAS data points within bin        
        
        % here we throw out outliers; does not need to be recursive because the regs is not recalculated...
        inBin = RemoveOutliers(outRemParams,regs,inBin,x,y,showFig);        
        
        if numel(inBin)<minNInBins
            if verbosity
                cprintf([1 0 0],'No sufficient coverage in bin %d-%d\n',bins(b-1),bins(b))
            end
            noBin = [noBin;binMeans(b-1)];
            
            if showFig
                patch([[min(xl) max(xl)] fliplr([min(xl) max(xl)])],[bins(b-1) bins(b-1) bins(b) bins(b)],[1 0 0],'FaceAlpha',nHFA,'EdgeColor','none');
            end
        end
    end
    if showFig
        drawnow; % not sure why this is necessary
    end
    
    selBin = [];
    nextStim = [];
    warnings(1) = 0; % return var indicating that the noBin suggestions included one or more beyond TOLERANCE
    warnings(2) = 0; % return var indicating that a noBin suggestion beyond TOLERANCE was picked, and it was lowered to TOLERANCE
    warnings(3) = 0; % return var indicating that a higher intensity than the noBin suggestion one has never been applied
    if ~isempty(noBin) % then we have bins with no data points
        % determine the bin we want to try and fill up next
        % HERE IS WHERE SOME CRUCIAL SAFETY FEATURES ARE LOCATED in order not to BURN people

        if strcmp(linOrSig,'lin')
            noBinInts = regs.beta(1)+regs.beta(2)*noBin;
        elseif strcmp(linOrSig,'sig')
            for b = 1:numel(noBin)
                noBinInts(b) = sigreverse([regs.beta 0 100],noBin(b));
            end
        end
        if any(noBinInts>TOLERANCE)
            if verbosity
                cprintf([1 0 0],'Possibility that dangerous stimulus intensities will be suggested.\n');
            end
            warnings(1) = 1;
        end

        % select the less sampled half of the range first
        if any(noBin<mean(bins)) % if it is the lower half, pick random bin
            s = randperm(numel(noBin(noBin<mean(bins))));
            selBin = noBin(s(end));
            nextStim = noBinInts(s(end));
        else % if it is the upper half, pick the bin closest to the mean (avoiding high intensities until the last possible moment, to increase reliability of the estimate)
            s = find(noBin>=mean(bins),1,'first'); 
            selBin = noBin(s);
            nextStim = noBinInts(s);
        end

        if nextStim>TOLERANCE
            warning('Lowered dangerous stimulus intensity from %1.1f kPa to %1.1f kPa.',nextStim,TOLERANCE);
            nextStim = TOLERANCE;
            warnings(2) = 1;
        end
        if ~any(x>=nextStim)
            if verbosity
                cprintf([1 0 0],'The suggested stimulus intensity %1.1f kPa will be the highest the subject ever received!\n',nextStim);
            end
            warnings(3) = 1;
        end

        if showFig && ~isempty(selBin)
            if isempty(dispSuggText)
                scatter(nextStim,selBin,150,'*','LineWidth',1.5,'MarkerEdgeColor',[0 0 0]);
            else
                scatter(nextStim,selBin,10,[0 0 0],'o','filled')
                text(nextStim,selBin,dispSuggText,'FontSize',12,'FontWeight','bold')
            end
        end
        fprintf('Suggested next stimulus %1.1f kPa.\n',nextStim);        
    else
        fprintf('All bins covered! No more suggestions.\n'); 
    end

    if confirm
        [nextStim,warnings] = ConfirmNextStim(x,y,regs,nextStim,selBin,warnings);
    end
    
    if nargout==2
        varargout{1} = warnings;
    elseif nargout==3
        varargout{1} = warnings;
        varargout{2} = GetSecs-sStart; % duration of execution, including confirmation
    elseif nargout==4
        varargout{1} = warnings;
        varargout{2} = GetSecs-sStart; % duration of execution, including confirmation        
        varargout{3} = selBin; % target VAS
    end
    
    
function [inBin,remBin] = RemoveOutliers(params,regs,inBin,x,y,showFig)

    distV = regs.(sprintf('%s',params{1})); % distance vector
    thresh = params{2}; % sds tolerance for distance-based exclusion
    
    mDist = mean(abs(distV));
    sdDist = std(abs(distV));
    
    remBin = 0;
    for b = 1:numel(inBin)
        bb = b-remBin; 
        if abs(distV(inBin(bb)))>(mDist+thresh*sdDist)
            cprintf([1 0 0],sprintf('Flagging %d as outlier, %1.2f>%1.2f+%1.2f!\n',inBin(bb),abs(distV(inBin(bb))),mDist,sdDist));
            if showFig
                scatter(x(inBin(bb)),y(inBin(bb)),150,'x','LineWidth',1,'MarkerEdgeColor',[0 0 0])            
            end
            inBin(bb) = []; % remove data point for now
            remBin = remBin+1;
        end
    end
    
    
function [nextStim,warnings] = ConfirmNextStim(x,y,regs,oldNextStim,selBin,warnings,varargin)

    [maxInt,ti] = max(x);
    [maxRat,tr] = max(y);
    
    if nargin==7       
        modified = varargin{1};
        modNextStim = oldNextStim+modified;
        modStr = sprintf('(modified by %+1.1f from %1.1f kPa)',modified,oldNextStim);
    else
        modNextStim = oldNextStim;
        modified = 0;
        modStr = '';
    end
    
    if isempty(modNextStim)
        nextStim = modNextStim;
        return;
    end
    
    fprintf('\n==============================\nINPUT REQUIRED\n==============================\n');
    fprintf('Highest intensity so far:\t%1.2f (%d VAS)\n',maxInt,y(ti));
    fprintf('Highest rating so far:\t\t%d VAS (%1.2f)\n',maxRat,x(tr));
    fprintf('\n');
    fprintf('The suggested stimulus is\t%1.2f%s (~~%d VAS), which\n',modNextStim,modStr,selBin);

    if modified==0
        modStr = '';
    elseif modified>0
        modStr = '+x';
    elseif modified<0
        modStr = '-x';
    end
    if modNextStim<=maxInt && selBin<=maxRat
        fprintf('\t- is within the range of previous stimuli\n');
    elseif modNextStim<=maxInt
        fprintf('\t- is within the range of previous stimuli\n');
        cprintf([1 0 0],'\t- aims %d%s VAS higher than all others\n',selBin-maxRat,modStr);
    elseif selBin<=maxRat
        cprintf([1 0 0],'\t- is %1.2f units higher than all others\n',modNextStim-maxInt);
        fprintf('\t- aims within the rating range of previous stimuli\n')
    else % then both target intensity as well as target rating are higher than all others
        cprintf([1 0 0],'\t- is %1.2f units higher than all others\n',modNextStim-maxInt);
        cprintf([1 0 0],'\t- aims %d%s VAS higher than all others\n',selBin-maxRat,modStr);
    end
    
    % some more diagnostics to help the decision
    yHat = localsigfun(regs.beta,x);
    resids = y-yHat;
    
    if mean(abs(resids))>20
        descr{1} = 'an';
        descr{2} = 'unreliable';
    elseif mean(abs(resids))>10 % threshold informed by previous studies
        descr{1} = 'an';
        descr{2} = 'average';
    elseif mean(abs(resids))>5
        descr{1} = 'a';
        descr{2} = 'decent';
    else
        descr{1} = 'a';
        descr{2} = 'very reliable';
    end
    fprintf('\nSubject is %s %s rater (mean(abs(resids))==%1.1f VAS).\n',descr{1},upper(descr{2}),mean(abs(resids)))
    fprintf('\n');    

    KbName('UnifyKeyNames');
    keyList = KbName('KeyNames');    
    keyCont = KbName('Return');
    keyExit = KbName('Escape');
    keyDecr = KbName('LeftArrow');
    keyIncr = KbName('RightArrow');
    fprintf('Press [%s] to continue, [%s] to abort, [%s] for -5 kPa, [%s] for 5 kPa.\n',upper(char(keyList(keyCont))),upper(char(keyList(keyExit))),upper(char(keyList(keyDecr))),upper(char(keyList(keyIncr))));
    commandwindow;
    
    recurse = 0;
        
    while 1        
        [keyIsDown, ~, keyCode] = KbCheck();        
        if keyIsDown
            if find(keyCode) == keyCont                 
                break;
            elseif find(keyCode) == keyExit
                modNextStim = [];
                break;                
            elseif find(keyCode) == keyDecr
                recurse = 1;
                modified = modified-5;
                break;
            elseif find(keyCode) == keyIncr
                recurse = 1;
                modified = modified+5;
                break;
            end
        end        
    end

    if recurse
        WaitSecs(0.2); % wait for sticky fingers
        [modNextStim,warnings] = ConfirmNextStim(x,y,regs,oldNextStim,selBin,warnings,modified);
    end

    nextStim = modNextStim;
        
        
function yhat = localsigfun(b0,x) % via FitData (Stephan Geuter?)
    a = b0(1);
    b = b0(2);
    L = 0; % b0(3);
    U = 100; % b0(4);
    v = 0.5;

    yhat = (L + ((U-L) ./ (1+v.*exp(-b.*(x-a))).^(1/v)));

        
function xsigpred = sigreverse(bsig1,ytarget) % via FitData (Stephan Geuter?)

    v=.5; 
    a1 = bsig1(1); 
    b1 = bsig1(2); 
    L1 = bsig1(3); 
    U1 = bsig1(4);
    xsigpred = a1 + 1/-b1 * log((((U1-L1)/(ytarget-L1))^v-1)./v);
    