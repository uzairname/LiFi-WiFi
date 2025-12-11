classdef Visualizer < handle
    properties
        % Data
        LiFi_Pos
        WiFi_Pos
        All_Pos      % Combined matrix for easy indexing
        RoomSize
        
        % Graphics Handles
        FigHandle
        AxHandle
        UserMarker
        TrailLine
        ConnectionLine
        ActiveAPMarker
    end
    
    methods
        function obj = Visualizer(lifi_pos, wifi_pos, room_size)
            obj.LiFi_Pos = lifi_pos;
            obj.WiFi_Pos = wifi_pos;
            obj.All_Pos = [lifi_pos; wifi_pos];
            obj.RoomSize = room_size;
            
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
            
            % 1. Draw Static APs (Background)
            % LiFi (Blue Triangles)
            scatter(obj.AxHandle, obj.LiFi_Pos(:,1), obj.LiFi_Pos(:,2), ...
                50, 'b', '^', 'filled', 'MarkerEdgeColor', 'k');
            % WiFi (Green Squares)
            scatter(obj.AxHandle, obj.WiFi_Pos(:,1), obj.WiFi_Pos(:,2), ...
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
            
            legend(obj.AxHandle, {'LiFi AP', 'WiFi AP'}, 'Location', 'northeastoutside');
        end
        
        function update(obj, user_pos, connected_ap_idx)
            % 1. Update User Position
            set(obj.UserMarker, 'XData', user_pos(1), 'YData', user_pos(2));
            
            % 2. Update Trail
            addpoints(obj.TrailLine, user_pos(1), user_pos(2));
            
            % 3. Update Active AP Highlight
            % Get position of the connected AP
            ap_pos = obj.All_Pos(connected_ap_idx, :);
            
            set(obj.ActiveAPMarker, 'XData', ap_pos(1), 'YData', ap_pos(2));
            
            % 4. Update Connection Line (Visual link)
            set(obj.ConnectionLine, ...
                'XData', [user_pos(1), ap_pos(1)], ...
                'YData', [user_pos(2), ap_pos(2)]);
            
            % 5. Force Draw
            drawnow limitrate; % 'limitrate' prevents slowing down calculation too much
        end
    end
end