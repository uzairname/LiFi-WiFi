% --- initializeEnvironment_Advanced.m ---
% Initialize an 18x18x3m workspace with 36 LiFi attocells and WiFi coverage
% This function supports the Advanced Proposed Algorithm with enhanced workspace modeling

function [apList, apParams] = initializeEnvironment_Advanced(simParams)
    % This function creates the list of all APs for the advanced workspace setup
    % - 36 LiFi attocells in a 6x6 grid (18x18m area)
    % - 4 WiFi APs for comprehensive coverage
    % - 3m ceiling height for full 3D coverage modeling
    
    %% --- LiFi APs (36 Attocells) ---
    % Create a 6x6 grid of LiFi attocells over the 18x18m workspace
    % Spacing: 18/6 = 3m between LiFi APs
    apParams.numLiFi = 36;
    apParams.freqReuseFactorLiFi = 4;  % Frequency reuse factor for interference management
    
    % Generate 6x6 grid positions
    sep = 3.0;  % 3m separation (18m / 6 = 3m)
    lifi_x = linspace(sep/2, simParams.roomSize(1) - sep/2, 6);
    lifi_y = linspace(sep/2, simParams.roomSize(2) - sep/2, 6);
    [X, Y] = meshgrid(lifi_x, lifi_y);
    lifi_pos = [X(:), Y(:)];
    
    % Add z-coordinate (height = 3m for all LiFi APs, assume ceiling-mounted)
    lifi_pos = [lifi_pos, 3.0 * ones(36, 1)];
    
    % Assign frequency channels in a pattern for frequency reuse factor 4
    % Pattern: [0 1 0 1 ...; 2 3 2 3 ...; ...]
    freq_pattern = [0 1 0 1 0 1;
                    2 3 2 3 2 3;
                    0 1 0 1 0 1;
                    2 3 2 3 2 3;
                    0 1 0 1 0 1;
                    2 3 2 3 2 3];
    lifi_freq_channels = freq_pattern(:);  % Flatten to 36x1 vector
    
    %% --- WiFi APs ---
    % 4 WiFi APs deployed at the corners/edges for comprehensive coverage
    apParams.numWiFi = 4;
    
    % Deploy WiFi APs strategically (one in each quadrant at 1.5m height)
    wifi_pos = [
        1.5,  1.5,  1.5;
        16.5, 1.5,  1.5;
        1.5,  16.5, 1.5;
        16.5, 16.5, 1.5
    ];
    
    %% --- Create apList struct array ---
    numAPs = apParams.numLiFi + apParams.numWiFi;
    apList(numAPs, 1) = struct('pos', [], 'type', '', 'tx_power', 0, 'noise_psd', 0, ...
                               'freq_channel', 0, 'bandwidth', 0, 'fov', 0);
    
    %% --- LiFi AP Parameters ---
    for i = 1:apParams.numLiFi
        apList(i).pos = lifi_pos(i, :);  % [x, y, z] coordinates
        apList(i).type = 'LiFi';
        apList(i).tx_power = 3;           % 3W optical power
        apList(i).noise_psd = 1e-21;      % A^2/Hz (shot noise + thermal noise)
        apList(i).freq_channel = lifi_freq_channels(i);
        apList(i).bandwidth = 20e6;       % 20 MHz bandwidth per LiFi AP
        apList(i).fov = 60;               % Field of view in degrees
        
        % Attocell coverage range (LiFi typically ~7-10m at moderate intensity)
        apList(i).coverage_radius = 2.5;  % 2.5m coverage radius for attocell
    end
    
    %% --- WiFi AP Parameters ---
    for i = 1:apParams.numWiFi
        idx = apParams.numLiFi + i;
        apList(idx).pos = wifi_pos(i, :);  % [x, y, z] coordinates
        apList(idx).type = 'WiFi';
        apList(idx).tx_power = 20;         % 20 dBm transmit power
        apList(idx).noise_psd = -174;      % dBm/Hz (thermal noise)
        apList(idx).freq_channel = 0;      % All WiFi on same channel (simplified)
        apList(idx).bandwidth = 80e6;      % 80 MHz WiFi bandwidth
        apList(idx).fov = 360;             % Omni-directional coverage
        apList(idx).coverage_radius = 15;  % 15m coverage radius for WiFi
    end
end
