classdef Logger < handle
    properties
        Time
        UserPos
        
        % Properties tracked for different strategies, as key-values
        HandoverEvents  % Map: String -> [Time, X, Y, FromAP, ToAP]
        ActiveSINR      % Map: String -> [SINR_Value] (N x 1)
        ActiveCapacity  % Map: String -> [Capacity_Value] (N x 1)
    end
    
    methods
        function obj = Logger()
            obj.Time = [];
            obj.UserPos = [];
            
            % Initialize Containers
            obj.HandoverEvents = containers.Map();
            obj.ActiveSINR = containers.Map();
            obj.ActiveCapacity = containers.Map();
        end
        
        function initStrategy(obj, tag)
            obj.HandoverEvents(tag) = [];
            obj.ActiveSINR(tag) = [];
            obj.ActiveCapacity(tag) = [];
        end
        
        function logStep(obj, t, pos, strategy_data)
            % strategy_data: Struct where field names are tags (e.g., data.STD)
            % containing {SINR, Capacity}
            
            obj.Time(end+1, 1) = t;
            obj.UserPos(end+1, :) = pos;
            
            tags = fieldnames(strategy_data);
            for i = 1:length(tags)
                tag = tags{i};
                vals = strategy_data.(tag); % Expecting [SINR, Capacity]
                
                % Append to existing arrays in Map
                obj.ActiveSINR(tag) = [obj.ActiveSINR(tag); vals(1)];
                obj.ActiveCapacity(tag) = [obj.ActiveCapacity(tag); vals(2)];
            end
        end
        
        function logHandover(obj, tag, t, pos, from_ap, to_ap)
            new_event = [t, pos(1), pos(2), double(from_ap), double(to_ap)];
            
            if isKey(obj.HandoverEvents, tag)
                obj.HandoverEvents(tag) = [obj.HandoverEvents(tag); new_event];
            else
                obj.HandoverEvents(tag) = new_event;
            end
        end
        
        % Helper to retrieve generic data
        function data = getTrace(obj, tag, metricType)
            if strcmp(metricType, 'SINR')
                data = obj.ActiveSINR(tag);
            elseif strcmp(metricType, 'Capacity')
                data = obj.ActiveCapacity(tag);
            end
        end
        
        function events = getEvents(obj, tag)
            events = obj.HandoverEvents(tag);
        end
    end
end