% --- checkHandover_AdvancedProposed.m ---
% Implements the Advanced Proposed Handover Algorithm with Monte Carlo Optimization
% Features:
% - Monte Carlo Optimizer for evaluating thousands of handover scenarios
% - Real-time optimal transition strategy determination

function [user, ho_event, counters] = checkHandover_AdvancedProposed(user, all_sinr_dB, apList, simParams, counters)
    
    ho_event.type = 'None';
    current_sinr = all_sinr_dB(user.currentAP_idx);
    
    % Find the best AP in the entire network
    [best_sinr, best_idx] = max(all_sinr_dB);
    
    %% === PART 1: GAUSSIAN MIXTURE MODEL FOR MOBILITY ===
    % Predict future user position based on GMM velocity and direction model
    
    % Extract current velocity and direction from user state
    if ~isfield(user, 'velocity_vector')
        user.velocity_vector = [0, 0];  % Initial velocity
    end
    if ~isfield(user, 'gmm_coverage_zone')
        user.gmm_coverage_zone = -1;    % Current coverage zone (-1 = undetermined)
    end
    
    % Update velocity vector with some smoothing (first-order low-pass filter)
    vec_to_target = user.targetPos - user.pos;
    dist_to_target = norm(vec_to_target);
    if dist_to_target > 1e-6
        desired_velocity = (vec_to_target / dist_to_target) * user.speed;
        alpha_smooth = 0.1;  % Smoothing factor
        user.velocity_vector = alpha_smooth * desired_velocity + (1 - alpha_smooth) * user.velocity_vector;
    end
    
    % Determine current coverage zone using GMM logic
    % Divide the room into zones and assign GMM parameters
    user = updateCoverageZone(user, simParams);
    
    % Predict user position at future time horizons for Monte Carlo
    dt_horizon = simParams.dt;
    predicted_pos_near = user.pos + user.velocity_vector * dt_horizon;
    
    %% === PART 2: MONTE CARLO OPTIMIZER ===
    % Evaluate thousands of handover scenarios to find optimal transition strategy
    
    % Initialize Monte Carlo parameters (allow fast-mode override from simParams)
    % Default to simParams values when available, else fall back to embedded defaults
    if isfield(simParams, 'fastMode') && simParams.fastMode
        num_scenarios = simParams.fastNumScenarios;
        num_time_steps = simParams.fastNumTimeSteps;
        prediction_horizon = simParams.mc_prediction_horizon;
        fprintf('  [AdvancedProposed] FastMode enabled: scenarios=%d, time_steps=%d\n', num_scenarios, num_time_steps);
    else
        if isfield(simParams, 'mc_num_scenarios')
            num_scenarios = simParams.mc_num_scenarios;
        else
            num_scenarios = 5000;  % default full-run value
        end
        if isfield(simParams, 'mc_num_time_steps')
            num_time_steps = simParams.mc_num_time_steps;
        else
            num_time_steps = 50;
        end
        if isfield(simParams, 'mc_prediction_horizon')
            prediction_horizon = simParams.mc_prediction_horizon;
        else
            prediction_horizon = 2.0;
        end
    end
    
    % Pre-allocate scenario results
    best_handover_benefit = -Inf;
    best_target_ap = double(user.currentAP_idx(1));  % Ensure scalar
    scenario_scores = zeros(length(apList), 1);
    
    % Get list of candidate APs (top 5 by current SINR)
    [~, sorted_indices] = sort(all_sinr_dB, 'descend');
    candidate_aps = sorted_indices(1:min(5, length(sorted_indices)));
    
    % For each candidate AP, run Monte Carlo simulations
    for ap_candidate_idx = 1:length(candidate_aps)
        ap_candidate = double(candidate_aps(ap_candidate_idx));  % Ensure scalar
        
        if ap_candidate == user.currentAP_idx
            continue;  % Skip current AP
        end
        
        scenario_benefits = zeros(num_scenarios, 1);
        
        % Run Monte Carlo scenarios for this candidate AP
        for scenario = 1:num_scenarios
            % Generate stochastic mobility trajectory using GMM
            trajectory_sinr_candidate = zeros(num_time_steps, 1);
            trajectory_sinr_current = zeros(num_time_steps, 1);
            
            % Sample from GMM to get perturbed trajectories
            gmm_noise = randn(2, 1) * 0.5;  % Gaussian noise for uncertainty
            
            current_pos_scenario = user.pos;
            
            for time_step = 1:num_time_steps
                % Update position with velocity + GMM perturbation
                dt_mc = prediction_horizon / num_time_steps;
                gmm_perturbation = randn(2, 1) * (user.speed * 0.1);
                current_pos_scenario = current_pos_scenario + user.velocity_vector * dt_mc + gmm_perturbation;
                
                % Clamp position to room boundaries
                current_pos_scenario = max(0, min(current_pos_scenario, simParams.roomSize'));
                
                % Calculate SINR at this position for both APs
                sinr_at_candidate = calculateSINR_SingleAP(current_pos_scenario, apList(ap_candidate), simParams);
                sinr_at_current = calculateSINR_SingleAP(current_pos_scenario, apList(user.currentAP_idx), simParams);
                
                trajectory_sinr_candidate(time_step) = sinr_at_candidate;
                trajectory_sinr_current(time_step) = sinr_at_current;
            end
            
            % Calculate benefit score for this scenario
            % Metric 1: Average SINR gain
            avg_gain = mean(trajectory_sinr_candidate) - mean(trajectory_sinr_current);
            
            % Metric 2: Stability (low variance = stable connection)
            stability_current = std(trajectory_sinr_current);
            stability_candidate = std(trajectory_sinr_candidate);
            stability_score = stability_current - stability_candidate;  % Positive = more stable
            
            % Metric 3: Hysteresis margin compliance
            hysteresis_score = (mean(trajectory_sinr_candidate) - mean(trajectory_sinr_current)) - simParams.HOM;
            
            % Combined benefit score (weighted average)
            w_gain = 0.5;
            w_stability = 0.3;
            w_hysteresis = 0.2;
            
            scenario_benefits(scenario) = w_gain * avg_gain + w_stability * stability_score + w_hysteresis * hysteresis_score;
        end
        
        % Average benefit across all scenarios for this candidate AP
        mean_benefit = mean(scenario_benefits);
        scenario_scores(ap_candidate) = mean_benefit;
        
        % Track best candidate
        if mean_benefit > best_handover_benefit
            best_handover_benefit = mean_benefit;
            best_target_ap = double(ap_candidate);  % Ensure scalar
        end
    end
    
    %% === PART 3: HANDOVER DECISION ===
    % Make handover decision based on Monte Carlo results with TTT
    
    % Only consider handover if benefit is significant
    benefit_threshold = 2.0;  % dB improvement required
    
    % Ensure scalar comparison
    best_target_ap = double(best_target_ap);
    current_ap_idx = double(user.currentAP_idx);
    
    if best_target_ap ~= current_ap_idx && best_handover_benefit > benefit_threshold
        
        % Check penalty timer (avoid ping-ponging)
        if ~isfield(user, 'adv_penalty_timer')
            user.adv_penalty_timer = 0;
        end
        
        if user.adv_penalty_timer > 0
            user.adv_penalty_timer = user.adv_penalty_timer - simParams.dt;
        end
        
        % Time-to-Trigger logic
        if user.adv_penalty_timer <= 0
            if best_target_ap == user.adv_target_idx
                user.adv_timer = user.adv_timer + simParams.dt;
            else
                user.adv_target_idx = best_target_ap;
                user.adv_timer = simParams.dt;
            end
            
            % Perform handover if TTT condition met
            if user.adv_timer >= simParams.TTT
                old_AP_type = user.currentAP_type;
                
                % Update user's AP
                user.currentAP_idx = user.adv_target_idx;
                user.currentAP_type = apList(user.currentAP_idx).type;
                user.adv_sinr_baseline = all_sinr_dB(user.currentAP_idx);
                
                % Log the event
                if strcmp(old_AP_type, user.currentAP_type)
                    ho_event.type = 'HHO';
                    counters.hho = counters.hho + 1;
                else
                    ho_event.type = 'VHO';
                    counters.vho = counters.vho + 1;
                end
                
                % Set penalty timer to avoid immediate re-handover
                user.adv_penalty_timer = 0.5;
                
                % Reset timer state
                user.adv_timer = 0;
                user.adv_target_idx = -1;
            end
        end
    else
        % No beneficial handover, reset timers
        user.adv_timer = 0;
        user.adv_target_idx = -1;
    end
    
end

%% === HELPER FUNCTION: Update Coverage Zone ===
function user = updateCoverageZone(user, simParams)
    % Determine which coverage zone the user is in
    % Based on Gaussian Mixture Model with overlapping zones
    
    if ~isfield(user, 'adv_timer')
        user.adv_timer = 0;
    end
    if ~isfield(user, 'adv_target_idx')
        user.adv_target_idx = -1;
    end
    if ~isfield(user, 'adv_sinr_baseline')
        user.adv_sinr_baseline = 0;
    end
    
    % Divide room into 2x2 zones with GMM characteristics
    zone_size = simParams.roomSize / 2;
    
    % Determine which zone user is in
    zone_x = floor(user.pos(1) / zone_size(1)) + 1;
    zone_y = floor(user.pos(2) / zone_size(2)) + 1;
    zone_x = max(1, min(zone_x, 2));
    zone_y = max(1, min(zone_y, 2));
    zone_id = (zone_y - 1) * 2 + zone_x;
    
    user.gmm_coverage_zone = zone_id;
end

%% === HELPER FUNCTION: Calculate SINR for Single AP ===
function sinr_dB = calculateSINR_SingleAP(user_pos, ap_struct, simParams)
    % Calculate SINR for a single AP (simplified version)
    % ap_struct is a single AP struct from apList
    
    % Ensure we have scalar values extracted from the struct
    user_pos_2D = user_pos(1:2);
    
    % Extract AP position safely
    ap_pos = ap_struct.pos;
    if size(ap_pos, 2) >= 3
        ap_pos_2D = ap_pos(1:2);
    else
        ap_pos_2D = ap_pos(1:2);
    end
    
    % Calculate distance
    distance = norm(double(user_pos_2D) - double(ap_pos_2D));
    distance = max(distance, 0.1);  % Avoid division by zero
    
    % Get AP type - convert to string for comparison
    ap_type = ap_struct.type;
    if iscell(ap_type)
        ap_type = ap_type{1};
    end
    if isstring(ap_type)
        ap_type = string(ap_type);
    end
    
    % Extract TX power as scalar
    tx_power_val = ap_struct.tx_power;
    if ~isscalar(tx_power_val)
        tx_power_val = tx_power_val(1);
    end
    tx_power_val = double(tx_power_val);
    
    % Select path loss exponent based on AP type
    if contains(ap_type, 'LiFi')
        path_loss_exp = 2;  % LiFi: -20 dB per decade
    else
        path_loss_exp = 4;  % WiFi: -40 dB per decade
    end
    
    % Calculate received power
    d0 = 1.0;  % Reference distance in meters
    rx_power = tx_power_val - 10 * path_loss_exp * log10(distance / d0);
    
    % Calculate noise power
    if contains(ap_type, 'LiFi')
        noise_power = -80;  % dBm for LiFi
    else
        noise_power = -100;  % dBm for WiFi
    end
    
    % Simple SINR calculation (assume minimal interference)
    sinr_linear = 10^((rx_power - noise_power) / 10);
    sinr_dB = 10 * log10(max(sinr_linear, 1e-10));
    
    % Ensure valid SINR
    if ~isfinite(sinr_dB)
        sinr_dB = -50;
    end
end
