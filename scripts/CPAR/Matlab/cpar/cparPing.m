function cparPing(dev, enable)
% cparPing Ping a CPAR device.
%   cparPing(dev, enable)

if enable
    try    
        kicks = dev.Ping();
        dev.PingEnabled = true;
        fprintf('Ping: %d\n', kicks);
    catch
       fprintf('Ping failed\n'); 
    end
else
   dev.PingEnabled = false; 
end