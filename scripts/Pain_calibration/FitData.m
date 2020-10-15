% modified by bh 2019-05-29
% added est_lin as argout
% revamped everything for varargout
% etc etc full restructuring, what's with the t.tmp.etc?
% varargin{1} is verbosity suppression, with 0 = all output, 1 = figures only, 2 = text only, 3 = no output (except argout)
% varargin{2} and {3} are figure handles used to plot multiple lin/sig fits (e.g. for whole sample visualization)

function [varargout] = FitData(x,y,target_vas,varargin) 

% transpose if necessary
if size(x,2)>1
    x = x';
end
if size(y,2)>1
    y = y';
end

% instantiate output vars
est_lin = [];
est_rob = [];
est_sig = [];
blin = [];
brob = [];
bsig = [];

nTrials = numel(x); 
trial = [1:numel(x)]'; 
x(isnan(y))=[]; 
trial(isnan(y))=[]; 
y(isnan(y))=[]; 

% estimate linear function
blin = [ones(numel(x),1) x]\y;
for vas = 1:size(target_vas,2)
    est_lin(vas) = linreverse(blin,target_vas(vas));
end

% estimate robust linear function
[brob,statsrob] = robustfit(x,y);
for vas = 1:size(target_vas,2)
    est_rob(vas) = linreverse(brob,target_vas(vas));
end

% estimate sigmoid function
a = mean(x); b = 1; % L = 0; U = 100; % l/u bounds to be fitted
beta0 = [a b];
% options = statset('Display','final','Robust','on','MaxIter',10000);
options = statset('Display','off','Robust','on','MaxIter',10000); % bh
[bsig,~] = nlinfit(x,y,@localsigfun,beta0,options);

for vas = 1:size(target_vas,2)
    est_sig(vas) = sigreverse([bsig -1 101],target_vas(vas));
end

% plot
xplot = 40:.1:50;
   
if nargin>3 && varargin{1}>1 % bh
    % suppress figure output
elseif nargin>4 % bh
    figure(varargin{2}); % linear prediction
    plot(xplot,blin(1)+xplot.*blin(2),'k');
    xlim([min(xplot)-.5 max(xplot)+.5]); ylim([0 100]);
    hold on;
    
    figure(varargin{3}); % sigmoid prediction
    plot(xplot,localsigfun(bsig,xplot),'k');
    xlim([min(xplot)-.5 max(xplot)+.5]); ylim([0 100]);    
    hold on;
    
    if nargin>6 % robust prediction
        figure(varargin{5});
        plot(xplot,brob(1)+xplot.*brob(2),'k');
        xlim([min(xplot)-.5 max(xplot)+.5]); ylim([0 100]);
        hold on;   
    end
else % orig
    plot(x,y,'kx');
    xlim([min(xplot)-.5 max(xplot)+.5]); ylim([0 100]);

    plot(x,y,'kx',xplot,localsigfun(bsig,xplot),'r',...
        est_sig,localsigfun(bsig,est_sig),'ro',est_lin,target_vas,'kd',...
        xplot,blin(1)+xplot.*blin(2),'k--');
    xlim([min(xplot)-.5 max(xplot)+.5]); ylim([0 100]);
end   

% calculate residuals for linear function and  sigmoid function
res_lin_sum = 0;
res_rob_sum = 0;
res_sig_sum = 0;
for nTrial = 1:nTrials
    est_lin_ind = linreverse(blin,y(nTrial));
    res_lin_ind = abs(est_lin_ind - x(nTrial));
    res_lin_sum = res_lin_sum + res_lin_ind;
    
    est_rob_ind = linreverse(brob,y(nTrial));
    res_rob_ind = abs(est_rob_ind - x(nTrial));
    res_rob_sum = res_rob_sum + res_rob_ind;
    
    est_sig_ind = sigreverse([bsig -1 101],y(nTrial));
    res_sig_ind = abs(est_sig_ind - x(nTrial));
    res_sig_sum = res_sig_sum + res_sig_ind;
end

% display
if nargin>3 && ( varargin{1}==0 || varargin{1}==2 ) % bh
    results1 = [trial x y];
    results = sortrows(results1,2);
    disp(results);

    fprintf('Estimates from  fit (n=%d)\n',nTrials);
    for vas = 1:size(target_vas,2)
        fprintf('%d : \tsigmoid: %1.3f kPa\tlinear: %1.3f kPa\trobust: %1.3f kPa\n',target_vas(vas),est_sig(vas),est_lin(vas),est_rob(vas));
    end
    fprintf('\n');
    fprintf('Residual sum of sigmoid fit : %2.1f\n',res_sig_sum);
    fprintf('Residual sum of linear fit  : %2.1f\n',res_lin_sum);
    fprintf('Residual sum of robust fit  : %2.1f\n',res_rob_sum);

    % Check - was the whole scale used?
    fprintf('\nCheck for minimal and maximal rating:\n');
    fprintf('Minimal rating: %d, Pressure: %3.1f \n', min(y), x(y == min(y)));
    fprintf('Maximal rating: %d, Presure: %3.1f \n', max(y), x(y == max(y)));
    fprintf('Rating range(max-min rating): %d\n', max(y)-min(y));
end

if nargout==1
    varargout{1} = est_lin;
elseif nargout==2
    varargout{1} = est_lin;
    varargout{2} = est_sig;    
elseif nargout==3
    varargout{1} = est_lin;
    varargout{2} = est_sig;
    varargout{3} = est_rob;
elseif nargout==6
    varargout{1} = est_lin;
    varargout{2} = est_sig;
    varargout{3} = est_rob;
    varargout{4} = blin;
    varargout{5} = bsig';
    varargout{6} = brob;
end

%% estimate sigmoid fit
function xsigpred = sigreverse(bsig1,ytarget)
    v=.5; 
    a1 = bsig1(1); 
    b1 = bsig1(2); 
    L1 = bsig1(3); 
    U1 = bsig1(4);
    xsigpred = a1 + 1/-b1 * log((((U1-L1)/(ytarget-L1))^v-1)./v);

%% estimate linear fit
function xlinpred = linreverse(blin1,ytarget)
    a1 = blin1(1); 
    b1 = blin1(2);
    xlinpred = (ytarget - a1) / b1;
    
%%
function yhat = localsigfun(b0,x)    
    a = b0(1);
    b = b0(2);
    L = 0;%b0(3);
    U = 100;%b0(4);
    v = 0.5;

    yhat = (L + ((U-L) ./ (1+v.*exp(-b.*(x-a))).^(1/v)));
