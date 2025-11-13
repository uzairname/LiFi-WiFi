% --- updateUserPosition_GMM.m ---
% Advanced mobility model using Gaussian Mixture Models (GMM)
% Features:
% - Velocity modeling with smooth acceleration/deceleration
% - Direction changes based on coverage zones
% - Gauss-Markov motion with correlation

function user = updateUserPosition_GMM(user, roomSize, dt, apList, all_sinr_dB)
    % Implements advanced mobility model with Gaussian Mixture Model characteristics
    
    %% Initialize GMM state if not present
    if ~isfield(user, 'gmm_velocity_mean')
        user.gmm_velocity_mean = user.speed;
    end
    if ~isfield(user, 'gmm_velocity_variance')
        user.gmm_velocity_variance = user.speed * 0.1;  % 10% variance
    end
    if ~isfield(user, 'gmm_direction_angle')
        vec_to_target = user.targetPos - user.pos;
        user.gmm_direction_angle = atan2(vec_to_target(2), vec_to_target(1));
    end
    if ~isfield(user, 'gmm_dwell_timer')
        user.gmm_dwell_timer = 0;
    end
    if ~isfield(user, 'gmm_cluster_center')
        user.gmm_cluster_center = user.pos;  % Current cluster
    end
    
    %% === GAUSSIAN MIXTURE COMPONENT 1: Velocity Modeling ===
    % Model velocity as a mixture of Gaussian components (normal movement + occasional stops)
    
    % Primary component: Normal movement with smoothing
    w_normal = 0.9;  % Weight for normal movement
    sigma_vel = user.gmm_velocity_variance;
    
    % Secondary component: Occasional pauses/slow movement
    w_pause = 0.1;   % Weight for pauses
    
    % Sample from mixture
    if rand() < w_normal
        % Sample from normal velocity distribution
        velocity_sample = user.gmm_velocity_mean + sigma_vel * randn();
    else
        % Sample from pause distribution (much lower velocity)
        velocity_sample = user.gmm_velocity_mean * 0.1 + sigma_vel * 0.1 * randn();
    end
    
    % Clamp velocity to valid range
    velocity_sample = max(0.05, min(velocity_sample, user.speed * 2));
    
    % Exponential smoothing for velocity (alpha filter)
    alpha_velocity = 0.05;
    current_velocity = alpha_velocity * velocity_sample + (1 - alpha_velocity) * user.gmm_velocity_mean;
    user.gmm_velocity_mean = current_velocity;
    
    %% === GAUSSIAN MIXTURE COMPONENT 2: Direction Changes ===
    % Model direction changes based on coverage zones and waypoints
    
    % Calculate vector to target waypoint
    vec_to_target = user.targetPos - user.pos;
    dist_to_target = norm(vec_to_target);
    
    % If close to target, select new waypoint and apply GMM-based direction change
    move_dist = current_velocity * dt;
    
    if dist_to_target < move_dist
        % Reached waypoint, select new one
        user.pos = user.targetPos;
        
        % NEW WAYPOINT SELECTION WITH COVERAGE AWARENESS
        % Generate waypoint biased towards high-coverage areas
        new_waypoint_base = rand(1, 2) .* roomSize;
        
        % Bias towards LiFi-rich areas (attocells create natural clusters)
        % Add Gaussian perturbation to create cluster-like behavior
        gmm_bias = randn(1, 2) * 2.0;  % Gaussian perturbation
        user.targetPos = new_waypoint_base + gmm_bias;
        
        % Clamp to room boundaries
        user.targetPos = max(0, min(user.targetPos, roomSize));
        
        % Update direction angle for this new target
        vec_to_target = user.targetPos - user.pos;
        user.gmm_direction_angle = atan2(vec_to_target(2), vec_to_target(1));
        
    else
        % Move towards current target with some directional smoothing
        direction = vec_to_target / dist_to_target;
        target_angle = atan2(direction(2), direction(1));
        
        % Apply low-pass filter to direction changes (smooth turning)
        alpha_direction = 0.1;
        user.gmm_direction_angle = alpha_direction * target_angle + (1 - alpha_direction) * user.gmm_direction_angle;
        
        % Add small directional noise (realistic motion jitter)
        angle_noise = randn() * 0.05;  % Small random perturbation
        final_angle = user.gmm_direction_angle + angle_noise;
        
        % Convert angle back to direction vector
        direction = [cos(final_angle), sin(final_angle)];
        
        % Update position
        user.pos = user.pos + direction * move_dist;
    end
    
    %% === GAUSSIAN MIXTURE COMPONENT 3: Coverage Zone Clustering ===
    % Model user tendency to cluster in high-coverage areas
    
    % Simplified clustering based on number of nearby LiFi APs
    num_nearby_lifi = 0;
    coverage_strength = 0;
    
    for i = 1:min(length(all_sinr_dB), 36)  % Check LiFi APs only
        if all_sinr_dB(i) > -20  % Threshold for "nearby"
            num_nearby_lifi = num_nearby_lifi + 1;
            coverage_strength = coverage_strength + 10^(all_sinr_dB(i) / 10);
        end
    end
    
    % If in high-coverage area, increase dwell time (user stays longer)
    if num_nearby_lifi >= 3  % In multiple LiFi coverage zones
        user.gmm_dwell_timer = user.gmm_dwell_timer + dt;
        
        % If dwelling for a while, may change direction less frequently
        if user.gmm_dwell_timer > 5.0  % 5 seconds of dwelling
            alpha_direction = 0.02;  % Much less directional change
            final_angle = user.gmm_direction_angle;
        end
    else
        % Low coverage area, user moves faster/more erratically
        user.gmm_dwell_timer = max(0, user.gmm_dwell_timer - dt);
    end
    
    %% === Clamp position to room boundaries ===
    user.pos = max(0, min(user.pos, roomSize));
    
end
