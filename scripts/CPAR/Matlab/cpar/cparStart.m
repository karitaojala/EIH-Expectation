function cparStart(dev, condition, forced)
% cparStart
%   cparStart(dev, condition, forced) start a stimulation with stop condition
%   [condition] and forced start [forced].
%
%   The stop condition determines what will terminate the stimulation, and has 
%   two possible values:
%
%     'v': VAS Mode, the stimulation will stop when either the VAS rating reaches 
%          10cm or if the subject presses the button.
%     'b': Button Mode, the stimulation will only stop if subject presses the 
%          button. Consequently, it will continue even if the VAS rating reaches
%          10cm.
%
%   The forced start determines whether or not to enforce that the VAS rating 
%   should be set to zero before a stimulation is started. If [forced] is false
%   it will not be possible to start a stimulation unless the VAS rating has been
%   set to zero, if it is true the stimulation can be started regardless of the 
%   value of the VAS rating.
%
%   The stop condition can after the stimulation in be examined in [dev].
%
%   See also, cparStop
if strcmp(condition, 'v')
    stop = LabBench.Interface.AlgometerStopCriterion.STOP_CRITERION_ON_BUTTON_VAS;
elseif (strcmp(condition, 'b'))
    stop = LabBench.Interface.AlgometerStopCriterion.STOP_CRITERION_ON_BUTTON;        
else
   error('Invalid stop condition, valid values are v or b'); 
end
        
dev.Start(stop, forced)
