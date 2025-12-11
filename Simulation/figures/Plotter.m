classdef Plotter < handle
    properties
        LiFi_Pos
        WiFi_Pos
        RoomSize
    end
    
    methods
        function obj = Plotter(lifi_pos, wifi_pos, room_size)
            obj.LiFi_Pos = lifi_pos;
            obj.WiFi_Pos = wifi_pos;
            obj.RoomSize = room_size;
        end
        
        % --- Figure 3 Replication: Network Topology & SINR Map ---
        function plotCoverageMap(obj)
            figure('Name', 'Network Coverage & Topology', 'Color', 'w');
            hold on; axis equal;
            xlim([0 obj.RoomSize(1)]); ylim([0 obj.RoomSize(2)]);
            
            % 1. Compute SINR Grid for Background
            step = 0.1;
            [X, Y] = meshgrid(0:step:obj.RoomSize(1), 0:step:obj.RoomSize(2));
            BestAP_Map = zeros(size(X));
            
            % (Requires a helper to get SINR, simplified here for visualization)
            % We simulate the "Voronoi" regions by distance for speed in plotting
            % Real implementation should call the PHY model
            all_aps = [obj.LiFi_Pos; obj.WiFi_Pos];
            
            for i = 1:numel(X)
                pt = [X(i), Y(i)];
                dists = sqrt(sum((all_aps(:,1:2) - pt).^2, 2));
                
                % Approximate coverage logic: LiFi range ~2-3m, else WiFi
                % This visualizes the "Hybrid" nature
                [min_dist, idx] = min(dists);
                
                % If closest is LiFi (idx<=16) and dist < 2.5, assign LiFi color
                % Else assign WiFi color
                if idx <= 16 && min_dist < 2.0 
                    BestAP_Map(i) = 1; % LiFi Region
                else
                    BestAP_Map(i) = 2; % WiFi Region
                end
            end
            
            % Plot Regions
            contourf(X, Y, BestAP_Map, [1, 2], 'LineStyle', 'none');
            colormap([0.9 0.9 1; 0.9 1 0.9]); % Light Blue (LiFi), Light Green (WiFi)
            
            % 2. Plot AP Locations
            scatter(obj.LiFi_Pos(:,1), obj.LiFi_Pos(:,2), 50, 'b', 'filled', 'v', ...
                'DisplayName', 'LiFi AP');
            scatter(obj.WiFi_Pos(:,1), obj.WiFi_Pos(:,2), 100, 'g', 'filled', 's', ...
                'DisplayName', 'WiFi AP');
            
            % Formatting
            grid on; box on;
            xlabel('X (m)'); ylabel('Y (m)');
            title('Hybrid LiFi/WiFi Network Topology');
            legend('Location', 'bestoutside');
            set(gca, 'Layer', 'top'); % Grid on top of contour
        end
        
        % --- Figure 1/11 Replication: Trajectory & Handovers ---
        function plotTrajectory(obj, logger)
            obj.plotCoverageMap(); % Start with the map background
            hold on;
            
            % Plot Path
            plot(logger.UserPos(:,1), logger.UserPos(:,2), 'k-', 'LineWidth', 1.5, ...
                'DisplayName', 'User Path');
            
            % Plot STD Handovers
            if ~isempty(logger.HandoverEvents_STD)
                p1 = plot(logger.HandoverEvents_STD(:,2), logger.HandoverEvents_STD(:,3), ...
                    'rx', 'MarkerSize', 10, 'LineWidth', 2, ...
                    'DisplayName', 'STD Handover');
            end
            
            % Plot Proposed Handovers
            if ~isempty(logger.HandoverEvents_Prop)
                p2 = plot(logger.HandoverEvents_Prop(:,2), logger.HandoverEvents_Prop(:,3), ...
                    'bo', 'MarkerSize', 10, 'LineWidth', 2, ...
                    'DisplayName', 'Skipping Handover');
            end
            
            title('User Trajectory and Handover Locations');
        end
        
        % --- Figure 4 Replication: Rate vs Speed ---
        function plotComparativeResults(~, speed_range, rates_std, rates_prop)
            figure('Name', 'Handover Performance', 'Color', 'w');
            
            plot(speed_range, rates_std, '--r^', 'LineWidth', 2, 'MarkerSize', 8, ...
                'DisplayName', 'Standard Scheme (STD)');
            hold on;
            plot(speed_range, rates_prop, '-bo', 'LineWidth', 2, 'MarkerSize', 8, ...
                'DisplayName', 'Proposed Skipping');
            
            grid on;
            xlabel('User Speed (m/s)');
            ylabel('Handover Rate (HO/s)');
            title('Impact of User Speed on Handover Rate');
            legend('Location', 'NorthWest');
            
            % Add annotations matching the paper insights
            % "Proposed reduces HO rate by ~40% at walking speed" [cite: 452]
            text(1.5, mean(rates_prop)*1.5, 'Reduced VHOs \rightarrow', ...
                'HorizontalAlignment', 'right', 'FontSize', 10);
        end
    end
end