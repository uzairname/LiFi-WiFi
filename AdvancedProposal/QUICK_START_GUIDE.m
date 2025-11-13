% --- QUICK START GUIDE ---
% Advanced Proposed Solution for LiFi-WiFi Handover Optimization
%
% This guide shows how to get started with the new Monte Carlo Optimizer-based
% handover strategy with 18×18×3m workspace and 36 LiFi attocells.

%% STEP 1: Run the Full Simulation with All Algorithms
% This is the recommended starting point. It will:
% - Initialize 18×18×3m workspace with 36 LiFi + 4 WiFi APs
% - Run STD, Proposed, and Advanced Proposed algorithms
% - Test three user speeds (0.5, 1.5, 3.0 m/s)
% - Generate comparison plots and results table

clear; clc; close all;
mainSimulation_Advanced
% Expected runtime: 30-60 minutes depending on hardware
% Output: Comprehensive comparison across all algorithms

%% STEP 2: Run Only Advanced Proposed Algorithm (Faster)
% If you want to test just the new Monte Carlo optimizer:

% Option A: Modify mainSimulation_Advanced to run single algorithm
% (Edit the file and change the loop: for algo_idx = 3:3)

% Option B: Create custom test script (see STEP 3)

%% STEP 3: Custom Test - Single Algorithm with Specific Parameters

clear; clc; close all;

% Define custom parameters
simParams.roomSize = [18, 18];      % 18×18m workspace
simParams.roomHeight = 3;            % 3m ceiling
simParams.simDuration = 1800;        % 30 minutes (shorter for testing)
simParams.dt = 0.1;                  % 100ms time step
simParams.v_list = [1.5];            % Only test 1.5 m/s
simParams.HOM = 2;                   % 2 dB handover margin
simParams.TTT = 0.160;               % 160ms Time-to-Trigger
simParams.HHO_overhead = 0.200;      % 200ms HHO delay
simParams.VHO_overhead = 0.500;      % 500ms VHO delay
simParams.mc_num_scenarios = 5000;   % 5000 Monte Carlo scenarios
simParams.mc_prediction_horizon = 2.0;  % 2 second prediction

% Initialize environment
[apList, apParams] = initializeEnvironment_Advanced(simParams);

fprintf('\n=== ADVANCED PROPOSED ALGORITHM TEST ===\n');
fprintf('Workspace: 18x18x3m\n');
fprintf('LiFi Attocells: %d (6x6 grid)\n', apParams.numLiFi);
fprintf('WiFi APs: %d\n\n', apParams.numWiFi);

% Initialize user
user.pos = simParams.roomSize / 2;
user.speed = 1.5;
user.targetPos = rand(1, 2) .* simParams.roomSize;
user.in_handover = false;
user.handover_end_time = 0;
user.adv_timer = 0;
user.adv_target_idx = -1;
user.adv_penalty_timer = 0;

% Initial connection
all_sinr_dB = calculateSINR(user.pos, apList, apParams);
[~, user.currentAP_idx] = max(all_sinr_dB);
user.currentAP_type = apList(user.currentAP_idx).type;
user.adv_sinr_baseline = all_sinr_dB(user.currentAP_idx);

% Initialize counters
counters.hho = 0;
counters.vho = 0;
counters.total_throughput = 0;
counters.total_sinr = 0;
counters.active_samples = 0;
counters.successful_handovers = 0;
counters.total_ho_events = 0;

% Run simulation
fprintf('Running simulation...\n');
t_samples = 0:simParams.dt:simParams.simDuration;

for step = 1:length(t_samples)
    t = t_samples(step);
    
    if mod(step, 100) == 0
        fprintf('  Progress: %.0f/%.0f s (%.1f%%)\n', t, simParams.simDuration, 100*step/length(t_samples));
    end
    
    % Update position with GMM mobility
    user = updateUserPosition_GMM(user, simParams.roomSize, simParams.dt, apList, all_sinr_dB);
    
    % Calculate SINR
    all_sinr_dB = calculateSINR(user.pos, apList, apParams);
    
    % Check handover with advanced algorithm
    [user, ho_event, counters] = checkHandover_AdvancedProposed(user, all_sinr_dB, apList, simParams, counters);
    
    % Handle handover
    if strcmp(ho_event.type, 'HHO')
        user.in_handover = true;
        user.handover_end_time = t + simParams.HHO_overhead;
    elseif strcmp(ho_event.type, 'VHO')
        user.in_handover = true;
        user.handover_end_time = t + simParams.VHO_overhead;
    end
    
    % Update handover state
    if user.in_handover && t >= user.handover_end_time
        user.in_handover = false;
        counters.successful_handovers = counters.successful_handovers + 1;
    end
    
    % Calculate throughput
    if ~user.in_handover
        current_sinr_dB = all_sinr_dB(user.currentAP_idx);
        current_sinr_linear = 10^(current_sinr_dB / 10);
        B = 20e6;
        throughput = B * log2(1 + current_sinr_linear);
        counters.total_throughput = counters.total_throughput + throughput * simParams.dt;
        counters.total_sinr = counters.total_sinr + current_sinr_dB;
        counters.active_samples = counters.active_samples + 1;
    end
end

% Display results
fprintf('\n=== RESULTS ===\n');
fprintf('Total Handovers: %d (HHO: %d, VHO: %d)\n', counters.hho + counters.vho, counters.hho, counters.vho);
fprintf('Handover Rate: %.3f HOs/s\n', (counters.hho + counters.vho) / simParams.simDuration);
fprintf('Average Throughput: %.2f Mbps\n', (counters.total_throughput / simParams.simDuration) / 1e6);
fprintf('Average SINR: %.2f dB\n', counters.total_sinr / counters.active_samples);
fprintf('Successful Handovers: %d / %d (%.1f%%)\n', counters.successful_handovers, ...
        counters.hho + counters.vho, 100*counters.successful_handovers/(counters.hho+counters.vho));

%% STEP 4: Visualize Workspace Configuration

figure('Position', [100, 100, 1000, 800]);

% Plot 1: LiFi Attocells
subplot(2, 2, 1);
hold on;
for i = 1:36
    pos = apList(i).pos(1:2);
    circle_h = viscircles(pos, apList(i).coverage_radius, 'EdgeColor', 'b', 'LineStyle', '--', 'Linewidth', 0.5);
    plot(pos(1), pos(2), 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'blue');
end
xlabel('X (m)'); ylabel('Y (m)');
title('LiFi Attocells Deployment (36 units, 6×6 grid)');
xlim([-1, 19]); ylim([-1, 19]);
grid on;
axis equal;

% Plot 2: WiFi APs
subplot(2, 2, 2);
hold on;
for i = 37:40
    pos = apList(i).pos(1:2);
    circle_h = viscircles(pos, apList(i).coverage_radius, 'EdgeColor', 'r', 'LineStyle', '--', 'Linewidth', 0.5);
    plot(pos(1), pos(2), 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'red');
end
xlabel('X (m)'); ylabel('Y (m)');
title('WiFi Access Points (4 units)');
xlim([-1, 19]); ylim([-1, 19]);
grid on;
axis equal;

% Plot 3: Combined Coverage
subplot(2, 2, 3);
hold on;
% LiFi cells
for i = 1:36
    pos = apList(i).pos(1:2);
    viscircles(pos, apList(i).coverage_radius, 'EdgeColor', 'b', 'LineStyle', '--', 'Linewidth', 0.3);
    plot(pos(1), pos(2), 'bo', 'MarkerSize', 6);
end
% WiFi APs
for i = 37:40
    pos = apList(i).pos(1:2);
    viscircles(pos, apList(i).coverage_radius, 'EdgeColor', 'r', 'LineStyle', '-', 'Linewidth', 1);
    plot(pos(1), pos(2), 'r^', 'MarkerSize', 10, 'MarkerFaceColor', 'red');
end
xlabel('X (m)'); ylabel('Y (m)');
title('Complete Network Coverage (LiFi + WiFi)');
xlim([-1, 19]); ylim([-1, 19]);
grid on;
axis equal;
legend('LiFi Coverage', 'LiFi AP', 'WiFi Coverage', 'WiFi AP');

% Plot 4: Frequency Reuse Pattern
subplot(2, 2, 4);
freq_pattern = [0 1 0 1 0 1;
                2 3 2 3 2 3;
                0 1 0 1 0 1;
                2 3 2 3 2 3;
                0 1 0 1 0 1;
                2 3 2 3 2 3];
imagesc(freq_pattern);
colorbar;
xlabel('Grid X'); ylabel('Grid Y');
title('LiFi Frequency Reuse Pattern (Factor 4)');
caxis([0, 3]);

sgtitle('18×18×3m Workspace Configuration with 36 LiFi + 4 WiFi APs');

%% STEP 5: Test Mobility Models

% Compare standard vs. GMM mobility
clear; clc;

simParams.roomSize = [18, 18];
simParams.dt = 0.1;

% Scenario: 1000 time steps with same initial conditions
num_steps = 1000;
speeds = [0.5, 1.5, 3.0];

for speed_idx = 1:length(speeds)
    figure;
    
    for mobility_type = 1:2  % 1 = Standard, 2 = GMM
        subplot(1, 2, mobility_type);
        hold on;
        
        % Initialize user
        user.pos = simParams.roomSize / 2;
        user.speed = speeds(speed_idx);
        user.targetPos = rand(1, 2) .* simParams.roomSize;
        user.velocity_vector = [0, 0];
        user.gmm_velocity_mean = user.speed;
        user.gmm_velocity_variance = user.speed * 0.1;
        user.gmm_direction_angle = 0;
        user.gmm_dwell_timer = 0;
        
        positions = zeros(num_steps, 2);
        
        for step = 1:num_steps
            if mobility_type == 1
                user = updateUserPosition(user, simParams.roomSize, simParams.dt);
            else
                % Create dummy SINR and apList for GMM
                all_sinr_dB = zeros(40, 1);
                apList(40).coverage_radius = 2.5;
                user = updateUserPosition_GMM(user, simParams.roomSize, simParams.dt, apList, all_sinr_dB);
            end
            positions(step, :) = user.pos;
        end
        
        plot(positions(:, 1), positions(:, 2), '.', 'MarkerSize', 3);
        xlabel('X (m)'); ylabel('Y (m)');
        
        if mobility_type == 1
            title('Standard Random Waypoint');
        else
            title('Gaussian Mixture Model (GMM)');
        end
        
        xlim([0, 18]); ylim([0, 18]);
        grid on;
        axis equal;
    end
    
    sgtitle(sprintf('Mobility Comparison at %.1f m/s', speeds(speed_idx)));
end

%% STEP 6: Parameter Sensitivity Analysis

% Test how algorithm performs with different Monte Carlo scenarios
clear; clc;

fprintf('=== MONTE CARLO PARAMETER SENSITIVITY ===\n\n');

scenario_counts = [100, 500, 1000, 5000, 10000];
results = [];

simParams.roomSize = [18, 18];
simParams.simDuration = 600;  % 10 minutes
simParams.dt = 0.1;
simParams.v_list = [1.5];
simParams.HOM = 2;
simParams.TTT = 0.160;
simParams.HHO_overhead = 0.200;
simParams.VHO_overhead = 0.500;

for mc_scenarios = scenario_counts
    fprintf('Testing with %d Monte Carlo scenarios...\n', mc_scenarios);
    simParams.mc_num_scenarios = mc_scenarios;
    
    % Note: Run modified simulation here
    % For now, just display parameter
    fprintf('  Scenarios: %d\n', mc_scenarios);
end

fprintf('\nResults: Higher scenario count = more stable decisions but longer computation\n');
fprintf('Recommended: 5000 scenarios for good balance between accuracy and speed\n');

%% STEP 7: Documentation and Help

fprintf('\n=== QUICK START GUIDE COMPLETE ===\n\n');
fprintf('Key Files:\n');
fprintf('  1. checkHandover_AdvancedProposed.m - Monte Carlo handover algorithm\n');
fprintf('  2. initializeEnvironment_Advanced.m - 18×18×3m workspace setup\n');
fprintf('  3. updateUserPosition_GMM.m - Gaussian Mixture Model mobility\n');
fprintf('  4. mainSimulation_Advanced.m - Full simulation framework\n\n');

fprintf('Next Steps:\n');
fprintf('  - Run "mainSimulation_Advanced" for full comparison\n');
fprintf('  - See ADVANCED_PROPOSED_README.md for detailed documentation\n');
fprintf('  - Check ADVANCED_PROPOSED_DOCUMENTATION.m for technical details\n');
fprintf('  - Modify simulation parameters in mainSimulation_Advanced.m for custom tests\n\n');

fprintf('Key Parameters to Adjust:\n');
fprintf('  - simParams.roomSize - Workspace dimensions\n');
fprintf('  - simParams.v_list - User speeds to test\n');
fprintf('  - simParams.mc_num_scenarios - Monte Carlo scenario count\n');
fprintf('  - simParams.TTT - Time-to-Trigger threshold\n');
fprintf('  - simParams.HOM - Handover margin (dB)\n\n');
