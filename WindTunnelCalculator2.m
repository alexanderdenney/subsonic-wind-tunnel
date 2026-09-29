clearvars; clc; close all; format long;
% -------------------------------------------------------------------------
% @file WindTunnelCalculator2.m 
% @author Alexander Denney
% @version 3.2
% @date 8/18/2026
%
% Optimizes geometry and calculates performance of an open-return wind
% tunnel with a square cross section.
%
%% Additional Notes:
%
% While the constructed wind tunnel does not have a honeycomb section (cost
% & time compromise), I have kept the inclusion of its  loss coefficient on
% this script to be consistent with what the geometry of the built wind tunnel
% was based on. Setting K_honeycombs = 0 seems to increase the test section
% velocity by a mere 0.03 m/s.
% 
% Different fan models were inputted to predict which one would be ideal for
% minimizing cost and maximizing performance (Re).
% -------------------------------------------------------------------------

%% Sweeping Different fan types
fans = struct;

fans(1).fanName = "Vevor BT-SHT12A"; % Power: 560W
fans(1).P_max = 385; % estimate based on other Vevor fan models
fans(1).Q_max = 2894 * 1.699; % m^3/hr, which is 2894 CFM
fans(1).diameter = 12 * 0.0254; % m

for i = 1:length(fans)
    fprintf("Fan #%d\n", i);
    fans(i).A_fan = pi * (fans(i).diameter/2)^2;
    fans(i).flowRate = linspace(0,fans(i).Q_max,20); % m^3/h | x-axis standard:  @(Q) P_max * (1-(Q/Q_max)^2);
    fans(i).deltaP = fans(i).P_max .* (1-(fans(i).flowRate ./ fans(i).Q_max).^2); % Pa | y-axis (a general fan curve)
    % this general fan curve is used since most consumer fan manufacturers
    % dont post lab-tested fan curves
    sweepGeometry1(fans(i));
end

% -------------------------------------------------------------------------

function sweepGeometry1(fanData)
    %% Wind Tunnel Input Geometry: (units: SI) - square geometry assumed
    geometry = struct;

    geometry.theta_diffuser = 4.5; % degrees | [3,6]
    geometry.C_r = 8.6; % contraction ratio
    geometry.D_intake = 0.2; % m | (square ==> "D" is sidelength, not diameter here)  -- influential
    geometry.C_testvolume = 1.5; % [1.5,3] -- l = C * D
    geometry.C_contractioncone = 0.75; % [0.75, 1.25] -- l = C * D
    geometry.numScreens = 2;
    geometry.frictionFactor = 0.02; % ~ for XPS foam / acrylic

    airfoilParameters = struct;
    airfoilParameters.blockageRatio = 0.05;
    airfoilParameters.airfoilThicknessRatio = 0.12;

    %% Sweep & Constraints:
    D_intake_sweep = linspace(0.1, 1, 50); % m -- I think a meter is my max willing size
    C_r_sweep = linspace(3, 9, 50);
    MINIMUM_LENGTH_TEST_SECTION = 0.1; % m
    MINIMUM_DIAM_TEST_VOLUME = 0.25; % m
    
    bestGeometry = struct; % preallocate

    bestRe = 0;
    for D_intake_sweep_value = D_intake_sweep
        geometry.D_intake = D_intake_sweep_value;
        for C_r_sweep_value = C_r_sweep
            geometry.C_r = C_r_sweep_value;
            [operatingPoint, output_geometry] = maxReynolds(geometry, fanData, airfoilParameters, false);
            if operatingPoint.Re > bestRe && output_geometry.L_testvolume >= MINIMUM_LENGTH_TEST_SECTION && output_geometry.D_testvolume >= MINIMUM_DIAM_TEST_VOLUME
                bestRe = operatingPoint.Re; % Update best Reynolds number
                bestGeometry = output_geometry; % Store the best geometry configuration
            end
        end
    end

    [operatingPoint, output_geometry] = maxReynolds(bestGeometry, fanData, airfoilParameters, true);
    fprintf('\nBest Operating Point Found:\nFlow Rate = %.2f m^3/h\nPressure = %.2f Pa\nRe = %.0f\nTest Section Velocity = %.2f m/s\n', operatingPoint.Q, operatingPoint.P,operatingPoint.Re,operatingPoint.V);
    
    bestGeometry
end

function [operatingPoint, output_geometry] = maxReynolds(geometry, fanData, airfoilParameters, doPlot)
SWEEP_TO_MPS = 30; % m/s

% Constants
rho = 1.225; % kg/m^3 -- density air (standard)
nu = 1.48e-5; % m^2/s -- kinematic viscosity (standard)
K_e = 0.15; % EMPIRICAL expansion coefficient -- for 4.5 deg half angle 
% good margin ^ ? (no citation) 
% 𝐾𝑒(𝜃) = −0.09661 + 0.046728� (page 29, equation 7, Jason Fink Spring
% 2021) -- which yields a lower value

operatingPoint = struct;
output_geometry = geometry;

C_r = geometry.C_r;
D_intake = geometry.D_intake;
A_fan = fanData.A_fan;
C_testvolume = geometry.C_testvolume;
C_contractioncone = geometry.C_contractioncone;
numScreens = geometry.numScreens;
frictionFactor = geometry.frictionFactor;
theta_diffuser = geometry.theta_diffuser;

%% Dependent/Further-Calculated Geometry:
A_intake = D_intake^2; % m^2
A_testvolume = A_intake/C_r; % m^2
D_testvolume = sqrt(A_testvolume); % m | (square ==> sidelength)
L_contractioncone = C_contractioncone * D_intake; % m | [0.75, 1.25]
L_testvolume = C_testvolume * D_testvolume; % m | [1.5, 3]

% For a general test article (airfoil in this case)
blockageRatio = airfoilParameters.blockageRatio;
airfoilThicknessRatio = airfoilParameters.airfoilThicknessRatio; % NACA 0012, is standard
wing_span = D_testvolume; % wall-to-wall span
L_chord = (blockageRatio * A_testvolume) / (wing_span * airfoilThicknessRatio); % m

%% Calculate Losses
K_hc_local = 0.50; % hexagonal honeycombs ("typical") -- (Cite: Low Speed Wind Tunnel Testing, Barlow)
K_honeycombs = K_hc_local * (1/C_r)^2;

K_screen_local = 1.0; % number inferred in (Barlow)
K_screens = numScreens * K_screen_local * (1/C_r)^2;

K_contractioncone = 0.05;
% citation: Barlow, J. B., Rae, W. H., & Pope, A. (1999). Low-Speed Wind Tunnel Testing (3rd ed.). John Wiley & Sons

K_testvolume = frictionFactor * L_testvolume/D_testvolume; % based on standard pipe friction
K_diffuser = K_e * (1-A_testvolume/A_fan)^2;

C_D = 0.12; % ~ subsonic airfoil near stall
A_ref = wing_span * L_chord;
K_testarticle = C_D * A_ref / A_testvolume; % object being tested (blockage)

K_exit = 1.0 * (A_testvolume / A_fan)^2; % open circuit, exhausting into room

% Must be scaled by dynamic pressure:
K_total = K_honeycombs + K_screens + K_contractioncone + K_testvolume + K_diffuser + K_testarticle + K_exit;

% delta P function definition:
P_total = @(V_test) K_total * 0.5 * rho * V_test.^2; % Pa

% interpolating fan data:
xq = linspace(min(fanData.flowRate), max(fanData.flowRate), 100);
yq = interp1(fanData.flowRate, fanData.deltaP, xq, 'spline');

V_test = linspace(0,SWEEP_TO_MPS,100);

Re_vector = V_test * L_chord / nu;
plot_P_total = P_total(V_test);
Q_m3_h = V_test .* A_testvolume * 3600;

diff_func = @(Q) interp1(fanData.flowRate, fanData.deltaP, Q, 'spline') ... 
               - P_total(Q / (A_testvolume * 3600));

Q_guess = 500; 
Q_intersect = fzero(diff_func, Q_guess); % incompressible: Q_test = Q_diffuser = Q_fan (volumetric flow rates constant)
P_intersect = interp1(fanData.flowRate, fanData.deltaP, Q_intersect, 'spline');
Re_intersect = interp1(Q_m3_h, Re_vector, Q_intersect);
V_intersect = Q_intersect / (A_testvolume * 3600);

% Output ideal operating point:
operatingPoint.Q = Q_intersect;
operatingPoint.P = P_intersect;
operatingPoint.Re = Re_intersect;
operatingPoint.V = V_intersect;

% Calculating Length of diffuser (trigonometric derivation)
L_diffuser = (fanData.diameter - D_testvolume) / (2 * tand(theta_diffuser));

% Calculating the length of the adapter loft from square to circle cross section that
% occurs at the end of the tunnel, for mating to the fan
theta_fanAdapter = 45;
L_square_to_circ_loft = ((fanData.diameter * sqrt(2)) / 2 - fanData.diameter / 2) / tand(theta_fanAdapter);
% Notes: negligible loss, diffuser as wide as fan at exit

output_geometry.L_diffuser = L_diffuser;
output_geometry.L_contractioncone = L_contractioncone;
output_geometry.A_testvolume = A_testvolume;
output_geometry.A_intake = A_intake;
output_geometry.D_testvolume = D_testvolume;
output_geometry.L_testvolume = L_testvolume;
output_geometry.L_square_to_circ_loft = L_square_to_circ_loft;

% Plotting Flow Rate:
if doPlot
    figure('Name', 'Pressure vs Volumetric Flow Rate (Q)', 'Color', 'w');
    
    yyaxis left;
    hold on
    
    plot(Q_m3_h, plot_P_total, '-', 'LineWidth', 2, 'Color', '#ef8a62');
    ylabel('Required Total Pressure Drop (Pa)');
    
    plot(xq, yq, '--', 'LineWidth',1, 'Color', '#ef8a62');
    
    plot(Q_intersect, P_intersect, 'k.', 'MarkerSize', 25, 'DisplayName', 'Operating Point');
    label_str = sprintf('  Re = %.0f\n  v_{test} = %.2f m/s', Re_intersect, V_intersect);
    text(Q_intersect, P_intersect, label_str, ...
        'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');
    
    hold off
    
    set(gca,'YColor','#ef8a62');
    
    yyaxis right;
    plot(Q_m3_h, Re_vector, '-', 'LineWidth', 2, 'Color','#67a9cf');
    ylabel(sprintf('Reynolds Number (Based on %.2f m chord)', L_chord));
    set(gca, 'YColor', '#67a9cf');
    
    grid on;
    title('System Resistance and Achievable Reynolds Number');
    subtitle(sprintf('C_r = %.2f    D_{intake} = %.2f m   D_{test} = %.2f m   Area_{fan} = %.2f m^2    L_{test volume} = %.2f m', C_r, D_intake, D_testvolume, A_fan, L_testvolume));

    xlabel('Volumetric Flow Rate (m^3/h)');
    fanLabel = append(fanData.fanName, ' Fan Pressure Drop');
    legend('System Pressure Drop', fanLabel,'Operating Point','Reynolds Number','Location', 'northwest');

    disableDefaultInteractivity(gca); % toolbar visibility warning
    exportgraphics(gcf, 'WindTunnelTheoreticalPlot.png', 'Resolution', 300);
end

end