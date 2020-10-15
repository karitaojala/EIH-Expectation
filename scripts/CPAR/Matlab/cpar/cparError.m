function [err] = cparError(dev)
% cparError Retrive error information 
%   [err] = cparError(dev) get the error string currently
%   set in the CPAR device. If it is empty it means no error
%   has occured in the device.
err = dev.Error;