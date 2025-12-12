% --- mainSimulation.m ---
% This script runs the entire HLWNet handover simulation.
% It compares STD and Proposed algorithms across multiple user speeds.

clear; clc; close all;

%% 1. Simulation Parameters
simParams.roomSize = [15, 15];       % [X, Y] meters
simParams.simDuration = 60;          % Total simulation time (60s for testing, 3600s for full results)
simParams.dt = 0.01;                % Time step (100 ms for accurate TTT)
simParams.v_list = [0.1, 1.5, 3.0];  % User speeds to test (match paper)
simParams.HOM = 1;                   % Handover Margin in dB [cite: 291]
simParams.TTT = 0.160;               % Time to Trigger in seconds (160 ms) [cite: 291]
simParams.HHO_overhead = 0.200;      % HHO overhead time (200 ms) [cite: 288]
simParams.VHO_overhead = 0.500;      % VHO overhead time (500 ms) [cite: 288]

% Animation settings (for testing/debugging)
simParams.animate = true;            % Set to true to visualize simulation
simParams.animate_update_interval = 0.2; % Update every 0.2 seconds (faster for testing)
simParams.animate_keep_open = true;  % Keep animation window open after simulation

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
for algo_idx = 1:1
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
        fprintf('  [%s] Speed: %.1f m/s\n', current_algorithm, v);
        
        % Run single simulation
        [sim_result, ~] = runSingleSimulation(simParams, apList, apParams, v, current_algorithm);
        
        % Store results in table
        results.Speed(i) = sim_result.speed;
        results.HHO_Rate(i) = sim_result.hho_rate;
        results.VHO_Rate(i) = sim_result.vho_rate;
        results.Total_HO_Rate(i) = sim_result.total_ho_rate;
        results.Avg_Throughput_Mbps(i) = sim_result.avg_throughput_mbps;
        results.Avg_SINR_dB(i) = sim_result.avg_sinr_dB;
    end
    
    if algo_idx == 1
        results_STD = results;
    else
        results_Proposed = results;
    end
end

%% 4. Display Results
fprintf('\n========================================\n');
fprintf('STD Algorithm Results\n');
fprintf('========================================\n');
disp(results_STD);

fprintf('\n========================================\n');
fprintf('Proposed Algorithm Results\n');
fprintf('========================================\n');
disp(results_Proposed);

%% 5. Plot Results
plotSimulationResults(results_STD, results_Proposed, simParams);

fprintf('\n=== Simulation Complete ===\n');
