% --- main_simulation.m ---
% This script runs the entire HLWNet handover simulation.

clear; clc; close all;

%% 1. Simulation Parameters
simParams.roomSize = [15, 15];       % [X, Y] meters
simParams.simDuration = 36;        % Total simulation time (e.g., 3600s = 1 hour)
simParams.dt = 0.01;                 % Time step (10 ms)
simParams.v_list = [0.1, 1.5, 5.0];  % User speeds to test
simParams.HOM = 1;                   % Handover Margin in dB [cite: 291]
simParams.TTT = 0.160;               % Time to Trigger in seconds (160 ms) [cite: 291]
simParams.algorithm = 'STD';         % 'STD' or 'Proposed'

% Initialize storage for result

results = table('Size', [length(simParams.v_list), 3], ...
                'VariableTypes', {'double', 'double', 'double'}, ...
                'VariableNames', {'Speed', 'HHO_Rate', 'VHO_Rate'}, ...
                'RowNames', arrayfun(@(v) sprintf('v=%.1f', v), simParams.v_list, 'UniformOutput', false));

%% 2. Setup Environment
[apList, apParams] = initializeEnvironment(simParams);
fprintf('Environment initialized with %d LiFi and %d WiFi APs.\n', apParams.numLiFi, apParams.numWiFi);

%% 3. Run Simulation Loop
for i = 1:length(simParams.v_list)
    v = simParams.v_list(i);
    fprintf('Running simulation for speed: %.1f m/s...\n', v);
    
    % Initialize counters
    counters.hho = 0;
    counters.vho = 0;
    
    % Initialize user state
    user.pos = simParams.roomSize / 2; % Start in the middle
    user.speed = v;
    user.targetPos = rand(1, 2) .* simParams.roomSize; % First random waypoint
    
    % Connect user to the strongest AP at the start
    all_sinr_dB = calculateSINR(user.pos, apList, apParams);
    [~, user.currentAP_idx] = max(all_sinr_dB);
    user.currentAP_type = apList(user.currentAP_idx).type;
    
    % Initialize algorithm state
    user.std_timer = 0;
    user.std_target_idx = -1;
    % user.proposed_timer = 0; % (for proposed algorithm)
    % user.proposed_t0_sinr = []; % (for proposed algorithm)

    % --- Time Loop ---
    for t = 0:simParams.dt:simParams.simDuration
        fprintf('%.1f\n', t)
        % 1. Update user position (Mobility)
        user = updateUserPosition(user, simParams.roomSize, simParams.dt);
        
        % 2. Calculate all SINR values
        all_sinr_dB = calculateSINR(user.pos, apList, apParams);
        
        % 3. Check for Handover
        % This is where you swap algorithms
        if strcmp(simParams.algorithm, 'STD')
            [user, ho_event, counters] = checkHandover_STD(user, all_sinr_dB, apList, simParams, counters);
        elseif strcmp(simParams.algorithm, 'Proposed')
            % [user, ho_event, counters] = checkHandover_Proposed(user, all_sinr_dB, apList, simParams, counters);
        end
    end
    
    % 4. Store results
    results.Speed(i) = v;
    results.HHO_Rate(i) = counters.hho / simParams.simDuration;
    results.VHO_Rate(i) = counters.vho / simParams.simDuration;
end

%% 4. Plot Results
disp(results);
figure;
b = bar(results.Speed, [results.HHO_Rate, results.VHO_Rate]);
xlabel('User''s Speed [m/s]');
ylabel('Handover Rate [/s]');
legend('HHO', 'VHO');
title(sprintf('Handover Rate vs. Speed (%s Algorithm)', simParams.algorithm));
grid on;