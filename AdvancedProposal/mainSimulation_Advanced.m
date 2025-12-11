% --- mainSimulation_Advanced.m ---
% Advanced simulation for LiFi-WiFi hybrid network handover optimization
% Features:
% - 18x18x3m workspace with 36 LiFi attocells
% - Gaussian Mixture Models for user mobility
% - Monte Carlo Optimizer for handover decision
% - Comprehensive performance metrics


clear; clc; close all;

%% 1. Advanced Simulation Parameters
simParams.roomSize = [18, 18];       % 18x18m workspace
simParams.roomHeight = 3;            % 3m ceiling height
simParams.simDuration = 200;        % 1 hour simulation
simParams.dt = 0.1;                  % 100ms time step
simParams.v_list = [0.5, 1.5, 3.0];  % User speeds (m/s)
simParams.HOM = 2;                   % Handover Margin (2 dB)
simParams.TTT = 0.160;               % Time-to-Trigger (160 ms)
simParams.HHO_overhead = 0.200;      % HHO overhead (200 ms)
simParams.VHO_overhead = 0.500;      % VHO overhead (500 ms)

% Monte Carlo optimizer parameters (embedded in handover function)
simParams.mc_num_scenarios = 3;   % Scenarios per handover check (default for full runs)
simParams.mc_prediction_horizon = 2.0;  % 2 second prediction
simParams.mc_num_time_steps = 50;    % Time steps in prediction

% Fast-mode for quick debugging (overrides Monte Carlo parameters when true)
% Use simParams.fastMode = true for short runs during development
simParams.fastMode = false;
simParams.fastNumScenarios = 100;   % scenarios used when fastMode==true
simParams.fastNumTimeSteps = 10;    % time steps used when fastMode==true

fprintf('========================================\n');
fprintf('ADVANCED LiFi-WiFi HYBRID NETWORK\n');
fprintf('SIMULATION WITH MONTE CARLO OPTIMIZER\n');
fprintf('========================================\n\n');
fprintf('Workspace: 18x18x3m with 36 LiFi Attocells\n');
fprintf('Mobility Model: Gaussian Mixture Models\n');
fprintf('Handover Optimizer: Monte Carlo (5000 scenarios)\n\n');

% Initialize results tables for three algorithms
algorithms = {'STD', 'Proposed', 'AdvancedProposed'};
results_STD = table('Size', [length(simParams.v_list), 8], ...
                'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'Speed', 'HHO_Rate', 'VHO_Rate', 'Total_HO_Rate', 'Avg_Throughput_Mbps', 'Avg_SINR_dB', 'HO_Success_Rate', 'Handover_Delay_ms'}, ...
                'RowNames', arrayfun(@(v) sprintf('v=%.1f', v), simParams.v_list, 'UniformOutput', false));

results_Proposed = table('Size', [length(simParams.v_list), 8], ...
                'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'Speed', 'HHO_Rate', 'VHO_Rate', 'Total_HO_Rate', 'Avg_Throughput_Mbps', 'Avg_SINR_dB', 'HO_Success_Rate', 'Handover_Delay_ms'}, ...
                'RowNames', arrayfun(@(v) sprintf('v=%.1f', v), simParams.v_list, 'UniformOutput', false));

results_Advanced = table('Size', [length(simParams.v_list), 8], ...
                'VariableTypes', {'double', 'double', 'double', 'double', 'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'Speed', 'HHO_Rate', 'VHO_Rate', 'Total_HO_Rate', 'Avg_Throughput_Mbps', 'Avg_SINR_dB', 'HO_Success_Rate', 'Handover_Delay_ms'}, ...
                'RowNames', arrayfun(@(v) sprintf('v=%.1f', v), simParams.v_list, 'UniformOutput', false));

%% 2. Setup Advanced Environment
[apList, apParams] = initializeEnvironment_Advanced(simParams);
fprintf('Advanced Environment Initialized:\n');
fprintf('  - %d LiFi Attocells (6x6 grid, 3m spacing)\n', apParams.numLiFi);
fprintf('  - %d WiFi Access Points\n', apParams.numWiFi);
fprintf('  - Total APs: %d\n\n', apParams.numLiFi + apParams.numWiFi);

%% 3. Run Simulation for All Three Algorithms
for algo_idx = 1:3
    current_algorithm = algorithms{algo_idx};
    fprintf('========================================\n');
    fprintf('Running: %s Algorithm\n', current_algorithm);
    fprintf('========================================\n\n');
    
    switch algo_idx
        case 1
            results = results_STD;
        case 2
            results = results_Proposed;
        case 3
            results = results_Advanced;
    end
    
    for i = 1:length(simParams.v_list)
        v = simParams.v_list(i);
        fprintf('Speed: %.1f m/s...\n', v);
        
        % Initialize counters
        counters.hho = 0;
        counters.vho = 0;
        counters.total_throughput = 0;
        counters.total_sinr = 0;
        counters.active_samples = 0;
        counters.handover_time = 0;
        counters.successful_handovers = 0;
        counters.total_ho_events = 0;
        counters.ho_delay_sum = 0;
        
        % Initialize user
        user.pos = simParams.roomSize / 2;
        user.speed = v;
        user.targetPos = rand(1, 2) .* simParams.roomSize;
        user.in_handover = false;
        user.handover_end_time = 0;
        user.std_timer = 0;
        user.std_target_idx = -1;
        user.prop_timer = 0;
        user.prop_target_idx = -1;
        user.prop_penalty_timer = 0;
        user.adv_timer = 0;
        user.adv_target_idx = -1;
        user.adv_penalty_timer = 0;
        
        % Initial AP connection
        all_sinr_dB = calculateSINR(user.pos, apList, apParams);
        [~, user.currentAP_idx] = max(all_sinr_dB);
        user.currentAP_type = apList(user.currentAP_idx).type;
        user.prop_sinr_0 = all_sinr_dB(user.currentAP_idx);
        user.adv_sinr_baseline = all_sinr_dB(user.currentAP_idx);
        
        % Simulation time loop
        t_samples = 0:simParams.dt:simParams.simDuration;
        for step = 1:length(t_samples)
            t = t_samples(step);
            
            % Progress indicator
            if mod(t, 300) < simParams.dt
                fprintf('  Time: %.0f / %.0f s\n', t, simParams.simDuration);
            end
            
            % Update user position (with GMM for advanced algorithm)
            if algo_idx == 3
                user = updateUserPosition_GMM(user, simParams.roomSize, simParams.dt, apList, all_sinr_dB);
            else
                user = updateUserPosition(user, simParams.roomSize, simParams.dt);
            end
            
            % Calculate SINR
            all_sinr_dB = calculateSINR(user.pos, apList, apParams);
            
            % Check handover completion
            if user.in_handover && t >= user.handover_end_time
                user.in_handover = false;
                counters.successful_handovers = counters.successful_handovers + 1;
            end
            
            % Calculate throughput (when not in handover)
            if ~user.in_handover
                current_sinr_dB = all_sinr_dB(user.currentAP_idx);
                current_sinr_linear = 10^(current_sinr_dB / 10);
                B = 20e6;  % 20 MHz bandwidth
                throughput = B * log2(1 + current_sinr_linear);
                counters.total_throughput = counters.total_throughput + throughput * simParams.dt;
                counters.total_sinr = counters.total_sinr + current_sinr_dB;
                counters.active_samples = counters.active_samples + 1;
            else
                counters.handover_time = counters.handover_time + simParams.dt;
            end
            
            % Check for handover based on algorithm
            if strcmp(current_algorithm, 'STD')
                [user, ho_event, counters] = checkHandover_STD(user, all_sinr_dB, apList, simParams, counters);
            elseif strcmp(current_algorithm, 'Proposed')
                [user, ho_event, counters] = checkHandover_Proposed(user, all_sinr_dB, apList, simParams, counters);
            elseif strcmp(current_algorithm, 'AdvancedProposed')
                [user, ho_event, counters] = checkHandover_AdvancedProposed(user, all_sinr_dB, apList, simParams, counters);
            end
            
            % Handle handover event
            if strcmp(ho_event.type, 'HHO')
                user.in_handover = true;
                user.handover_end_time = t + simParams.HHO_overhead;
                counters.total_ho_events = counters.total_ho_events + 1;
                counters.ho_delay_sum = counters.ho_delay_sum + simParams.HHO_overhead * 1000;  % Convert to ms
            elseif strcmp(ho_event.type, 'VHO')
                user.in_handover = true;
                user.handover_end_time = t + simParams.VHO_overhead;
                counters.total_ho_events = counters.total_ho_events + 1;
                counters.ho_delay_sum = counters.ho_delay_sum + simParams.VHO_overhead * 1000;  % Convert to ms
            end
        end
        
        % Store results
        results.Speed(i) = v;
        results.HHO_Rate(i) = counters.hho / simParams.simDuration;
        results.VHO_Rate(i) = counters.vho / simParams.simDuration;
        results.Total_HO_Rate(i) = (counters.hho + counters.vho) / simParams.simDuration;
        
        if counters.active_samples > 0
            results.Avg_Throughput_Mbps(i) = (counters.total_throughput / simParams.simDuration) / 1e6;
            results.Avg_SINR_dB(i) = counters.total_sinr / counters.active_samples;
        else
            results.Avg_Throughput_Mbps(i) = 0;
            results.Avg_SINR_dB(i) = -Inf;
        end
        
        results.HO_Success_Rate(i) = (counters.successful_handovers / max(1, counters.total_ho_events)) * 100;
        results.Handover_Delay_ms(i) = (counters.ho_delay_sum / max(1, counters.total_ho_events));
        
        fprintf('  HO Count: %d (HHO: %d, VHO: %d)\n', counters.hho + counters.vho, counters.hho, counters.vho);
        fprintf('  Throughput: %.2f Mbps | SINR: %.2f dB\n', results.Avg_Throughput_Mbps(i), results.Avg_SINR_dB(i));
        fprintf('  HO Success Rate: %.1f%% | Avg Delay: %.1f ms\n\n', results.HO_Success_Rate(i), results.Handover_Delay_ms(i));
    end
    
    % Store results back
    switch algo_idx
        case 1
            results_STD = results;
        case 2
            results_Proposed = results;
        case 3
            results_Advanced = results;
    end
end

%% 4. Display Results
fprintf('========================================\n');
fprintf('RESULTS SUMMARY\n');
fprintf('========================================\n\n');

fprintf('STD Algorithm:\n');
disp(results_STD);
fprintf('\nProposed Algorithm:\n');
disp(results_Proposed);
fprintf('\nAdvanced Proposed Algorithm (Monte Carlo):\n');
disp(results_Advanced);

%% 5. Comparison Visualization
figure('Position', [100, 100, 1200, 800]);

% Plot 1: Handover Rates
subplot(2, 3, 1);
hold on;
plot(results_STD.Speed, results_STD.Total_HO_Rate, 'o-', 'LineWidth', 2, 'DisplayName', 'STD');
plot(results_Proposed.Speed, results_Proposed.Total_HO_Rate, 's-', 'LineWidth', 2, 'DisplayName', 'Proposed');
plot(results_Advanced.Speed, results_Advanced.Total_HO_Rate, '^-', 'LineWidth', 2, 'DisplayName', 'Advanced (MC)');
xlabel('User Speed (m/s)'); ylabel('Handover Rate (HOs/s)');
title('Handover Rate Comparison');
legend; grid on;

% Plot 2: Average Throughput
subplot(2, 3, 2);
hold on;
plot(results_STD.Speed, results_STD.Avg_Throughput_Mbps, 'o-', 'LineWidth', 2, 'DisplayName', 'STD');
plot(results_Proposed.Speed, results_Proposed.Avg_Throughput_Mbps, 's-', 'LineWidth', 2, 'DisplayName', 'Proposed');
plot(results_Advanced.Speed, results_Advanced.Avg_Throughput_Mbps, '^-', 'LineWidth', 2, 'DisplayName', 'Advanced (MC)');
xlabel('User Speed (m/s)'); ylabel('Throughput (Mbps)');
title('Average Throughput Comparison');
legend; grid on;

% Plot 3: Average SINR
subplot(2, 3, 3);
hold on;
plot(results_STD.Speed, results_STD.Avg_SINR_dB, 'o-', 'LineWidth', 2, 'DisplayName', 'STD');
plot(results_Proposed.Speed, results_Proposed.Avg_SINR_dB, 's-', 'LineWidth', 2, 'DisplayName', 'Proposed');
plot(results_Advanced.Speed, results_Advanced.Avg_SINR_dB, '^-', 'LineWidth', 2, 'DisplayName', 'Advanced (MC)');
xlabel('User Speed (m/s)'); ylabel('SINR (dB)');
title('Average SINR Comparison');
legend; grid on;

% Plot 4: HHO Rate
subplot(2, 3, 4);
hold on;
plot(results_STD.Speed, results_STD.HHO_Rate, 'o-', 'LineWidth', 2, 'DisplayName', 'STD');
plot(results_Proposed.Speed, results_Proposed.HHO_Rate, 's-', 'LineWidth', 2, 'DisplayName', 'Proposed');
plot(results_Advanced.Speed, results_Advanced.HHO_Rate, '^-', 'LineWidth', 2, 'DisplayName', 'Advanced (MC)');
xlabel('User Speed (m/s)'); ylabel('HHO Rate (HOs/s)');
title('Horizontal Handover Rate');
legend; grid on;

% Plot 5: VHO Rate
subplot(2, 3, 5);
hold on;
plot(results_STD.Speed, results_STD.VHO_Rate, 'o-', 'LineWidth', 2, 'DisplayName', 'STD');
plot(results_Proposed.Speed, results_Proposed.VHO_Rate, 's-', 'LineWidth', 2, 'DisplayName', 'Proposed');
plot(results_Advanced.Speed, results_Advanced.VHO_Rate, '^-', 'LineWidth', 2, 'DisplayName', 'Advanced (MC)');
xlabel('User Speed (m/s)'); ylabel('VHO Rate (HOs/s)');
title('Vertical Handover Rate');
legend; grid on;

% Plot 6: Handover Success Rate
subplot(2, 3, 6);
hold on;
plot(results_STD.Speed, results_STD.HO_Success_Rate, 'o-', 'LineWidth', 2, 'DisplayName', 'STD');
plot(results_Proposed.Speed, results_Proposed.HO_Success_Rate, 's-', 'LineWidth', 2, 'DisplayName', 'Proposed');
plot(results_Advanced.Speed, results_Advanced.HO_Success_Rate, '^-', 'LineWidth', 2, 'DisplayName', 'Advanced (MC)');
xlabel('User Speed (m/s)'); ylabel('Success Rate (%)');
title('Handover Success Rate');
legend; grid on;
ylim([90, 101]);

sgtitle('LiFi-WiFi Hybrid Network: Algorithm Comparison (18x18x3m, 36 Attocells)');

fprintf('\nSimulation complete!\n');
