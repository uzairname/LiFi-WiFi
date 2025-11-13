% Quick 5-minute test of mainSimulation_Advanced
clear; clc; close all;

fprintf('========================================\n');
fprintf('QUICK TEST - Advanced Simulation\n');
fprintf('========================================\n\n');

% Modified parameters for quick test
simParams.roomSize = [18, 18];
simParams.roomHeight = 3;
simParams.simDuration = 300;  % 5 minutes only (was 3600)
simParams.dt = 0.1;
simParams.v_list = [1.5];     % Only test 1.5 m/s
simParams.HOM = 2;
simParams.TTT = 0.160;
simParams.HHO_overhead = 0.200;
simParams.VHO_overhead = 0.500;

fprintf('Configuration:\n');
fprintf('  Workspace: 18x18x3m\n');
fprintf('  Simulation: %d seconds (%.1f minutes)\n', simParams.simDuration, simParams.simDuration/60);
fprintf('  Speed tested: %.1f m/s\n', simParams.v_list(1));
fprintf('  Algorithms: STD only (for quick test)\n\n');

% Initialize environment
[apList, apParams] = initializeEnvironment_Advanced(simParams);
fprintf('Environment: %d LiFi + %d WiFi = %d total APs\n\n', apParams.numLiFi, apParams.numWiFi, length(apList));

% Run quick test with STD only
v = simParams.v_list(1);
fprintf('Running simulation at %.1f m/s...\n\n', v);

% Initialize counters
counters.hho = 0;
counters.vho = 0;
counters.total_throughput = 0;
counters.total_sinr = 0;
counters.active_samples = 0;
counters.handover_time = 0;

% Initialize user
user.pos = simParams.roomSize / 2;
user.speed = v;
user.targetPos = rand(1, 2) .* simParams.roomSize;
user.in_handover = false;
user.handover_end_time = 0;
user.std_timer = 0;
user.std_target_idx = -1;

% Initial AP connection
all_sinr_dB = calculateSINR(user.pos, apList, apParams);
[~, user.currentAP_idx] = max(all_sinr_dB);
user.currentAP_type = apList(user.currentAP_idx).type;

% Time loop
t_samples = 0:simParams.dt:simParams.simDuration;
for step = 1:length(t_samples)
    t = t_samples(step);
    
    % Progress
    if mod(step, 100) == 0
        progress_pct = 100 * step / length(t_samples);
        fprintf('  Progress: %.1f%% (%.1f s / %.1f s)\n', progress_pct, t, simParams.simDuration);
    end
    
    % Update position
    user = updateUserPosition(user, simParams.roomSize, simParams.dt);
    
    % Calculate SINR
    all_sinr_dB = calculateSINR(user.pos, apList, apParams);
    
    % Check handover state
    if user.in_handover && t >= user.handover_end_time
        user.in_handover = false;
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
    else
        counters.handover_time = counters.handover_time + simParams.dt;
    end
    
    % Check for handover
    [user, ho_event, counters] = checkHandover_STD(user, all_sinr_dB, apList, simParams, counters);
    
    % Handle handover
    if strcmp(ho_event.type, 'HHO')
        user.in_handover = true;
        user.handover_end_time = t + simParams.HHO_overhead;
    elseif strcmp(ho_event.type, 'VHO')
        user.in_handover = true;
        user.handover_end_time = t + simParams.VHO_overhead;
    end
end

% Display results
fprintf('\n========================================\n');
fprintf('RESULTS\n');
fprintf('========================================\n\n');
fprintf('Total Handovers: %d (HHO: %d, VHO: %d)\n', counters.hho + counters.vho, counters.hho, counters.vho);
fprintf('Handover Rate: %.3f HOs/s\n', (counters.hho + counters.vho) / simParams.simDuration);
fprintf('Handover Time: %.1f s (%.1f%%)\n', counters.handover_time, 100*counters.handover_time/simParams.simDuration);

if counters.active_samples > 0
    fprintf('Average Throughput: %.2f Mbps\n', (counters.total_throughput / simParams.simDuration) / 1e6);
    fprintf('Average SINR: %.2f dB\n\n', counters.total_sinr / counters.active_samples);
end

fprintf('✓ Quick test completed successfully!\n');
fprintf('Ready to run: mainSimulation_Advanced\n');
