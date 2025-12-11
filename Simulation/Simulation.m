classdef Simulation < handle
    % HLWNetSim: Simulation Environment for Hybrid LiFi and WiFi Networks
    % Based on "Smart Handover for Hybrid LiFi and WiFi Networks" (2020)
    
    properties
        % --- Topology Parameters ---
        RoomSize = [10, 10];
        LiFi_Spacing = 2.5;         % Spacing between LiFi APs (r)
        Vertical_Distance = 3.0;
        Num_WiFi = 4;
        
        % --- PHY Layer Parameters ---
        Bandwidth = 10e6;          % 10 MHz
        TxPower_LiFi = 2.25;       % Watts (Optical) per AP
        TxPower_WiFi = 0.1;        % Watts (20 dBm)
        FOV = 60;                  % Degrees (Semi-angle)
        Responsivity = 0.53;       % A/W
        NoisePSD_LiFi = 1e-21;     % A^2/Hz (Approx)
        NoisePSD_WiFi = 10^(-174/10)*1e-3; % Watts/Hz (-174 dBm/Hz)
        
        % --- Handover Parameters ---
        HOM = 1.0;            % Handover Margin (dB)
        TTT = 0.160;          % Time to Trigger (s)
        TimeStep = 0.01;      % Simulation resolution (10ms)
        Delay_HHO = 0.200;    % Horizontal Handover Delay (s)
        Delay_VHO = 0.500;    % Vertical Handover Delay (s)
        
        % --- State Variables ---
        LiFi_Pos      % Matrix of LiFi AP coordinates
        WiFi_Pos      % Matrix of WiFi AP coordinates
    end
    
    methods
        function obj = Simulation()
            obj.setupEnvironment();
        end
        
        function setupEnvironment(obj)
            % Sets up AP locations based on Regular Deployment
            
            % 1. LiFi Lattice (4x4 grid for 10m room with 2.5m spacing)
            % Centering the grid in the room
            x = linspace(obj.LiFi_Spacing/2, obj.RoomSize(1)-obj.LiFi_Spacing/2, 4);
            y = linspace(obj.LiFi_Spacing/2, obj.RoomSize(2)-obj.LiFi_Spacing/2, 4);
            [X, Y] = meshgrid(x, y);
            obj.LiFi_Pos = [X(:), Y(:), ones(16,1) * obj.Vertical_Distance];
            
            % 2. WiFi Regular Deployment (Centers of 4 quadrants)
            % Quadrant centers: (2.5, 2.5), (7.5, 2.5), etc.
            wx = [2.5, 7.5];
            wy = [2.5, 7.5];
            [WX, WY] = meshgrid(wx, wy);
            obj.WiFi_Pos = [WX(:), WY(:), ones(4,1) * obj.Vertical_Distance];
        end
        
        function [sinr_db, capacity] = getChannelResponse(obj, user_pos)
            % Calculates SINR and Capacity for all APs at user_pos
            % Returns: sinr_db (1 x NumAPs), capacity (1 x NumAPs)
            % Indices 1-16 are LiFi, 17-20 are WiFi
            
            % --- LiFi Channel (Lambertian) ---
            % H = (m+1)A / (2pi d^2) * cos^m(phi) * cos(psi)
            m = -log(2) / log(cosd(obj.FOV)); % Lambertian order
            Adet = 1e-4; % Detector area (assumed standard)
            
            % Vectors from user to all LiFi APs
            vec_L = obj.LiFi_Pos - [user_pos, 0]; 
            dist_L = sqrt(sum(vec_L.^2, 2));
            cos_phi = vec_L(:,3) ./ dist_L; % Angle of irradiance
            cos_psi = vec_L(:,3) ./ dist_L; % Angle of incidence (assuming facing up)
            
            H_LiFi = ((m+1)*Adet ./ (2*pi*dist_L.^2)) .* (cos_phi.^m) .* cos_psi;
            H_LiFi(cos_psi < cosd(obj.FOV)) = 0; % FOV clipping
            
            % Electrical SINR for LiFi: S = (R * P_rx)^2
            Sig_LiFi = (obj.Responsivity * obj.TxPower_LiFi * H_LiFi).^2;
            Noise_LiFi = obj.NoisePSD_LiFi * obj.Bandwidth;
            SINR_LiFi = Sig_LiFi / Noise_LiFi;
            
            % --- WiFi Channel (Log-distance) ---
            % PL(d) = PL(d0) + 10n log10(d/d0)
            vec_W = obj.WiFi_Pos - [user_pos, 0];
            dist_W = sqrt(sum(vec_W.^2, 2));
            
            f_c = 2.4e9; c = 3e8; lambda = c/f_c;
            PL_d0 = 20*log10(4*pi*1/lambda); % Ref loss at 1m
            n_exp = 3; % Indoor path loss exponent
            PL_dB = PL_d0 + 10*n_exp*log10(dist_W);
            
            Prx_WiFi = obj.TxPower_WiFi ./ (10.^(PL_dB/10));
            Noise_WiFi = obj.NoisePSD_WiFi * obj.Bandwidth;
            SINR_WiFi = Prx_WiFi / Noise_WiFi;
            
            % --- Capacity Bounds  ---
            % Eq (1): LiFi uses tight bound, WiFi uses Shannon
            C_LiFi = (obj.Bandwidth/2) * log2(1 + (exp(1)/(2*pi)) * SINR_LiFi);
            C_WiFi = obj.Bandwidth * log2(1 + SINR_WiFi);
            
            % Combine
            sinr_lin = [SINR_LiFi; SINR_WiFi];
            sinr_db = 10*log10(sinr_lin)';
            capacity = [C_LiFi; C_WiFi]';
        end
        
        function isEmpty = isEmpty(~, val)
             isEmpty = isempty(val);
        end
    end
end
