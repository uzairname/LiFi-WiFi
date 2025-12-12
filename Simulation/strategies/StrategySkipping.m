classdef StrategySkipping < HandoverStrategy
    % Proposed "Handover Skipping" Scheme
    
    properties
        HOM     % Handover Margin (dB)
        TTT     % Time to Trigger (s)
        Env     % Simulation environment (for AP type checking)
        Lambda % Weight coefficient for WiFi
    end
    
    properties(Access = private)
        TimerStart
        IsTimerActive
        SINR_at_t0     % Snapshot of SINRs when timer started
    end
    
    methods
        function obj = StrategySkipping(hom, ttt, env, lambda)
            obj@HandoverStrategy();
            obj.HOM = hom;
            obj.TTT = ttt;
            obj.Env = env;
            obj.Lambda = lambda;
            obj.IsTimerActive = false;
        end
        
        function target_ap = decideHandover(obj, current_t, serving_ap, meas)
            target_ap = serving_ap;
            current_sinr = meas.SINR(serving_ap);
            
            % 1. Trigger Condition: Is *ANY* AP better than Host + HOM?
            % Note: In proposed scheme, any AP can trigger the evaluation period.
            candidates = find(meas.SINR > current_sinr + obj.HOM, 1);
            
            if ~isempty(candidates)
                if ~obj.IsTimerActive
                    % Start Timer & Capture State (t0)
                    obj.IsTimerActive = true;
                    obj.TimerStart = current_t;
                    obj.SINR_at_t0 = meas.SINR; % Store P(t0)
                else
                    % Timer Running
                    elapsed = current_t - obj.TimerStart;
                    
                    if elapsed >= obj.TTT
                        % 2. Calculate Objective Function Gamma
                        % Delta = (P(now) - P(t0)) / TTT
                        delta_gamma = (meas.SINR - obj.SINR_at_t0) / obj.TTT;
                        
                        Gamma = obj.SINR_at_t0 + delta_gamma;
                        
                        % Apply Lambda weighting to WiFi APs (Type 2)
                        ap_types = obj.Env.getAPTypes();
                        wifi_mask = (ap_types == 2);
                        Gamma(wifi_mask) = obj.Lambda * (obj.SINR_at_t0(wifi_mask) + delta_gamma(wifi_mask));
                        
                        % 3. Determine Winner
                        [~, best_gamma_idx] = max(Gamma);
                        
                        % 4. Execution Check
                        % Handover only if the WINNER currently satisfies HOM condition
                        if meas.SINR(best_gamma_idx) > current_sinr + obj.HOM
                            target_ap = best_gamma_idx;
                        end
                        
                        % Reset
                        obj.IsTimerActive = false;
                    end
                end
            else
                % Condition failed, reset
                obj.IsTimerActive = false;
            end
        end
    end
end