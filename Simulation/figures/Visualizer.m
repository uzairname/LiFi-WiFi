classdef Visualizer < handle
    properties
        % Data
        Env          % Simulation environment (for AP positions)
        RoomSize
        SchemeTag    % Current handover scheme name
        ShowCoverage % Whether to display coverage regions
        
        % Graphics Handles
        FigHandle
        AxHandle
        UserMarker
        TrailLine
        ConnectionLine
        ActiveAPMarker
        TimeText
        SINRText
        StrategyText
    end
    
    methods
        function obj = Visualizer(env, room_size, scheme_tag, show_coverage, coverage_resolution)
            % Constructor for Visualizer
            % Inputs:
            %   env: Simulation environment object
            %   room_size: [width, height] of room in meters
            %   scheme_tag: Name of handover strategy
            %   show_coverage: (optional) Display coverage regions (default: false)
            %   coverage_resolution: (optional) Grid spacing for coverage map (default: 0.2)
            
            obj.Env = env;
            obj.RoomSize = room_size;
            obj.SchemeTag = scheme_tag;
            
            % Handle optional parameters
            if nargin < 4
                obj.ShowCoverage = false;
            else
                obj.ShowCoverage = show_coverage;
            end
            
            if nargin < 5
                coverage_resolution = 0.2;
            end
            
            obj.initializePlot(coverage_resolution);
        end
        
        function initializePlot(obj, coverage_resolution)
            obj.FigHandle = figure('Name', 'Real-Time Simulation', ...
                                   'Color', 'w', 'NumberTitle', 'off');
            obj.AxHandle = axes('Parent', obj.FigHandle);
            hold(obj.AxHandle, 'on');
            
            % Draw coverage regions as background if enabled
            if obj.ShowCoverage
                fprintf('Generating coverage map for visualization...\n');
                obj.drawCoverageRegions(coverage_resolution);
            end
            
            axis(obj.AxHandle, 'equal');
            xlim(obj.AxHandle, [0 obj.RoomSize(1)]);
            ylim(obj.AxHandle, [0 obj.RoomSize(2)]);
            grid(obj.AxHandle, 'on');
            box(obj.AxHandle, 'on');
            xlabel(obj.AxHandle, 'X (m)');
            ylabel(obj.AxHandle, 'Y (m)');
            title(obj.AxHandle, 'Live User Tracking');
            
            % Get AP positions from environment
            lifi_pos = obj.Env.getLiFiPositions();
            wifi_pos = obj.Env.getWiFiPositions();
            
            % 1. Draw Static APs (Background)
            % LiFi (Blue Triangles)
            scatter(obj.AxHandle, lifi_pos(:,1), lifi_pos(:,2), ...
                50, 'b', '^', 'filled', 'MarkerEdgeColor', 'k');
            % WiFi (Green Squares)
            scatter(obj.AxHandle, wifi_pos(:,1), wifi_pos(:,2), ...
                120, 'g', 's', 'filled', 'MarkerEdgeColor', 'k');
            
            % 2. Initialize Dynamic Objects
            % Trail: Use animatedline for high performance appending
            obj.TrailLine = animatedline('Color', [0.5 0.5 0.5], ...
                                         'LineStyle', '-', 'LineWidth', 1);
            
            % Connection Line (User to AP)
            obj.ConnectionLine = plot(obj.AxHandle, [0 0], [0 0], 'k:', 'LineWidth', 1.5);
            
            % Active AP Highlight (Red Halo)
            obj.ActiveAPMarker = plot(obj.AxHandle, -10, -10, 'ro', ...
                'MarkerSize', 14, 'LineWidth', 2);
            
            % User Marker (Filled Black Circle)
            obj.UserMarker = plot(obj.AxHandle, 0, 0, 'ko', ...
                'MarkerFaceColor', 'k', 'MarkerSize', 6);
            
            % Text displays for time and SINR
            obj.TimeText = text(obj.AxHandle, 0.5, obj.RoomSize(2) - 0.3, ...
                'Time: 0.00 s', 'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 3);
            obj.SINRText = text(obj.AxHandle, 0.5, obj.RoomSize(2) - 0.8, ...
                'SINR: -- dB', 'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', 'w', 'EdgeColor', 'k', 'Margin', 3);
            obj.StrategyText = text(obj.AxHandle, 0.5, obj.RoomSize(2) - 1.3, ...
                sprintf('Strategy: %s', obj.SchemeTag), 'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.9 0.9 1], 'EdgeColor', 'k', 'Margin', 3);
            
            legend(obj.AxHandle, {'LiFi AP', 'WiFi AP'}, 'Location', 'northeastoutside');
        end
        
        function update(obj, user_pos, connected_ap_idx, current_time, sinr_db)
            % 1. Update User Position
            set(obj.UserMarker, 'XData', user_pos(1), 'YData', user_pos(2));
            
            % 2. Update Trail
            addpoints(obj.TrailLine, user_pos(1), user_pos(2));
            
            % 3. Update Active AP Highlight
            % Get position of the connected AP from environment
            ap_pos = obj.Env.APs(connected_ap_idx).Position;
            
            set(obj.ActiveAPMarker, 'XData', ap_pos(1), 'YData', ap_pos(2));
            
            % 4. Update Connection Line (Visual link)
            set(obj.ConnectionLine, ...
                'XData', [user_pos(1), ap_pos(1)], ...
                'YData', [user_pos(2), ap_pos(2)]);
            
            % 5. Update Text Displays
            set(obj.TimeText, 'String', sprintf('Time: %.2f s', current_time));
            set(obj.SINRText, 'String', sprintf('SINR: %.2f dB', sinr_db));
            
            % 6. Force Draw
            drawnow limitrate; % 'limitrate' prevents slowing down calculation too much
        end
        
        function drawCoverageRegions(obj, resolution)
            % Draw coverage regions as background image
            % White = LiFi better, Gray = WiFi better
            
            % Create grid
            x_range = 0:resolution:obj.RoomSize(1);
            y_range = 0:resolution:obj.RoomSize(2);
            [X, Y] = meshgrid(x_range, y_range);
            
            % Initialize coverage map (1 = LiFi better, 2 = WiFi better)
            coverage_map = zeros(size(X));
            
            % Calculate best technology at each point
            for i = 1:numel(X)
                pos = [X(i), Y(i)];
                [sinr_db, ~] = obj.Env.getChannelResponse(pos);
                
                best_lifi_sinr = max(sinr_db(1:16));
                best_wifi_sinr = max(sinr_db(17:20));
                
                if best_lifi_sinr > best_wifi_sinr
                    coverage_map(i) = 1;  % LiFi region
                else
                    coverage_map(i) = 2;  % WiFi region
                end
            end
            
            % Display coverage map as background
            imagesc(obj.AxHandle, x_range, y_range, coverage_map);
            colormap(obj.AxHandle, [1 1 1; 0.75 0.75 0.75]);  % White = LiFi, Gray = WiFi
            caxis(obj.AxHandle, [1 2]);
            set(obj.AxHandle, 'YDir', 'normal');
            
            % Add colorbar
            cb = colorbar(obj.AxHandle);
            cb.Ticks = [1.25, 1.75];
            cb.TickLabels = {'LiFi', 'WiFi'};
            cb.Label.String = 'Best Tech';
            
            fprintf('Coverage map complete!\n');
        end
    end
end