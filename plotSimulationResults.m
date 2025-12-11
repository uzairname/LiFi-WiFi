% --- plotSimulationResults.m ---
function plotSimulationResults(results_STD, results_Proposed, simParams)
    % Plots the simulation results comparing STD and Proposed algorithms
    %
    % Inputs:
    %   results_STD     - Table with STD algorithm results
    %   results_Proposed - Table with Proposed algorithm results
    %   simParams       - Simulation parameters struct
    
    %% Figure 7: Handover Rates (Bar Chart - HHO and VHO)
    figure('Name', 'Figure 7 - Handover Rates', 'NumberTitle', 'off', 'Position', [100, 100, 900, 500]);
    num_speeds = length(simParams.v_list);
    speed_labels = cellfun(@(x) sprintf('%.1f m/s', x), num2cell(simParams.v_list), 'UniformOutput', false);
    
    % Prepare data for grouped bar chart
    x_positions = 1:num_speeds;
    bar_width = 0.18;
    
    % Plot HHO and VHO for each algorithm
    hold on;
    
    % Proposed - HHO (Red)
    bar(x_positions - 1.5*bar_width, results_Proposed.HHO_Rate, bar_width, ...
        'FaceColor', [1 0 0], 'EdgeColor', 'black', 'LineWidth', 0.5);
    
    % Proposed - VHO (Green)
    bar(x_positions - 0.5*bar_width, results_Proposed.VHO_Rate, bar_width, ...
        'FaceColor', [0 1 0], 'EdgeColor', 'black', 'LineWidth', 0.5);
    
    % STD - HHO (Blue)
    bar(x_positions + 0.5*bar_width, results_STD.HHO_Rate, bar_width, ...
        'FaceColor', [0 0 1], 'EdgeColor', 'black', 'LineWidth', 0.5);
    
    % STD - VHO (Cyan)
    bar(x_positions + 1.5*bar_width, results_STD.VHO_Rate, bar_width, ...
        'FaceColor', [0 1 1], 'EdgeColor', 'black', 'LineWidth', 0.5);
    
    % Labels and formatting
    xlabel('User Speed', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Handover rate [/s]', 'FontSize', 12, 'FontWeight', 'bold');
    title('Fig. 7. Handover rates of HHO and VHO.', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Set x-axis labels
    xticks(x_positions);
    xticklabels(speed_labels);
    
    % Legend
    legend('Proposed HHO', 'Proposed VHO', 'STD HHO', 'STD VHO', ...
           'FontSize', 10, 'Location', 'best');
    
    % Y-axis limits
    max_rate = max([results_Proposed.HHO_Rate; results_Proposed.VHO_Rate; ...
                    results_STD.HHO_Rate; results_STD.VHO_Rate]);
    ylim([0, max_rate * 1.2 + 0.2]);
    
    grid on;
    set(gca, 'FontSize', 11);
    hold off;
    
    %% Figure 8: Total Handover Rate Comparison
    figure('Name', 'Figure 8 - Total Handover Rate', 'NumberTitle', 'off', 'Position', [1050, 100, 900, 500]);
    hold on;
    
    plot(results_Proposed.Speed, results_Proposed.Total_HO_Rate, '-o', ...
         'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [1 0 0], 'DisplayName', 'Proposed');
    plot(results_STD.Speed, results_STD.Total_HO_Rate, '-s', ...
         'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0 0 1], 'DisplayName', 'STD');
    
    xlabel('User''s speed [m/s]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Total handover rate [/s]', 'FontSize', 12, 'FontWeight', 'bold');
    title('Fig. 8. Total handover rate versus user speed.', 'FontSize', 12, 'FontWeight', 'bold');
    
    xlim([0, max(simParams.v_list) + 0.5]);
    ylim([0, max([results_Proposed.Total_HO_Rate; results_STD.Total_HO_Rate]) * 1.2]);
    
    grid on;
    set(gca, 'FontSize', 11);
    legend('Proposed', 'STD', 'FontSize', 11, 'Location', 'best');
    hold off;
    
    %% Figure 9: User Throughput vs Speed
    figure('Name', 'Figure 9 - User Throughput', 'NumberTitle', 'off', 'Position', [100, 650, 900, 500]);
    hold on;
    
    % Plot throughput curves
    plot(results_Proposed.Speed, results_Proposed.Avg_Throughput_Mbps, '-o', ...
         'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [1 0 0], 'DisplayName', 'Proposed');
    plot(results_STD.Speed, results_STD.Avg_Throughput_Mbps, '-s', ...
         'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0 0 1], 'DisplayName', 'STD');
    
    xlabel('User''s speed [m/s]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('User throughput [Mbps]', 'FontSize', 12, 'FontWeight', 'bold');
    title('Fig. 9. User throughput versus the user''s speed.', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Set axis limits similar to paper
    xlim([0, max(simParams.v_list) + 0.5]);
    ylim([0, 105]);
    
    % Grid
    grid on;
    set(gca, 'FontSize', 11);
    
    % Legend
    legend('Proposed', 'STD', 'FontSize', 11, 'Location', 'best');
    
    hold off;
    
    %% Figure 10: Average SINR vs Speed
    figure('Name', 'Figure 10 - Average SINR', 'NumberTitle', 'off', 'Position', [1050, 650, 900, 500]);
    hold on;
    
    plot(results_Proposed.Speed, results_Proposed.Avg_SINR_dB, '-o', ...
         'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [1 0 0], 'DisplayName', 'Proposed');
    plot(results_STD.Speed, results_STD.Avg_SINR_dB, '-s', ...
         'LineWidth', 2.5, 'MarkerSize', 8, 'Color', [0 0 1], 'DisplayName', 'STD');
    
    xlabel('User''s speed [m/s]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Average SINR [dB]', 'FontSize', 12, 'FontWeight', 'bold');
    title('Fig. 10. Average SINR versus user speed.', 'FontSize', 12, 'FontWeight', 'bold');
    
    xlim([0, max(simParams.v_list) + 0.5]);
    
    grid on;
    set(gca, 'FontSize', 11);
    legend('Proposed', 'STD', 'FontSize', 11, 'Location', 'best');
    hold off;
    
    %% Performance Improvement Summary
    figure('Name', 'Performance Improvement', 'NumberTitle', 'off', 'Position', [550, 350, 900, 500]);
    
    % Calculate improvements (Proposed vs STD)
    ho_reduction_percent = 100 * (results_STD.Total_HO_Rate - results_Proposed.Total_HO_Rate) ./ results_STD.Total_HO_Rate;
    throughput_improvement_percent = 100 * (results_Proposed.Avg_Throughput_Mbps - results_STD.Avg_Throughput_Mbps) ./ results_STD.Avg_Throughput_Mbps;
    
    % Plot improvements
    subplot(1, 2, 1);
    bar(1:num_speeds, ho_reduction_percent, 'FaceColor', [0 0.7 0.3]);
    xticks(1:num_speeds);
    xticklabels(speed_labels);
    xlabel('User Speed', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Handover Reduction [%]', 'FontSize', 11, 'FontWeight', 'bold');
    title('Handover Rate Reduction (Proposed vs STD)', 'FontSize', 11);
    grid on;
    
    subplot(1, 2, 2);
    bar(1:num_speeds, throughput_improvement_percent, 'FaceColor', [0.2 0.5 0.8]);
    xticks(1:num_speeds);
    xticklabels(speed_labels);
    xlabel('User Speed', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Throughput Improvement [%]', 'FontSize', 11, 'FontWeight', 'bold');
    title('Throughput Improvement (Proposed vs STD)', 'FontSize', 11);
    grid on;
    
    % Print summary statistics
    fprintf('\n========================================\n');
    fprintf('Performance Improvement Summary\n');
    fprintf('========================================\n');
    for i = 1:length(simParams.v_list)
        fprintf('Speed %.1f m/s:\n', simParams.v_list(i));
        fprintf('  HO Reduction: %.1f%%\n', ho_reduction_percent(i));
        fprintf('  Throughput Gain: %.1f%%\n', throughput_improvement_percent(i));
    end
    fprintf('========================================\n');
end
