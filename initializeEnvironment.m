% --- initializeEnvironment.m ---
function [apList, apParams] = initializeEnvironment(simParams)
    % This function creates the list of all APs and their properties.
    
    % --- LiFi APs ---
    % 16 APs in a 4x4 grid [cite: 284]
    apParams.numLiFi = 16;
    sep = 2.5; % 2.5m separation [cite: 284]
    [X, Y] = meshgrid( ...
        linspace(-sep*1.5, sep*1.5, 4) + simParams.roomSize(1)/2, ...
        linspace(-sep*1.5, sep*1.5, 4) + simParams.roomSize(2)/2 ...
    );
    lifi_pos = [X(:), Y(:)];
    
    % --- WiFi APs ---
    % 4 APs, regular deployment (center of 4 quadrants) [cite: 293]
    apParams.numWiFi = 4;
    quad_size = simParams.roomSize / 2;
    wifi_pos = [ ...
        quad_size/2; ...
        [quad_size(1)*1.5, quad_size(2)/2]; ...
        [quad_size(1)/2, quad_size(2)*1.5]; ...
        quad_size*1.5 ...
    ];

    % --- Create apList struct array ---
    numAPs = apParams.numLiFi + apParams.numWiFi;
    apList(numAPs, 1) = struct('pos', [], 'type', '', 'tx_power', 0, 'noise_psd', 0);
    
    % LiFi parameters
    for i = 1:apParams.numLiFi
        apList(i).pos = lifi_pos(i, :);
        apList(i).type = 'LiFi';
        apList(i).tx_power = 3; % 3W optical power
        apList(i).noise_psd = 1e-21; % A^2/Hz
    end
    
    % WiFi parameters
    for i = 1:apParams.numWiFi
        idx = apParams.numLiFi + i;
        apList(idx).pos = wifi_pos(i, :);
        apList(idx).type = 'WiFi';
        apList(idx).tx_power = 20; % 20 dBm
        apList(idx).noise_psd = -174; % dBm/Hz
    end
end