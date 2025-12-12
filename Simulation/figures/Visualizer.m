classdef Visualizer < handle
    properties
        % Data
        Env          % Simulation environment (for AP positions)
        RoomSize
        SchemeTag    % Current handover scheme name
        
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
        function obj = Visualizer(env, room_size, scheme_tag)
            obj.Env = env;
            obj.RoomSize = room_size;
            obj.SchemeTag = scheme_tag;
            
            obj.initializePlot();
        end
        
        function initializePlot(obj)
            obj.FigHandle = figure('Name', 'Real-Time Simulation', ...
                                   'Color', 'w', 'NumberTitle', 'off');
            obj.AxHandle = axes('Parent', obj.FigHandle);
            hold(obj.AxHandle, 'on');
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
    end
end