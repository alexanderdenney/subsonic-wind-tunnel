clc; clearvars; close all;
% -------------------------------------------------------------------------
% @file WindTunnelVelocityPlotting.m
% @author Alexander Denney
% @version 1.2
% @date 9/21/2026
% 
% Reads the downloaded serial output from the Arduino Uno R3 (.txt format),
% and plots the airspeed over time. I selected a time interval where the
% tunnel appears to be fully spooled up. Across this interval I calculate
% the mean which is compared with my theoretical airspeed from
% WindTunnelCalculator2.m
%
% -------------------------------------------------------------------------

SECONDS_BETWEEN_EACH_SERIAL_PRINT = 0.02; % seconds (assumes perfect 50Hz, actual was likely bottlenecked by 9600 baud)

% The time range after the fan is fully ramped up and before it is turned
% off
START_MEAN = 5.58; % seconds
END_MEAN = 21.58;
THEORETICAL_TEST_VELOCITY = 16.81; % m/s

filename = 'trimmedTestData.txt'; 
fileID = fopen(filename, 'r');
dataCell = textscan(fileID, 'Pressure(Pa):%f Velocity(m/s):%f');
fclose(fileID);

pressure = dataCell{1};
velocity = dataCell{2};

timeStamp = (0:numel(pressure)-1) * SECONDS_BETWEEN_EACH_SERIAL_PRINT;

%% Statistics
validIdx = (timeStamp >= START_MEAN) & (timeStamp <= END_MEAN);
meanPressureInRange = mean(pressure(validIdx));
meanVelocityInRange = mean(velocity(validIdx));

percentError_v = abs((meanVelocityInRange - THEORETICAL_TEST_VELOCITY) / THEORETICAL_TEST_VELOCITY) * 100;

fprintf('Mean Velocity: %.2f m/s\n', meanVelocityInRange);
fprintf('Mean Pressure: %.2f Pa\n', meanPressureInRange);
fprintf('Theoretical Velocity: %.2f m/s\n', THEORETICAL_TEST_VELOCITY);
fprintf('Velocity Percent Error: %.2f%%\n', percentError_v);


%% Plotting
figure('Name', 'Pressure and Velocity vs Time')
title('Pressure and Velocity vs Time')

subtitle(sprintf('v_{mean} = %.2f m/s, p_{mean} = %.2f Pa, t_{sample} = [%.2f, %.2f] s\nv_{theoretical} = %.2f m/s, Error_v = %.2f%%', meanVelocityInRange, meanPressureInRange, START_MEAN, END_MEAN, THEORETICAL_TEST_VELOCITY, percentError_v));

hold on
grid on

yyaxis right;

yticks(0:10:150)
pPlot = plot(timeStamp, pressure, 'Color', '#af8dc3', 'LineWidth', 1);
ylabel("Pressure (Pa)");
hold off

set(gca,'YColor','#af8dc3');

yyaxis left;

vPlot = plot(timeStamp, velocity, 'Color', '#7fbf7b', 'LineWidth', 1);
set(gca,'YColor','#7fbf7b');
yticks(0:1:17)

ylabel("Velocity (m/s)")
xlabel("Time (s)")

hold on;

meanRangePlot = xline([START_MEAN, END_MEAN], '--r');

tv_Plot = yline(THEORETICAL_TEST_VELOCITY, '--','LineWidth',1.5, 'Color','#7fbf7b'); % display theoretical velocity

legend([vPlot, pPlot, tv_Plot, meanRangePlot(1)], {'Experimental Velocity', 'Experimental Pressure', 'Theoretical Velocity', 'Sampling Window'}, 'Location', 'northwestoutside');

disableDefaultInteractivity(gca); % toolbar visibility warning
exportgraphics(gcf, 'WindTunnel_Test3_9-20-2026.png', 'Resolution', 300);