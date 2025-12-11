classdef (Abstract) MobilityModel < handle
    % Abstract base class for user mobility models
    properties
        CurrentPos  % [x, y]
        CurrentVel  % [vx, vy]
    end

    methods (Abstract)
        % Updates position based on dt and returns new position
        pos = step(obj, dt);
    end
end
