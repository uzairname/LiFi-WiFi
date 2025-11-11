% --- main_simulation.m ---
% This script runs the entire HLWNet handover simulation.

clear; clc; close all;

%% 1. Simulation Parameters
simParams.roomSize = [15, 15];       % [X, Y] meters
simParams.simDuration = 600;         % Total simulation time (600s = 10 min for testing, use 3600 for full hour)
simParams.dt = 0.1;                % Time step (1 ms for more accurate TTT)
simParams.v_list = [0.1, 1.5, 5.0, 10.0];  % User speeds to test (match paper)
simParams.HOM = 1;                   % Handover Margin in dB [cite: 291]
simParams.TTT = 0.160;               % Time to Trigger in seconds (160 ms) [cite: 291]
simParams.HHO_overhead = 0.200;      % HHO overhead time (200 ms) [cite: 288]
simParams.VHO_overhead = 0.500;      % VHO overhead time (500 ms) [cite: 288]
simParams.algorithm = 'STD';         % 'STD' or 'Proposed'

% Initialize storage for results
results = table('Size', [length(simParams.v_list), 5], ...
                'VariableTypes', {'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'Speed', 'HHO_Rate', 'VHO_Rate', 'Avg_Throughput_Mbps', 'Avg_SINR_dB'}, ...
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
    counters.total_throughput = 0; % Sum of throughput over time
    counters.total_sinr = 0;       % Sum of SINR over time
    counters.active_samples = 0;   % Number of samples when user is active (not in handover)
    counters.handover_time = 0;    % Time spent in handover
    
    % Initialize user state
    user.pos = simParams.roomSize / 2; % Start in the middle
    user.speed = v;
    user.targetPos = rand(1, 2) .* simParams.roomSize; % First random waypoint
    user.in_handover = false;      % Flag to track if user is in handover
    user.handover_end_time = 0;    % When handover will complete
    
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
        % Progress indicator (every 10 seconds)
        if mod(t, 10) < simParams.dt
            fprintf('  Time: %.1f / %.1f s\n', t, simParams.simDuration);
        end
        
        % 1. Update user position (Mobility)
        user = updateUserPosition(user, simParams.roomSize, simParams.dt);
        
        % 2. Calculate all SINR values
        all_sinr_dB = calculateSINR(user.pos, apList, apParams);
        
        % 3. Check if user is in handover
        if user.in_handover && t >= user.handover_end_time
            user.in_handover = false; % Handover complete
        end
        
        % 4. Calculate throughput (only if not in handover)
        if ~user.in_handover
            % Get current SINR from serving AP
            current_sinr_dB = all_sinr_dB(user.currentAP_idx);
            current_sinr_linear = 10^(current_sinr_dB / 10);
            
            % Shannon capacity: C = B * log2(1 + SINR)
            B = 10e6; % 10 MHz bandwidth
            instantaneous_throughput = B * log2(1 + current_sinr_linear); % bits/s
            
            % Accumulate statistics
            counters.total_throughput = counters.total_throughput + instantaneous_throughput * simParams.dt;
            counters.total_sinr = counters.total_sinr + current_sinr_dB;
            counters.active_samples = counters.active_samples + 1;
        else
            % User is in handover, no throughput
            counters.handover_time = counters.handover_time + simParams.dt;
        end
        
        % 5. Check for Handover
        % This is where you swap algorithms
        if strcmp(simParams.algorithm, 'STD')
            [user, ho_event, counters] = checkHandover_STD(user, all_sinr_dB, apList, simParams, counters);
        elseif strcmp(simParams.algorithm, 'Proposed')
            % [user, ho_event, counters] = checkHandover_Proposed(user, all_sinr_dB, apList, simParams, counters);
        end
        
        % 6. If handover occurred, set handover state
        if strcmp(ho_event.type, 'HHO')
            user.in_handover = true;
            user.handover_end_time = t + simParams.HHO_overhead;
        elseif strcmp(ho_event.type, 'VHO')
            user.in_handover = true;
            user.handover_end_time = t + simParams.VHO_overhead;
        end
    end
    
    % 4. Store results
    results.Speed(i) = v;
    results.HHO_Rate(i) = counters.hho / simParams.simDuration;
    results.VHO_Rate(i) = counters.vho / simParams.simDuration;
    
    % Calculate average throughput in Mbps
    if counters.active_samples > 0
        results.Avg_Throughput_Mbps(i) = (counters.total_throughput / simParams.simDuration) / 1e6; % Convert to Mbps
        results.Avg_SINR_dB(i) = counters.total_sinr / counters.active_samples;
    else
        results.Avg_Throughput_Mbps(i) = 0;
        results.Avg_SINR_dB(i) = -Inf;
    end
    
    fprintf('  Total handover time: %.2f s (%.1f%%)\n', counters.handover_time, 100*counters.handover_time/simParams.simDuration);
    fprintf('  Average throughput: %.2f Mbps\n', results.Avg_Throughput_Mbps(i));
    fprintf('  Average SINR: %.2f dB\n\n', results.Avg_SINR_dB(i));
end

%% 4. Plot Results
disp(results);

% Figure 1: Handover Rates
figure('Position', [100, 100, 1200, 400]);

subplot(1, 3, 1);
b = bar(results.Speed, [results.HHO_Rate, results.VHO_Rate]);
xlabel('User''s Speed [m/s]');
ylabel('Handover Rate [/s]');
legend('HHO', 'VHO');
title(sprintf('Handover Rate vs. Speed (%s Algorithm)', simParams.algorithm));
grid on;

% Figure 2: Average Throughput vs Speed
subplot(1, 3, 2);
plot(results.Speed, results.Avg_Throughput_Mbps, '-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('User''s Speed [m/s]');
ylabel('Average Throughput [Mbps]');
title(sprintf('Throughput vs. Speed (%s Algorithm)', simParams.algorithm));
grid on;

% Figure 3: Average SINR vs Speed
subplot(1, 3, 3);
plot(results.Speed, results.Avg_SINR_dB, '-s', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.85, 0.33, 0.1]);
xlabel('User''s Speed [m/s]');
ylabel('Average SINR [dB]');
title(sprintf('SINR vs. Speed (%s Algorithm)', simParams.algorithm));
grid on;