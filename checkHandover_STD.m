% --- checkHandover_STD.m ---
function [user, ho_event, counters] = checkHandover_STD(user, all_sinr_dB, apList, simParams, counters)
    % Implements the Standard (STD) handover logic [cite: 107-115]
    
    ho_event.type = 'None';
    current_sinr = all_sinr_dB(user.currentAP_idx);
    
    % Find the best AP in the entire network
    [best_sinr, best_idx] = max(all_sinr_dB);

    % change to best ap
    user.currentAP_idx = best_idx;
    user.currentAP_type = apList(user.currentAP_idx).type;

    % % Check Handover Trigger Condition [cite: 112]
    % if best_idx ~= user.currentAP_idx && best_sinr > current_sinr + simParams.HOM
    %     % Condition is MET
    % 
    %     if best_idx == user.std_target_idx
    %         % Timer is already running for this target
    %         user.std_timer = user.std_timer + simParams.dt;
    %     else
    %         % A new target is strongest, reset timer
    %         user.std_target_idx = best_idx;
    %         user.std_timer = simParams.dt;
    %     end
    % 
    %     % Check if TTT has expired [cite: 115]
    %     if user.std_timer >= simParams.TTT
    %         % --- EXECUTE HANDOVER ---
    %         old_AP_type = user.currentAP_type;
    % 
    %         % Update user's AP
    %         user.currentAP_idx = user.std_target_idx;
    %         user.currentAP_type = apList(user.currentAP_idx).type;
    % 
    %         % Log the event
    %         if strcmp(old_AP_type, user.currentAP_type)
    %             ho_event.type = 'HHO';
    %             counters.hho = counters.hho + 1;
    %         else
    %             ho_event.type = 'VHO';
    %             counters.vho = counters.vho + 1;
    %         end
    % 
    %         % Reset timer state
    %         user.std_timer = 0;
    %         user.std_target_idx = -1;
    %     end
    % 
    % else
    %     % Condition is NOT MET, reset timer
    %     user.std_timer = 0;
    %     user.std_target_idx = -1;
    % end
end