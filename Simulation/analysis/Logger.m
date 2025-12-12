classdef Logger < handle
    properties
        SpeedTag        % User speed tag for this logger (e.g., 'SLOW', 'FAST')
        SchemeTag       % Handover scheme tag for this logger (e.g., 'PROP', 'STD', 'NAIVE')
        Time
        UserPos
        
        % Properties tracked for this single simulation run
        HandoverEvents  % [Time, X, Y, FromAP, ToAP]
        ActiveSINR      % [SINR_Value] (N x 1)
        ActiveCapacity  % [Capacity_Value] (N x 1)
    end
    
    methods
        function obj = Logger(varargin)
            % Constructor: Initialize logger with optional speed and scheme tags
            % Usage:
            %   Logger()                    - Default tags
            %   Logger(scheme_tag)          - Only scheme tag
            %   Logger(speed_tag, scheme_tag) - Both tags
            
            p = inputParser;
            p.addOptional('speed_tag', 'DEFAULT_SPEED', @ischar);
            p.addOptional('scheme_tag', 'DEFAULT_SCHEME', @ischar);
            p.parse(varargin{:});
            
            % Handle backward compatibility: if only one arg, treat as scheme
            if nargin == 1
                obj.SpeedTag = 'DEFAULT_SPEED';
                obj.SchemeTag = p.Results.speed_tag;
            else
                obj.SpeedTag = p.Results.speed_tag;
                obj.SchemeTag = p.Results.scheme_tag;
            end
            
            obj.Time = [];
            obj.UserPos = [];
            obj.HandoverEvents = [];
            obj.ActiveSINR = [];
            obj.ActiveCapacity = [];
        end
        
        function logStep(obj, t, pos, sinr_val, capacity_val)
            % Log a single timestep with SINR and Capacity values
            
            obj.Time(end+1, 1) = t;
            obj.UserPos(end+1, :) = pos;
            obj.ActiveSINR(end+1, 1) = sinr_val;
            obj.ActiveCapacity(end+1, 1) = capacity_val;
        end
        
        function logHandover(obj, t, pos, from_ap, to_ap)
            % Log a handover event
            new_event = [t, pos(1), pos(2), double(from_ap), double(to_ap)];
            obj.HandoverEvents(end+1, :) = new_event;
        end
        
        % Helper to retrieve generic data
        function data = getTrace(obj, metricType)
            if strcmp(metricType, 'SINR')
                data = obj.ActiveSINR;
            elseif strcmp(metricType, 'Capacity')
                data = obj.ActiveCapacity;
            end
        end
        
        function events = getEvents(obj)
            events = obj.HandoverEvents;
        end
    end
end