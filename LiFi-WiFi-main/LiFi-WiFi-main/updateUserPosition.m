% --- updateUserPosition.m ---
function user = updateUserPosition(user, roomSize, dt)
    % Implements the Random Waypoint (RWP) mobility model [cite: 81]
    
    % Calculate distance and direction to target
    vec_to_target = user.targetPos - user.pos;
    dist_to_target = norm(vec_to_target);
    
    % Check if user has reached the target
    move_dist = user.speed * dt;
    if dist_to_target < move_dist
        % Reached target, pick a new random waypoint
        user.pos = user.targetPos;
        user.targetPos = rand(1, 2) .* roomSize;
    else
        % Move towards target
        direction = vec_to_target / dist_to_target; % Normalized vector
        user.pos = user.pos + (direction * move_dist);
    end
end