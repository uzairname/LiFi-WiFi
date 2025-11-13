% Quick test for AdvancedProposed algorithm fix
clear; clc;

fprintf('Testing AdvancedProposed algorithm fix...\n\n');

% Setup
simParams.roomSize = [18, 18];
simParams.simDuration = 100;  % 100 seconds
simParams.dt = 0.1;
simParams.HOM = 2;
simParams.TTT = 0.160;
simParams.HHO_overhead = 0.200;
simParams.VHO_overhead = 0.500;

% Initialize
[apList, apParams] = initializeEnvironment_Advanced(simParams);

fprintf('Environment: %d APs\n\n', length(apList));

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

fprintf('Running 100-second test...\n');

% Run test
t_samples = 0:simParams.dt:simParams.simDuration;
for step = 1:length(t_samples)
    t = t_samples(step);
    
    if mod(step, 100) == 0
        fprintf('  Progress: %.0f s\n', t);
    end
    
    % Update position
    user = updateUserPosition_GMM(user, simParams.roomSize, simParams.dt, apList, all_sinr_dB);
    
    % Calculate SINR
    all_sinr_dB = calculateSINR(user.pos, apList, apParams);
    
    % Check handover with Advanced algorithm
    try
        [user, ho_event, counters] = checkHandover_AdvancedProposed(user, all_sinr_dB, apList, simParams, counters);
    catch ME
        fprintf('\n✗ ERROR: %s\n', ME.message);
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        return;
    end
    
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

fprintf('\n✓ SUCCESS! AdvancedProposed algorithm works!\n\n');
fprintf('Results:\n');
fprintf('  Total Handovers: %d (HHO: %d, VHO: %d)\n', counters.hho + counters.vho, counters.hho, counters.vho);
fprintf('  Handover Rate: %.3f HOs/s\n', (counters.hho + counters.vho) / simParams.simDuration);

if counters.active_samples > 0
    fprintf('  Average Throughput: %.2f Mbps\n', (counters.total_throughput / simParams.simDuration) / 1e6);
    fprintf('  Average SINR: %.2f dB\n', counters.total_sinr / counters.active_samples);
end

fprintf('\nReady to run mainSimulation_Advanced.m!\n');
