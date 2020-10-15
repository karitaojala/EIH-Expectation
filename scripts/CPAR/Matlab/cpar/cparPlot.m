function cparPlot(data)
% cparPlot Plot data from the CPAR device.
%   cparPlot(data)

clf;
set(gcf, 'Color', [1 1 1]);

subplot(3,1,1);
plot(data.t, data.p01, 'r-',...
     data.t, data.t01, 'b-'); 
ylabel('Pressure [kPa]');
title('Pressure (1)');
set(gca,'TickDir', 'out');
set(gca,'Box', 'off');
legend('Actual', 'Target');

subplot(3,1,2);
plot(data.t, data.p02, 'r-',...
     data.t, data.t02, 'b-'); 
ylabel('Pressure [kPa]');
title('Pressure (2)');
set(gca,'TickDir', 'out');
set(gca,'Box', 'off');
legend('Actual', 'Target');

subplot(3,1,3);
plot(data.t, data.vas, 'k');
xlabel('Time [s]'); 
ylabel('VAS [cm]');
title('Visual Analog Rating');
set(gca,'TickDir', 'out');
set(gca,'Box', 'off');
