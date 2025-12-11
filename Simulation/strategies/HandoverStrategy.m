classdef (Abstract) HandoverStrategy < handle
    % Abstract base class for handover strategies
    
    methods
        function obj = HandoverStrategy()
        end
    end
    
    methods (Abstract)
        % Main decision function
        % Inputs:
        %   current_t: current simulation time
        %   serving_ap: index of currently connected AP
        %   measurements: struct containing .SINR (array) and history
        % Returns:
        %   target_ap: index of new AP (or same as serving_ap if no HO)
        target_ap = decideHandover(obj, current_t, serving_ap, measurements);
    end
end
