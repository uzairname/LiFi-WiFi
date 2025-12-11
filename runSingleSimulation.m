% --- runSingleSimulation.m ---
function [results, counters] = runSingleSimulation(simParams, apList, apParams, speed, algorithm)
    % Runs a single simulation for given speed and algorithm
    %
    % Inputs:
    %   simParams - Simulation parameters struct
    %   apList    - Array of AP structures
    %   apParams  - AP parameters
    %   speed     - User speed in m/s
    %   algorithm - 'STD' or 'Proposed'
    %
    % Outputs:
    %   results   - Struct with performance metrics
    %   counters  - Detailed counters for analysis
    
    % Initialize counters
    counters.hho = 0;
    counters.vho = 0;
    counters.total_throughput = 0; % Sum of throughput over time
    counters.total_sinr = 0;       % Sum of SINR over time
    counters.active_samples = 0;   % Number of samples when user is active (not in handover)
    counters.handover_time = 0;    % Time spent in handover
    
    % Initialize user state
    user.pos = simParams.roomSize / 2; % Start in the middle
    user.speed = speed;
    user.targetPos = rand(1, 2) .* simParams.roomSize; % First random waypoint
    user.in_handover = false;      % Flag to track if user is in handover
    user.handover_end_time = 0;    % When handover will complete
    
    % Connect user to the strongest AP at the start
    all_sinr_dB = calculateSINR(user.pos, apList, apParams);
    [~, user.currentAP_idx] = max(all_sinr_dB);
    user.currentAP_type = apList(user.currentAP_idx).type;
    
    % Initialize algorithm-specific state
    if strcmp(algorithm, 'STD')
        user.std_timer = 0;
        user.std_target_idx = -1;
    elseif strcmp(algorithm, 'Proposed')
        user.prop_timer = 0;
        user.prop_target_idx = -1;
        user.prev_sinr_dB = all_sinr_dB; % For Δγ calculation
        user.prop_penalty_timer = 0;
    end
    
    % Animation setup (optional)
    if isfield(simParams, 'animate') && simParams.animate
        fig = figure('Name', sprintf('%s - v=%.1f m/s', algorithm, speed), 'NumberTitle', 'off');
        axis([0 simParams.roomSize(1) 0 simParams.roomSize(2)]);
        axis equal; hold on;
        xlabel('X [m]'); ylabel('Y [m]');
        title(sprintf('%s Algorithm - Speed: %.1f m/s', algorithm, speed));
        
        % Plot APs
        lifi_idx = find(arrayfun(@(a) strcmp(a.type, 'LiFi'), apList));
        wifi_idx = find(arrayfun(@(a) strcmp(a.type, 'WiFi'), apList));
        lifi_pos = vertcat(apList(lifi_idx).pos);
        wifi_pos = vertcat(apList(wifi_idx).pos);
        
        scatter(lifi_pos(:,1), lifi_pos(:,2), 100, [0.8 0.6 1], 's', 'filled', 'DisplayName', 'LiFi APs');
        scatter(wifi_pos(:,1), wifi_pos(:,2), 120, [0.1 0.6 0.9], '^', 'filled', 'DisplayName', 'WiFi APs');
        
        % Current AP marker
        hCurrentAP = plot(apList(user.currentAP_idx).pos(1), apList(user.currentAP_idx).pos(2), ...
                          'ko', 'MarkerSize', 14, 'LineWidth', 2.5, 'DisplayName', 'Current AP');
        
        % User marker and trail
        hUser = plot(user.pos(1), user.pos(2), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'DisplayName', 'User');
        userTrailX = user.pos(1);
        userTrailY = user.pos(2);
        hTrail = plot(userTrailX, userTrailY, 'r-', 'LineWidth', 1, 'DisplayName', 'User Path');
        
        % Text info
        hText = text(0.02*simParams.roomSize(1), 0.95*simParams.roomSize(2), '', ...
                     'FontSize', 10, 'BackgroundColor', 'w', 'EdgeColor', 'k');
        
        legend('Location', 'southeast');
        drawnow;
        
        % Decide update frequency in steps
        animUpdateEvery = max(1, round(simParams.animate_update_interval / simParams.dt));
    end
    
    % --- Time Loop ---
    t_samples = 0:simParams.dt:simParams.simDuration;
    
    for step = 1:length(t_samples)
        t = t_samples(step);
        
        % Progress indicator (every 10 seconds)
        if mod(t, 10) < simParams.dt
            fprintf('    Time: %.1f / %.1f s\n', t, simParams.simDuration);
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
        if strcmp(algorithm, 'STD')
            [user, ho_event, counters] = checkHandover_STD(user, all_sinr_dB, apList, simParams, counters);
        elseif strcmp(algorithm, 'Proposed')
            [user, ho_event, counters] = checkHandover_Proposed(user, all_sinr_dB, apList, simParams, counters);
        else
            error('Unknown algorithm: %s', algorithm);
        end
        
        % 6. If handover occurred, set handover state
        if strcmp(ho_event.type, 'HHO')
            user.in_handover = true;
            user.handover_end_time = t + simParams.HHO_overhead;
        elseif strcmp(ho_event.type, 'VHO')
            user.in_handover = true;
            user.handover_end_time = t + simParams.VHO_overhead;
        end
        
        % 7. Update animation (if enabled)
        if isfield(simParams, 'animate') && simParams.animate && mod(step, animUpdateEvery) == 0
            % Update user marker and trail
            userTrailX(end+1) = user.pos(1); %#ok<AGROW>
            userTrailY(end+1) = user.pos(2); %#ok<AGROW>
            set(hUser, 'XData', user.pos(1), 'YData', user.pos(2));
            set(hTrail, 'XData', userTrailX, 'YData', userTrailY);
            
            % Update current AP marker
            set(hCurrentAP, 'XData', apList(user.currentAP_idx).pos(1), ...
                           'YData', apList(user.currentAP_idx).pos(2));
            
            % Update info text
            infoStr = sprintf(['Time: %.1f s\n' ...
                              'Speed: %.2f m/s\n' ...
                              'Current AP: %d (%s)\n' ...
                              'SINR: %.1f dB\n' ...
                              'HHO: %d | VHO: %d\n' ...
                              'In HO: %s'], ...
                              t, user.speed, user.currentAP_idx, user.currentAP_type, ...
                              all_sinr_dB(user.currentAP_idx), ...
                              counters.hho, counters.vho, ...
                              string(user.in_handover));
            set(hText, 'String', infoStr);
            drawnow limitrate;
        end
    end
    
    % Close animation figure if it was created
    if isfield(simParams, 'animate') && simParams.animate
        % Keep figure open for inspection or close after delay
        if isfield(simParams, 'animate_keep_open') && simParams.animate_keep_open
            % Keep open
        else
            pause(2); % Brief pause to see final state
            close(fig);
        end
    end
    
    % Calculate final results
    results.speed = speed;
    results.hho_rate = counters.hho / simParams.simDuration;
    results.vho_rate = counters.vho / simParams.simDuration;
    results.total_ho_rate = (counters.hho + counters.vho) / simParams.simDuration;
    
    % Calculate average throughput in Mbps
    if counters.active_samples > 0
        results.avg_throughput_mbps = (counters.total_throughput / simParams.simDuration) / 1e6;
        results.avg_sinr_dB = counters.total_sinr / counters.active_samples;
    else
        results.avg_throughput_mbps = 0;
        results.avg_sinr_dB = -Inf;
    end
    
    results.handover_time = counters.handover_time;
    results.handover_time_percent = 100 * counters.handover_time / simParams.simDuration;
    
    % Print summary
    fprintf('    HO Count: %d (HHO: %d, VHO: %d)\n', counters.hho + counters.vho, counters.hho, counters.vho);
    fprintf('    HO Time: %.2f s (%.1f%%)\n', results.handover_time, results.handover_time_percent);
    fprintf('    Avg Throughput: %.2f Mbps\n', results.avg_throughput_mbps);
    fprintf('    Avg SINR: %.2f dB\n\n', results.avg_sinr_dB);
end
