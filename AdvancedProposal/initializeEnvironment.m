% --- initializeEnvironment.m ---
function [apList, apParams] = initializeEnvironment(simParams)
    % This function creates the list of all APs and their properties.
    
    % --- LiFi APs ---
    % 16 APs in a 4x4 grid [cite: 284]
    apParams.numLiFi = 16;
    apParams.freqReuseFactorLiFi = 4; % Frequency reuse factor [cite: 284]
    sep = 2.5; % 2.5m separation [cite: 284]
    [X, Y] = meshgrid( ...
        linspace(-sep*1.5, sep*1.5, 4) + simParams.roomSize(1)/2, ...
        linspace(-sep*1.5, sep*1.5, 4) + simParams.roomSize(2)/2 ...
    );
    lifi_pos = [X(:), Y(:)];
    
    % Assign frequency channels (0, 1, 2, 3) in a pattern for reuse factor 4
    freq_pattern = [0 1; 2 3];
    freq_assignment = repmat(freq_pattern, 2, 2);
    lifi_freq_channels = freq_assignment(:); % Flatten to 16x1 vector
    
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
        apList(i).freq_channel = lifi_freq_channels(i); % Frequency channel assignment
    end
    
    % WiFi parameters
    for i = 1:apParams.numWiFi
        idx = apParams.numLiFi + i;
        apList(idx).pos = wifi_pos(i, :);
        apList(idx).type = 'WiFi';
        apList(idx).tx_power = 20; % 20 dBm
        apList(idx).noise_psd = -174; % dBm/Hz
        apList(idx).freq_channel = 0; % WiFi APs on same channel (for simplicity)
    end
end