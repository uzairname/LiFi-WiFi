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
        
        function rate = getHandoverRate(obj)
            % Calculate handover rate (handovers per second)
            % Returns: Total handover rate (/s)
            
            if isempty(obj.Time)
                rate = 0;
                return;
            end
            
            total_duration = obj.Time(end) - obj.Time(1);
            total_handovers = size(obj.HandoverEvents, 1);
            
            if total_duration > 0
                rate = total_handovers / total_duration;
            else
                rate = 0;
            end
        end
        
        function [hho_count, vho_count, hho_rate, vho_rate] = classifyHandovers(obj, env)
            % Classify handovers as HHO (Horizontal) or VHO (Vertical)
            % HHO: LiFi-to-LiFi or WiFi-to-WiFi
            % VHO: LiFi-to-WiFi or WiFi-to-LiFi
            % 
            % Inputs:
            %   env: Simulation environment object (to access AP types)
            % 
            % Returns:
            %   hho_count: Number of horizontal handovers
            %   vho_count: Number of vertical handovers
            %   hho_rate: HHO rate (/s)
            %   vho_rate: VHO rate (/s)
            
            hho_count = 0;
            vho_count = 0;
            
            if isempty(obj.HandoverEvents)
                hho_rate = 0;
                vho_rate = 0;
                return;
            end
            
            % Calculate duration
            if isempty(obj.Time)
                duration = 1;  % Avoid division by zero
            else
                duration = obj.Time(end) - obj.Time(1);
                if duration <= 0
                    duration = 1;
                end
            end
            
            % Classify each handover event
            for i = 1:size(obj.HandoverEvents, 1)
                from_ap_id = obj.HandoverEvents(i, 4);
                to_ap_id = obj.HandoverEvents(i, 5);
                
                % Get AP types from environment
                from_type = env.APs(from_ap_id).Type;  % 1=LiFi, 2=WiFi
                to_type = env.APs(to_ap_id).Type;
                
                % Classify
                if from_type == to_type
                    % Same technology: Horizontal Handover (HHO)
                    hho_count = hho_count + 1;
                else
                    % Different technology: Vertical Handover (VHO)
                    vho_count = vho_count + 1;
                end
            end
            
            % Calculate rates
            hho_rate = hho_count / duration;
            vho_rate = vho_count / duration;
        end
    end
end