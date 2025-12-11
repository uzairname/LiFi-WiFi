classdef StrategyNaive < HandoverStrategy
    % Naive Handover Scheme
    % Always connects to the AP with the highest SINR immediately.
    % Useful as a baseline to demonstrate the "Ping-Pong" effect.
    
    methods
        function target_ap = decideHandover(~, ~, serving_ap, meas)
            % 1. Identify the AP with the absolute highest SINR
            [~, best_idx] = max(meas.SINR);
            
            % 2. Immediate Decision
            % If the best AP is different from current, switch immediately.
            if best_idx ~= serving_ap
                target_ap = best_idx;
            else
                target_ap = serving_ap;
            end
        end
    end
end