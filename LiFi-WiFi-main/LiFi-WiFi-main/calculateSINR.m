% --- calculateSINR.m ---
function all_sinr_dB = calculateSINR(userPos, apList, apParams)
    % Calculates the SINR from *all* APs to the user.
    
    numAPs = length(apList);
    received_power_linear = zeros(1, numAPs); % Will store I^2 for LiFi, P(W) for WiFi
    all_sinr_dB = zeros(1, numAPs);
    
    % --- Physical Constants from Paper ---
    H = 3;                  % Vertical distance to user [m] [cite: 284]
    B = 10e6;               % 10 MHz bandwidth for all APs [cite: 285]
    
    % --- LiFi-specific Parameters ---
    PD_Area = 1e-4;         % 1 cm^2 -> m^2
    PD_Responsivity = 0.53; % A/W
    FOV_deg = 60;           % Receiver Field of View
    % Lambertian order: m = -ln(2)/ln(cos(Phi_1/2))
    % Assuming LED semi-angle Phi_1/2 = 60 deg (wide angle LED)
    LED_semi_angle = 60;    % degrees
    m_l = -log(2) / log(cosd(LED_semi_angle)); % Calculated Lambertian order
    
    % --- WiFi-specific Parameters (Standard Model) ---
    d_0 = 1;                % 1m reference distance
    PL_d0 = 40;             % 40 dB path loss at 1m for 2.4 GHz
    n_exp = 3.0;            % Path loss exponent for indoor (justified substitute)

    % --- Step 1: Calculate Received Power from *all* APs ---
    for i = 1:numAPs
        apPos = apList(i).pos;
        
        if strcmp(apList(i).type, 'LiFi')
            % --- LIFI MODEL (Lambertian LOS) ---
            
            % 1. Calculate 3D distance and angle
            dist_3D = sqrt((userPos(1) - apPos(1))^2 + (userPos(2) - apPos(2))^2 + H^2);
            cos_psi = H / dist_3D; % Angle of incidence
            psi_deg = rad2deg(acos(cos_psi));
            
            % 2. Check if user is within the LiFi cone (Field of View)
            if psi_deg > FOV_deg
                H_0 = 0; % User is outside the cone, 0 gain
            else
                cos_phi = cos_psi; % AP points straight down, so phi = psi
                % 3. Calculate DC Channel Gain H(0)
                % H(0) = (m+1)*A_pd / (2*pi*d^2) * cos^m(phi) * cos(psi)
                H_0 = (m_l+1) * PD_Area / (2 * pi * dist_3D^2) * (cos_phi^m_l) * cos_psi;
            end
            
            % 4. Received Optical Power
            P_rx_optical = apList(i).tx_power * H_0; % P_tx_opt (W) * H(0)
            
            % 5. Received Electrical Signal (Photocurrent I_signal)
            I_signal = P_rx_optical * PD_Responsivity;
            
            % Store the *electrical power* (I^2)
            received_power_linear(i) = I_signal^2;
            
        elseif strcmp(apList(i).type, 'WiFi')
            % --- WIFI MODEL (Log-Distance Path Loss) ---
            
            % 1. Calculate 2D distance
            dist_2D = norm(userPos - apPos);
            if dist_2D < d_0
                dist_2D = d_0; % Avoid log(0) or gain > PL_d0
            end
            
            % 2. Calculate Path Loss (PL) in dB
            PL_dB = PL_d0 + 10 * n_exp * log10(dist_2D / d_0);
            
            % 3. Received Power in dBm
            P_tx_dBm = apList(i).tx_power;
            P_rx_dBm = P_tx_dBm - PL_dB;
            
            % 4. Convert P_rx from dBm to linear Watts for SINR
            % P_rx_W = (10^(P_rx_dBm / 10)) / 1000
            received_power_linear(i) = (10^(P_rx_dBm / 10)) / 1000;
        end
    end
    
    % --- Step 2: Calculate SINR for *each* AP ---
    
    % Calculate linear noise values
    lifi_noise_psd_A2_Hz = 1e-21; % From initializeEnvironment
    lifi_noise_linear_A2 = lifi_noise_psd_A2_Hz * B;
    
    wifi_noise_psd_dBm_Hz = -174; % From initializeEnvironment
    wifi_noise_dBm = wifi_noise_psd_dBm_Hz + 10 * log10(B); % -174 + 70 = -104 dBm
    wifi_noise_linear_W = (10^(wifi_noise_dBm / 10)) / 1000; % 3.98e-14 W
    
    for i = 1:numAPs
        signal = received_power_linear(i);
        interference = 0;
        
        % Sum interference from other APs of the *same type* and *same frequency channel*
        for j = 1:numAPs
            if i ~= j && strcmp(apList(i).type, apList(j).type)
                % For LiFi: Only APs on the same frequency channel cause interference [cite: 69]
                % For WiFi: All WiFi APs on same channel interfere (simplified model)
                if strcmp(apList(i).type, 'LiFi')
                    % Check if on same frequency channel
                    if apList(i).freq_channel == apList(j).freq_channel
                        interference = interference + received_power_linear(j);
                    end
                else
                    % WiFi: all other WiFi APs interfere
                    interference = interference + received_power_linear(j);
                end
            end
        end
        
        % Select the correct noise (Amps^2 or Watts)
        if strcmp(apList(i).type, 'LiFi')
            noise = lifi_noise_linear_A2;
        else
            noise = wifi_noise_linear_W;
        end
        
        % SINR calculation
        sinr_linear = signal / (interference + noise);
        
        % Avoid log(0) if signal is zero
        if sinr_linear <= 0
            all_sinr_dB(i) = -Inf;
        else
            all_sinr_dB(i) = 10 * log10(sinr_linear);
        end
    end

end