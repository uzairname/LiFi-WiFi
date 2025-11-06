% --- calculateSINR.m ---
function all_sinr_dB = calculateSINR(userPos, apList, apParams)
    % Calculates the SINR from *all* APs to the user.
    % This is the most complex function to implement.
    
    numAPs = length(apList);
    received_power_linear = zeros(1, numAPs);
    all_sinr_dB = zeros(1, numAPs);
    
    % --- Step 1: Calculate Received Power from *all* APs ---
    for i = 1:numAPs
        % NOTE: This is where you implement the channel models!
        if strcmp(apList(i).type, 'LiFi')
            % --- YOUR LIFI MODEL (Lambertian) ---
            % Pseudocode:
            % 1. Calculate distance 'd' (incl. 3m height)
            % 2. Calculate angles (phi, psi)
            % 3. Calculate H(0) (channel gain)
            % 4. P_rx = apList(i).tx_power * H(0)
            % 5. Store P_rx_linear in received_power_linear(i)
            received_power_linear(i) = 1e-9; % Placeholder
            
        elseif strcmp(apList(i).type, 'WiFi')
            % --- YOUR WIFI MODEL (Log-Distance) ---
            % Pseudocode:
            % 1. Calculate 2D distance 'd'
            % 2. Calculate Path Loss (PL_dB) using Log-Distance formula
            % 3. P_rx_dBm = apList(i).tx_power - PL_dB
            % 4. Convert P_rx_dBm to linear (mW) for SINR calculation
            received_power_linear(i) = 1e-9; % Placeholder
        end
    end
    
    % --- Step 2: Calculate SINR for *each* AP ---
    for i = 1:numAPs
        signal = received_power_linear(i);
        interference = 0;
        
        % Sum interference from other APs of the *same type*
        for j = 1:numAPs
            if i ~= j && strcmp(apList(i).type, apList(j).type)
                % Add interference (consider LiFi reuse factor here)
                interference = interference + received_power_linear(j);
            end
        end
        
        % Calculate total noise power (Noise_PSD * Bandwidth)
        % Note: You must handle units (linear vs. dB) carefully!
        noise_linear = 1e-12; % Placeholder for (Noise_PSD * 10MHz)
        
        % SINR calculation
        sinr_linear = signal / (interference + noise_linear);
        all_sinr_dB(i) = 10 * log10(sinr_linear);
    end
end