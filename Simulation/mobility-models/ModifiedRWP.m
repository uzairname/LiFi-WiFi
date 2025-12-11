classdef ModifiedRWP < MobilityModel
    % Implementation of Modified Random Waypoint (Excursion-based)
    
    properties
        RoomLimits      % [x_max, y_max]
        SpeedRange      % [min_speed, max_speed] e.g., [0, 5]
        ExcursionRange  % [min_time, max_time] e.g., [10, 20]
        
        % Internal State
        TargetPos
        TimeRemaining
    end
    
    methods
        function obj = ModifiedRWP(roomSize, speedRange)
            obj.RoomLimits = roomSize;
            obj.SpeedRange = speedRange;
            obj.ExcursionRange = [10, 20]; % Default excursion
            
            % Initialize random start
            obj.CurrentPos = rand(1, 2) .* obj.RoomLimits;
            obj.pickNewExcursion();
        end
        
        function pos = step(obj, dt)
            % Update position
            obj.CurrentPos = obj.CurrentPos + obj.CurrentVel * dt;
            obj.TimeRemaining = obj.TimeRemaining - dt;
            
            % Check if excursion ended or hit wall
            if obj.TimeRemaining <= 0 || obj.checkBounds()
                obj.CurrentPos = max(0, min(obj.RoomLimits, obj.CurrentPos)); % Clip
                obj.pickNewExcursion();
            end
            
            pos = obj.CurrentPos;
        end
        
        function hit = checkBounds(obj)
            hit = any(obj.CurrentPos <= 0) || any(obj.CurrentPos >= obj.RoomLimits);
        end
        
        function pickNewExcursion(obj)
            % 1. Pick new target waypoint
            obj.TargetPos = rand(1, 2) .* obj.RoomLimits;
            
            % 2. Pick new constant speed
            speed = obj.SpeedRange(1) + rand() * diff(obj.SpeedRange);
            
            % 3. Calculate Velocity Vector
            direction = obj.TargetPos - obj.CurrentPos;
            dist = norm(direction);
            
            if dist > 0
                obj.CurrentVel = (direction / dist) * speed;
            else
                obj.CurrentVel = [0, 0];
            end
            
            % 4. Determine duration (dist/speed or random excursion time)
            % Paper implies constant speed for a "period"
            duration = obj.ExcursionRange(1) + rand() * diff(obj.ExcursionRange);
            
            % Cap duration to actually reaching the target if needed, 
            % but RWP usually implies moving Towards target for time T.
            obj.TimeRemaining = duration;
        end
    end
end