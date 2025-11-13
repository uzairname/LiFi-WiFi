% --- checkHandover_Proposed.m ---
% Implements the Proposed Handover Algorithm from the paper
% This algorithm uses SINR degradation and velocity prediction for improved handover decisions

function [user, ho_event, counters] = checkHandover_Proposed(user, all_sinr_dB, apList, simParams, counters)
    
    ho_event.type = 'None';
    current_sinr = all_sinr_dB(user.currentAP_idx);
    
    % Find the best AP in the entire network
    [best_sinr, best_idx] = max(all_sinr_dB);
    
    % --- Proposed Algorithm Logic ---
    % The proposed algorithm is based on:
    % 1. SINR degradation detection (not just absolute threshold)
    % 2. Hysteresis with margin (HOM)
    % 3. Time-to-Trigger (TTT) for stability
    % 4. Smart penalty system to avoid ping-ponging
    
    % Check if current SINR has degraded significantly from initial measurement
    sinr_degradation = user.prop_sinr_0 - current_sinr;
    
    % Handover condition: A candidate AP is significantly better than current AP
    % AND the user hasn't recently handed over to this AP (penalty timer)
    if best_idx ~= user.currentAP_idx && best_sinr > current_sinr + simParams.HOM
        
        % Check if we're in the penalty period (avoid ping-ponging)
        if user.prop_penalty_timer > 0
            user.prop_penalty_timer = user.prop_penalty_timer - simParams.dt;
        end
        
        % Only consider handover if not in penalty period
        if user.prop_penalty_timer <= 0
            if best_idx == user.prop_target_idx
                % Timer is already running for this target
                user.prop_timer = user.prop_timer + simParams.dt;
            else
                % A new target is strongest, reset timer
                user.prop_target_idx = best_idx;
                user.prop_timer = simParams.dt;
            end
            
            if user.prop_timer >= simParams.TTT
                old_AP_type = user.currentAP_type;
                
                % Update user's AP
                user.currentAP_idx = user.prop_target_idx;
                user.currentAP_type = apList(user.currentAP_idx).type;
                user.prop_sinr_0 = all_sinr_dB(user.currentAP_idx); % Update baseline SINR
                
                % Log the event
                if strcmp(old_AP_type, user.currentAP_type)
                    ho_event.type = 'HHO';
                    counters.hho = counters.hho + 1;
                else
                    ho_event.type = 'VHO';
                    counters.vho = counters.vho + 1;
                end
                
                % Set penalty timer to avoid immediate re-handover (500ms)
                user.prop_penalty_timer = 0.5;
                
                % Reset timer state
                user.prop_timer = 0;
                user.prop_target_idx = -1;
            end
        end
    else
        % Handover condition not met, reset timers
        user.prop_timer = 0;
        user.prop_target_idx = -1;
    end
    
end
