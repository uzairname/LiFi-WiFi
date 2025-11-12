% Test script to verify code structure before full simulation
% Run this to check for syntax errors

clear; clc;

fprintf('Testing code structure...\n\n');

% Test 1: Check all functions exist
fprintf('1. Checking function files exist:\n');
functions_to_check = {'mainSimulation.m', 'calculateSINR.m', 'initializeEnvironment.m', ...
                      'checkHandover_STD.m', 'checkHandover_Proposed.m', 'updateUserPosition.m'};

for i = 1:length(functions_to_check)
    if isfile(functions_to_check{i})
        fprintf('   ✓ %s found\n', functions_to_check{i});
    else
        fprintf('   ✗ %s NOT FOUND\n', functions_to_check{i});
    end
end

% Test 2: Basic parameter check
fprintf('\n2. Testing basic simulation parameters:\n');
simParams.roomSize = [15, 15];
simParams.simDuration = 3600;
simParams.dt = 0.1;
simParams.v_list = [0.1, 1.5, 5.0, 10.0];
simParams.HOM = 1;
simParams.TTT = 0.160;
simParams.HHO_overhead = 0.200;
simParams.VHO_overhead = 0.500;

fprintf('   Room size: %.1f x %.1f m\n', simParams.roomSize(1), simParams.roomSize(2));
fprintf('   Simulation duration: %.0f seconds (%.1f hours)\n', simParams.simDuration, simParams.simDuration/3600);
fprintf('   Time step: %.3f seconds\n', simParams.dt);
fprintf('   Total time steps: %.0f\n', simParams.simDuration/simParams.dt);
fprintf('   Test speeds: %s\n', sprintf('%.1f ', simParams.v_list));

% Test 3: Try to initialize environment
fprintf('\n3. Initializing environment:\n');
try
    [apList, apParams] = initializeEnvironment(simParams);
    fprintf('   ✓ Environment initialized successfully\n');
    fprintf('   Total APs: %d (LiFi: %d, WiFi: %d)\n', length(apList), apParams.numLiFi, apParams.numWiFi);
    fprintf('   LiFi frequency reuse factor: %d\n', apParams.freqReuseFactorLiFi);
catch ME
    fprintf('   ✗ Error initializing environment:\n');
    fprintf('     %s\n', ME.message);
end

% Test 4: Try SINR calculation
fprintf('\n4. Testing SINR calculation:\n');
try
    user_pos = simParams.roomSize / 2;
    sinr_dB = calculateSINR(user_pos, apList, apParams);
    fprintf('   ✓ SINR calculation successful\n');
    fprintf('   Calculated SINRs for %d APs\n', length(sinr_dB));
    fprintf('   SINR range: %.2f to %.2f dB\n', min(sinr_dB), max(sinr_dB));
    fprintf('   Best AP index: %d (Type: %s)\n', find(sinr_dB==max(sinr_dB)), apList(find(sinr_dB==max(sinr_dB))).type);
catch ME
    fprintf('   ✗ Error in SINR calculation:\n');
    fprintf('     %s\n', ME.message);
end

% Test 5: Try user position update
fprintf('\n5. Testing user position update:\n');
try
    user.pos = simParams.roomSize / 2;
    user.speed = 1.5;
    user.targetPos = rand(1, 2) .* simParams.roomSize;
    
    user_old = user;
    user = updateUserPosition(user, simParams.roomSize, simParams.dt);
    
    move_distance = norm(user.pos - user_old.pos);
    expected_distance = user_old.speed * simParams.dt;
    
    fprintf('   ✓ Position update successful\n');
    fprintf('   Movement distance: %.6f m (expected: %.6f m)\n', move_distance, expected_distance);
catch ME
    fprintf('   ✗ Error in position update:\n');
    fprintf('     %s\n', ME.message);
end

% Test 6: Check handover algorithms
fprintf('\n6. Testing handover algorithms:\n');
try
    % Test STD algorithm
    user.currentAP_idx = 1;
    user.currentAP_type = 'LiFi';
    user.std_timer = 0;
    user.std_target_idx = -1;
    counters.hho = 0;
    counters.vho = 0;
    ho_event_std.type = 'None';
    
    [user_std, ho_event, counters] = checkHandover_STD(user, sinr_dB, apList, simParams, counters);
    fprintf('   ✓ STD algorithm test passed\n');
    
    % Test Proposed algorithm
    user.currentAP_idx = 1;
    user.currentAP_type = 'LiFi';
    user.prop_timer = 0;
    user.prop_target_idx = -1;
    user.prop_sinr_0 = sinr_dB(1);
    user.prop_penalty_timer = 0;
    counters.hho = 0;
    counters.vho = 0;
    
    [user_prop, ho_event, counters] = checkHandover_Proposed(user, sinr_dB, apList, simParams, counters);
    fprintf('   ✓ Proposed algorithm test passed\n');
    
catch ME
    fprintf('   ✗ Error in handover algorithm:\n');
    fprintf('     %s\n', ME.message);
end

fprintf('\n========================================\n');
fprintf('All basic tests completed!\n');
fprintf('Code structure appears valid.\n');
fprintf('You can now run mainSimulation.m for full testing.\n');
fprintf('========================================\n');
