classdef Plotter < handle
    properties
        env
    end
    
    methods (Static)
        function plotHandoverRateComparison(data_source, env, handover_type)
            % Plot grouped bar chart comparing handover rates across schemes and speeds
            % Shows either HHO (Horizontal) or VHO (Vertical) handover rates
            %
            % Inputs:
            %   data_source: Either:
            %       - Cell array of Logger objects (single runs)
            %       - containers.Map of RunAggregator objects (multiple runs with averaging)
            %   env: Simulation environment object (needed for AP type classification)
            %   handover_type: 'HHO' or 'VHO' (default: 'HHO')
            %
            % Creates a figure similar to Fig. 7 with:
            % - X-axis: Speed categories
            % - Y-axis: Handover rate (/s)
            % - Grouped bars: Different schemes (color-coded)
            % - Error bars: Standard deviation (when using RunAggregator)
            
            % Default to HHO if not specified
            if nargin < 3
                handover_type = 'HHO';
            end
            
            % Validate input
            if ~ismember(upper(handover_type), {'HHO', 'VHO'})
                error('handover_type must be ''HHO'' or ''VHO''');
            end
            
            % Determine if input is aggregators or loggers
            is_aggregators = isa(data_source, 'containers.Map');
            
            if is_aggregators
                % Extract unique speed tags and scheme tags from aggregators
                speed_tags = {};
                scheme_tags = {};
                agg_keys = keys(data_source);
                for i = 1:length(agg_keys)
                    agg = data_source(agg_keys{i});
                    if ~ismember(agg.SpeedTag, speed_tags)
                        speed_tags{end+1} = agg.SpeedTag;
                    end
                    if ~ismember(agg.SchemeTag, scheme_tags)
                        scheme_tags{end+1} = agg.SchemeTag;
                    end
                end
            else
                % Extract from loggers (original behavior)
                all_loggers = data_source;
                if isempty(all_loggers)
                    warning('No logger data to plot');
                    return;
                end
                
                speed_tags = {};
                scheme_tags = {};
                for i = 1:length(all_loggers)
                    if ~ismember(all_loggers{i}.SpeedTag, speed_tags)
                        speed_tags{end+1} = all_loggers{i}.SpeedTag;
                    end
                    if ~ismember(all_loggers{i}.SchemeTag, scheme_tags)
                        scheme_tags{end+1} = all_loggers{i}.SchemeTag;
                    end
                end
            end
            
            % Sort for consistent ordering
            speed_tags = sort(speed_tags);
            scheme_tags = sort(scheme_tags);
            
            n_speeds = length(speed_tags);
            n_schemes = length(scheme_tags);
            
            % Initialize data matrices: rows=schemes, cols=speeds
            plot_data = zeros(n_schemes, n_speeds);
            plot_std = zeros(n_schemes, n_speeds);  % For error bars
            
            % Aggregate data
            if is_aggregators
                % Use aggregators to compute means and std
                for i = 1:length(agg_keys)
                    agg = data_source(agg_keys{i});
                    
                    % Find indices
                    speed_idx = find(strcmp(speed_tags, agg.SpeedTag));
                    scheme_idx = find(strcmp(scheme_tags, agg.SchemeTag));
                    
                    % Compute rates for all runs in this aggregator
                    rates_mean = zeros(1, agg.getNumRuns());
                    rates_std = zeros(1, agg.getNumRuns());
                    
                    for run_idx = 1:agg.getNumRuns()
                        logger = agg.Loggers{run_idx};
                        [~, ~, hho_rate, vho_rate] = logger.classifyHandovers(env);
                        
                        if strcmpi(handover_type, 'HHO')
                            rates_mean(run_idx) = hho_rate;
                        else
                            rates_mean(run_idx) = vho_rate;
                        end
                    end
                    
                    % Store mean and std
                    plot_data(scheme_idx, speed_idx) = mean(rates_mean);
                    plot_std(scheme_idx, speed_idx) = std(rates_mean);
                end
            else
                % Use loggers directly (original behavior)
                for i = 1:length(all_loggers)
                    logger = all_loggers{i};
                    
                    % Find indices
                    speed_idx = find(strcmp(speed_tags, logger.SpeedTag));
                    scheme_idx = find(strcmp(scheme_tags, logger.SchemeTag));
                    
                    % Classify handovers and get rates
                    [~, ~, hho_rate, vho_rate] = logger.classifyHandovers(env);
                    
                    % Store the appropriate rate based on handover_type
                    if strcmpi(handover_type, 'HHO')
                        plot_data(scheme_idx, speed_idx) = hho_rate;
                    else
                        plot_data(scheme_idx, speed_idx) = vho_rate;
                    end
                end
            end
            
            % Create figure
            figure('Name', 'Handover Rate Comparison', 'Color', 'w', 'Position', [100, 100, 800, 500]);
            
            % Create grouped bar chart
            b = bar(plot_data', 'grouped');
            
            % Add error bars if using aggregators
            if is_aggregators
                hold on;
                % Calculate x positions for each bar group
                x = 1:n_speeds;
                group_width = min(0.8, n_schemes/(n_schemes + 1.5));
                
                for scheme_idx = 1:n_schemes
                    % Calculate offset for this scheme's bars
                    offset = (scheme_idx - (n_schemes+1)/2) * group_width / n_schemes;
                    x_pos = x + offset;
                    
                    % Add error bars
                    errorbar(x_pos, plot_data(scheme_idx, :), plot_std(scheme_idx, :), ...
                        'k.', 'LineWidth', 1.5, 'CapSize', 6);
                end
                hold off;
            end
            
            % Define colors for schemes (matching typical paper colors)
            % Red, Green, Blue for up to 3 schemes
            colors = [
                0.8, 0.2, 0.2;  % Red (Proposed/SKIPPING)
                0.2, 0.8, 0.2;  % Green (STD)
                0.2, 0.2, 0.8   % Blue (NAIVE/Trajectory-based)
            ];
            
            % Apply colors to bars
            for i = 1:min(n_schemes, size(colors, 1))
                b(i).FaceColor = colors(i, :);
            end
            
            % Create x-axis labels (speed tags with units)
            x_labels = cell(1, n_speeds);
            for s = 1:n_speeds
                x_labels{s} = sprintf('%s m/s', speed_tags{s});
            end
            
            % Formatting
            set(gca, 'XTickLabel', x_labels);
            xlabel('User Speed', 'FontSize', 12);
            ylabel('Handover rate (/s)', 'FontSize', 12);
            
            % Update title based on whether we're showing averages
            if is_aggregators
                title(sprintf('%s (averaged over 10 runs).', handover_type), ...
                    'FontSize', 11, 'FontWeight', 'normal');
            else
                title(sprintf('%s.', handover_type), ...
                    'FontSize', 11, 'FontWeight', 'normal');
            end
            
            legend(scheme_tags, 'Location', 'northwest', 'FontSize', 10);
            grid on;
            box on;
            
            % Adjust y-axis to start from 0
            ylim([0, max(plot_data(:)) * 1.1]);
            
            % Improve readability
            set(gca, 'FontSize', 10);
        end
        
        function plotCoverageRegions(env, resolution)
            % Plot WiFi and LiFi coverage regions based on SINR comparison
            % Creates a map showing where WiFi SINR > LiFi SINR (gray) and
            % where LiFi SINR > WiFi SINR (white), similar to the paper
            %
            % Inputs:
            %   env: Simulation environment object
            %   resolution: Grid spacing in meters (default: 0.1)
            %
            % Output:
            %   Figure showing:
            %   - White regions: LiFi has better SINR
            %   - Gray regions: WiFi has better SINR
            %   - Blue circles: LiFi AP locations
            %   - Red triangles: WiFi AP locations
            
            if nargin < 2
                resolution = 0.1;
            end
            
            % Create grid
            room_size = env.RoomSize;
            x_range = 0:resolution:room_size(1);
            y_range = 0:resolution:room_size(2);
            [X, Y] = meshgrid(x_range, y_range);
            
            % Initialize coverage map (1 = LiFi better, 2 = WiFi better)
            coverage_map = zeros(size(X));
            
            fprintf('Generating coverage map (%d x %d points)...\n', length(y_range), length(x_range));
            
            % Calculate best technology at each point
            for i = 1:numel(X)
                pos = [X(i), Y(i)];
                [sinr_db, ~] = env.getChannelResponse(pos);
                
                best_lifi_sinr = max(sinr_db(1:16));
                best_wifi_sinr = max(sinr_db(17:20));
                
                if best_lifi_sinr > best_wifi_sinr
                    coverage_map(i) = 1;  % LiFi region
                else
                    coverage_map(i) = 2;  % WiFi region
                end
                
                % Progress indicator
                if mod(i, 1000) == 0
                    fprintf('  Progress: %d/%d (%.1f%%)\n', i, numel(X), i/numel(X)*100);
                end
            end
            
            % Calculate coverage percentages
            lifi_coverage = sum(coverage_map(:) == 1) / numel(coverage_map) * 100;
            wifi_coverage = sum(coverage_map(:) == 2) / numel(coverage_map) * 100;
            
            fprintf('\nCoverage Statistics:\n');
            fprintf('  LiFi coverage: %.1f%%\n', lifi_coverage);
            fprintf('  WiFi coverage: %.1f%%\n', wifi_coverage);
            
            % Create figure
            figure('Name', 'Coverage Regions', 'Color', 'w', 'Position', [100, 100, 700, 600]);
            
            % Plot coverage map
            imagesc(x_range, y_range, coverage_map);
            colormap([1 1 1; 0.75 0.75 0.75]);  % White = LiFi, Gray = WiFi
            caxis([1 2]);  % Explicitly set color axis limits to [1, 2]
            hold on;
            
            % Get AP positions
            lifi_pos = env.getLiFiPositions();
            wifi_pos = env.getWiFiPositions();
            
            % Plot LiFi APs
            plot(lifi_pos(:,1), lifi_pos(:,2), 'bo', ...
                'MarkerSize', 8, 'LineWidth', 2, 'MarkerFaceColor', 'w');
            
            % Plot WiFi APs
            plot(wifi_pos(:,1), wifi_pos(:,2), 'r^', ...
                'MarkerSize', 10, 'LineWidth', 2, 'MarkerFaceColor', 'r');
            
            % Formatting
            xlabel('X Position (m)', 'FontSize', 12);
            ylabel('Y Position (m)', 'FontSize', 12);
            title('Coverage Regions: LiFi (White) vs WiFi (Gray)', 'FontSize', 12);
            legend('LiFi APs', 'WiFi APs', 'Location', 'best', 'FontSize', 10);
            grid on;
            axis equal tight;
            set(gca, 'YDir', 'normal');
            set(gca, 'FontSize', 10);
            
            % Add colorbar with labels
            cb = colorbar;
            cb.Ticks = [1.25, 1.75];
            cb.TickLabels = {'LiFi', 'WiFi'};
            cb.Label.String = 'Best Technology';
            
            hold off;
            
            fprintf('Coverage map complete!\n');
        end
    end
end

function out = iif(cond, true_val, false_val)
    if cond
        out = true_val;
    else
        out = false_val;
    end
end
