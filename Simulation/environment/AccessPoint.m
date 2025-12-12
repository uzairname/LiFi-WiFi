classdef AccessPoint < handle
    % AccessPoint: Represents a single access point in the network
    
    properties
        ID          % Unique identifier
        Position    % [x, y, z] coordinates
        Type        % 1 = LiFi, 2 = WiFi
        TxPower     % Transmission power (Watts)
    end
    
    methods
        function obj = AccessPoint(id, position, type, txPower)
            % Constructor
            % Inputs:
            %   id: Unique identifier (integer)
            %   position: [x, y, z] coordinates
            %   type: 1 (LiFi) or 2 (WiFi)
            %   txPower: Transmission power in Watts
            
            obj.ID = id;
            obj.Position = position;
            obj.Type = type;
            obj.TxPower = txPower;
        end
        
        function is_lifi = isLiFi(obj)
            % Check if this AP is LiFi
            is_lifi = (obj.Type == 1);
        end
        
        function is_wifi = isWiFi(obj)
            % Check if this AP is WiFi
            is_wifi = (obj.Type == 2);
        end
    end
end
