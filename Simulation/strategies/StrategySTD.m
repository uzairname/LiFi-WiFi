classdef StrategySTD < HandoverStrategy
    % Standard LTE Handover (Event A3 logic) [cite: 111-115]
    
    properties(Access = private)
        HOM     % Handover Margin (dB)
        TTT     % Time to Trigger (s)
        AP_Types % Array: 1=LiFi, 2=WiFi (Needed for proposed weighting)
        TimerStart      % Timestamp when condition first met
        CandidateAP     % The specific AP triggering the timer
        IsTimerActive   % Boolean flag
    end
    
    methods
        function obj = StrategySTD(hom, ttt, ap_types)
            obj@HandoverStrategy(hom, ttt, ap_types);
            obj.TimerStart = -1;
            obj.CandidateAP = -1;
            obj.IsTimerActive = false;
        end
        
        function target_ap = decideHandover(obj, current_t, serving_ap, meas)
            current_sinr = meas.SINR(serving_ap);
            target_ap = serving_ap; % Default: stay connected
            
            % 1. Identify valid candidates (Condition: Target > Host + HOM) [cite: 112]
            % We look for the strongest candidate
            [max_sinr, best_idx] = max(meas.SINR);
            
            if best_idx ~= serving_ap && max_sinr > current_sinr + obj.HOM
                
                if ~obj.IsTimerActive || best_idx ~= obj.CandidateAP
                    % Start or Restart Timer
                    obj.CandidateAP = best_idx;
                    obj.TimerStart = current_t;
                    obj.IsTimerActive = true;
                else
                    % Timer is running for this candidate
                    elapsed = current_t - obj.TimerStart;
                    
                    % Check TTT [cite: 115]
                    if elapsed >= obj.TTT
                        target_ap = obj.CandidateAP;
                        % Reset timer after successful HO decision
                        obj.IsTimerActive = false;
                        obj.CandidateAP = -1;
                    end
                end
            else
                % Condition failed, reset timer [cite: 114]
                obj.IsTimerActive = false;
                obj.CandidateAP = -1;
            end
        end
    end
end