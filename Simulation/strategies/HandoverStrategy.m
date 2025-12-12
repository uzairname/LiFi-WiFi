classdef (Abstract) HandoverStrategy < handle
    % Abstract base class for handover strategies
    methods
        function obj = HandoverStrategy()
        end
    end
    
    methods (Abstract)
        target_ap = decideHandover(obj, current_t, serving_ap, measurements);
    end
end
