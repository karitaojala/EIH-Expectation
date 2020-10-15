function [data] = cparGetData(dev)
    % cparGetData Get the data from a CPAR device.
    %    [data] = cparGetData(dev) retrieve the current collected data
    %    from the CPAR device.

    ratings = dev.Rating;
    data.vas = zeros(1, ratings.Count);
    data.t = zeros(1, ratings.Count);
    t = 0.0;
    
    for n = 1:ratings.Count
       data.vas(n) = ratings.Item(n - 1); 
       data.t(n) = t;
       t = t + (1/20.0);
    end
    
    [data.p01, data.t01, data.p01final] = GetPressure(dev.Channels.Item(0));
    [data.p02, data.t02, data.p02final] = GetPressure(dev.Channels.Item(1));
end

function [p, t, final] = GetPressure(ch)
    actual = ch.Pressure;
    target = ch.TargetPressure;
    p = zeros(1, actual.Count);
    t = zeros(1, actual.Count);
    final = ch.FinalPressure;
    
    for n = 1:actual.Count
       p(n) = actual.Item(n - 1); 
       t(n) = target.Item(n - 1);
    end
end