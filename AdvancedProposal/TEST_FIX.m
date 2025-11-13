% Quick test to verify the fix
clear; clc;

fprintf('Testing fixed calculateSINR with new workspace...\n\n');

% Setup
simParams.roomSize = [18, 18];
simParams.roomHeight = 3;
simParams.dt = 0.1;
simParams.v_list = [0.5];  % Just one speed
simParams.HOM = 2;
simParams.TTT = 0.160;
simParams.HHO_overhead = 0.200;
simParams.VHO_overhead = 0.500;

% Initialize environment
[apList, apParams] = initializeEnvironment_Advanced(simParams);

fprintf('Environment initialized:\n');
fprintf('  - %d LiFi APs\n', apParams.numLiFi);
fprintf('  - %d WiFi APs\n', apParams.numWiFi);
fprintf('  - Total: %d APs\n\n', length(apList));

% Test user position (2D)
user_pos = simParams.roomSize / 2;
fprintf('User position: [%.1f, %.1f]\n', user_pos(1), user_pos(2));

% Test calculateSINR
fprintf('Calculating SINR...\n');
try
    all_sinr_dB = calculateSINR(user_pos, apList, apParams);
    fprintf('✓ SUCCESS! SINR calculated for %d APs\n\n', length(all_sinr_dB));
    
    % Find best AP
    [best_sinr, best_idx] = max(all_sinr_dB);
    fprintf('Best AP: %d (%s) with SINR = %.2f dB\n', best_idx, apList(best_idx).type, best_sinr);
    
    % Show top 5 APs
    [sorted_sinr, sorted_idx] = sort(all_sinr_dB, 'descend');
    fprintf('\nTop 5 APs:\n');
    for i = 1:min(5, length(sorted_idx))
        fprintf('  %d. AP %d (%s): %.2f dB\n', i, sorted_idx(i), apList(sorted_idx(i)).type, sorted_sinr(i));
    end
    
    fprintf('\n✓ Fix verified! Ready to run mainSimulation_Advanced.m\n');
    
catch ME
    fprintf('✗ ERROR: %s\n', ME.message);
    fprintf('Location: %s\n', ME.stack(1).name);
end
