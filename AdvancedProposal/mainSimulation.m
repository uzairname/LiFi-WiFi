% --- main_simulation.m ---
% This script runs the entire HLWNet handover simulation.

clear; clc; close all;

%% 1. Simulation Parameters
simParams.roomSize = [15, 15];       % [X, Y] meters
simParams.simDuration = 200;        % Total simulation time (3600s = 1 hour for full results)
simParams.dt = 0.1;                % Time step (100 ms for accurate TTT)
simParams.v_list = [0.1, 1.5, 5.0];  % User speeds to test (match paper)
simParams.HOM = 1;                   % Handover Margin in dB [cite: 291]
simParams.TTT = 0.160;               % Time to Trigger in seconds (160 ms) [cite: 291]
simParams.HHO_overhead = 0.200;      % HHO overhead time (200 ms) [cite: 288]
simParams.VHO_overhead = 0.500;      % VHO overhead time (500 ms) [cite: 288]

% Initialize storage for results (both algorithms)
algorithms = {'STD', 'Proposed'};
results_STD = table('Size', [length(simParams.v_list), 6], ...
                'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'Speed', 'HHO_Rate', 'VHO_Rate', 'Total_HO_Rate', 'Avg_Throughput_Mbps', 'Avg_SINR_dB'}, ...
                'RowNames', arrayfun(@(v) sprintf('v=%.1f', v), simParams.v_list, 'UniformOutput', false));

results_Proposed = table('Size', [length(simParams.v_list), 6], ...
                'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'Speed', 'HHO_Rate', 'VHO_Rate', 'Total_HO_Rate', 'Avg_Throughput_Mbps', 'Avg_SINR_dB'}, ...
                'RowNames', arrayfun(@(v) sprintf('v=%.1f', v), simParams.v_list, 'UniformOutput', false));

%% 2. Setup Environment
[apList, apParams] = initializeEnvironment(simParams);
fprintf('Environment initialized with %d LiFi and %d WiFi APs.\n', apParams.numLiFi, apParams.numWiFi);

%% 3. Run Simulation Loop for BOTH algorithms
for algo_idx = 1:2
    current_algorithm = algorithms{algo_idx};
    fprintf('\n========================================\n');
    fprintf('Running %s Algorithm\n', current_algorithm);
    fprintf('========================================\n\n');
    
    if algo_idx == 1
        results = results_STD;
    else
        results = results_Proposed;
    end
    
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
        counters.last_ho_time = 0;     % For tracking hopping rate
        
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
        
        % Initialize algorithm state (STD)
        user.std_timer = 0;
        user.std_target_idx = -1;
        
        % Initialize algorithm state (Proposed)
        user.prop_timer = 0;
        user.prop_target_idx = -1;
        user.prop_sinr_0 = all_sinr_dB(user.currentAP_idx);
        user.prop_penalty_timer = 0;

        % --- Time Loop ---
        t_samples = 0:simParams.dt:simParams.simDuration;
        for step = 1:length(t_samples)
            t = t_samples(step);
            
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
            if strcmp(current_algorithm, 'STD')
                [user, ho_event, counters] = checkHandover_STD(user, all_sinr_dB, apList, simParams, counters);
            elseif strcmp(current_algorithm, 'Proposed')
                [user, ho_event, counters] = checkHandover_Proposed(user, all_sinr_dB, apList, simParams, counters);
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
        results.Total_HO_Rate(i) = (counters.hho + counters.vho) / simParams.simDuration;
        
        % Calculate average throughput in Mbps
        if counters.active_samples > 0
            results.Avg_Throughput_Mbps(i) = (counters.total_throughput / simParams.simDuration) / 1e6; % Convert to Mbps
            results.Avg_SINR_dB(i) = counters.total_sinr / counters.active_samples;
        else
            results.Avg_Throughput_Mbps(i) = 0;
            results.Avg_SINR_dB(i) = -Inf;
        end
        
        fprintf('  Total HO count: %d (HHO: %d, VHO: %d)\n', counters.hho + counters.vho, counters.hho, counters.vho);
        fprintf('  Total handover time: %.2f s (%.1f%%)\n', counters.handover_time, 100*counters.handover_time/simParams.simDuration);
        fprintf('  Average throughput: %.2f Mbps\n', results.Avg_Throughput_Mbps(i));
        fprintf('  Average SINR: %.2f dB\n\n', results.Avg_SINR_dB(i));
    end
    
    if algo_idx == 1
        results_STD = results;
    else
        results_Proposed = results;
    end
end

%% 4. Display and Plot Results
fprintf('\n========================================\n');
fprintf('STD Algorithm Results\n');
fprintf('========================================\n');
disp(results_STD);

fprintf('\n========================================\n');
fprintf('Proposed Algorithm Results\n');
fprintf('========================================\n');
disp(results_Proposed);

% Figure 7: Handover Rates (Bar Chart - HHO and VHO)
figure('Name', 'Figure 7', 'NumberTitle', 'off', 'Position', [100, 100, 900, 500]);
num_speeds = length(simParams.v_list);
speed_labels = cellfun(@(x) sprintf('%.1f m/s', x), num2cell(simParams.v_list), 'UniformOutput', false);

% Prepare data for grouped bar chart
x_positions = 1:num_speeds;
bar_width = 0.18;

% Plot HHO and VHO for each algorithm
hold on;

% Proposed - HHO (Red)
bar(x_positions - 1.5*bar_width, results_Proposed.HHO_Rate, bar_width, 'FaceColor', [1 0 0], 'EdgeColor', 'black', 'LineWidth', 0.5);

% Proposed - VHO (Green)
bar(x_positions - 0.5*bar_width, results_Proposed.VHO_Rate, bar_width, 'FaceColor', [0 1 0], 'EdgeColor', 'black', 'LineWidth', 0.5);

% STD - HHO (Blue)
bar(x_positions + 0.5*bar_width, results_STD.HHO_Rate, bar_width, 'FaceColor', [0 0 1], 'EdgeColor', 'black', 'LineWidth', 0.5);

% STD - VHO (Cyan)
bar(x_positions + 1.5*bar_width, results_STD.VHO_Rate, bar_width, 'FaceColor', [0 1 1], 'EdgeColor', 'black', 'LineWidth', 0.5);

% Labels and formatting
xlabel('User Speed', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Handover rate [/s]', 'FontSize', 12, 'FontWeight', 'bold');
title('Fig. 7. Handover rates of HHO and VHO.', 'FontSize', 12, 'FontWeight', 'bold');

% Set x-axis labels
xticks(x_positions);
xticklabels(speed_labels);

% Legend
legend('Proposed HHO', 'Proposed VHO', 'STD HHO', 'STD VHO', 'FontSize', 10, 'Location', 'best');

% Y-axis limits
ylim([0, max([results_Proposed.HHO_Rate; results_Proposed.VHO_Rate; results_STD.HHO_Rate; results_STD.VHO_Rate])*1.2 + 0.2]);

grid on;
set(gca, 'FontSize', 11);
hold off;

% Figure 9: User Throughput vs Speed
figure('Name', 'Figure 9', 'NumberTitle', 'off', 'Position', [100, 650, 900, 500]);
hold on;

% Plot throughput curves
plot(results_Proposed.Speed, results_Proposed.Avg_Throughput_Mbps, '-o', 'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [1 0 0], 'DisplayName', 'Proposed');
plot(results_STD.Speed, results_STD.Avg_Throughput_Mbps, '-s', 'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0 0 1], 'DisplayName', 'STD');

% Add placeholder for Trajectory-based and WiFi variants (for paper matching)
% These would be additional algorithms if implemented
% plot(speeds_traj, throughput_traj, '-v', 'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0 0.5 0], 'DisplayName', 'Trajectory-based');

xlabel('User''s speed [m/s]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('User throughput [Mbps]', 'FontSize', 12, 'FontWeight', 'bold');
title('Fig. 9. User throughput versus the user''s speed.', 'FontSize', 12, 'FontWeight', 'bold');

% Set axis limits similar to paper
xlim([0, 5.5]);
ylim([0, 105]);

% Grid
grid on;
set(gca, 'FontSize', 11);

% Legend
legend('Proposed', 'STD', 'FontSize', 11, 'Location', 'best');

hold off;