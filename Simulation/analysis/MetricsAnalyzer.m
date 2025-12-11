classdef MetricsAnalyzer < handle
    properties (Constant)
        DELAY_HHO = 0.200;
        DELAY_VHO = 0.500;
        LIFI_MAX_IDX = 16;      % Boundary between LiFi (1-16) and WiFi (17+)
        PING_PONG_WIN = 1.0;    % Critical window (seconds)
        CDF_THRESHOLDS = 0:50;  % SINR range for Coverage Plot (dB)
    end
    
    methods
        function report = generateReport(obj, logger, strategy_tag)
            % Main entry point. Returns a struct of calculated metrics.
            % Inputs:
            %   logger: SimLogger instance
            %   strategy_tag: String ID of the strategy (e.g., 'STD')
            
            % 1. Retrieve Raw Data
            events = logger.getEvents(strategy_tag);
            sinr_trace = logger.getTrace(strategy_tag, 'SINR');
            cap_trace = logger.getTrace(strategy_tag, 'Capacity');
            total_time = logger.Time(end);
            
            % 2. Calculate Handover Metrics
            [ho_count, vho_count, hho_count] = obj.countHandoverTypes(events);
            
            % 3. Calculate Penalties (Interruption Time)
            downtime = (vho_count * obj.DELAY_VHO) + (hho_count * obj.DELAY_HHO);
            
            % 4. Calculate Advanced Metrics
            pp_rate = obj.calcPingPongRate(events);
            [cov_prob, cov_axis] = obj.calcCoverageProbability(sinr_trace);
            avg_throughput = mean(cap_trace);
            
            % 5. Package Report
            report.StrategyTag = strategy_tag;
            report.TotalHandovers = ho_count;
            report.HandoverFrequency = ho_count / total_time; % HOs per second
            report.VHO_Ratio = vho_count / max(1, ho_count); % Avoid div/0
            report.TotalDowntime = downtime;
            report.PingPongEvents = pp_rate;
            report.AverageThroughput = avg_throughput;
            report.CoverageCDF = cov_prob;     % Vector
            report.CoverageAxis = cov_axis;    % Vector
        end
        
        function plotComparison(obj, reports)
            % Utility to visualize side-by-side comparison of multiple reports
            % inputs: reports is a cell array of report structs
            
            figure('Name', 'Metrics Comparison', 'Color', 'w');
            
            % Subplot 1: Coverage Probability
            subplot(1, 2, 1); hold on; grid on;
            for i = 1:length(reports)
                r = reports{i};
                plot(r.CoverageAxis, r.CoverageCDF, 'LineWidth', 2, ...
                    'DisplayName', r.StrategyTag);
            end
            xlabel('SINR Threshold (dB)');
            ylabel('Coverage Probability');
            title('Coverage Probability (CDF)');
            legend('Location', 'SouthWest');
            
            % Subplot 2: Handover Types
            subplot(1, 2, 2);
            tags = cellfun(@(x) x.StrategyTag, reports, 'UniformOutput', false);
            vho_ratios = cellfun(@(x) x.VHO_Ratio, reports);
            bar(categorical(tags), vho_ratios);
            ylabel('VHO Ratio');
            title('Ratio of Vertical Handovers');
            grid on;
        end
    end
    
    methods (Access = private)
        function [total, vho, hho] = countHandoverTypes(obj, events)
            if isempty(events)
                total = 0; vho = 0; hho = 0;
                return;
            end
            
            total = size(events, 1);
            vho = 0;
            
            for i = 1:total
                from_ap = events(i, 4);
                to_ap = events(i, 5);
                
                % Check if crossing the technology boundary
                % LiFi (<=16) <-> WiFi (>16)
                is_vertical = (from_ap <= obj.LIFI_MAX_IDX && to_ap > obj.LIFI_MAX_IDX) || ...
                              (from_ap > obj.LIFI_MAX_IDX && to_ap <= obj.LIFI_MAX_IDX);
                
                if is_vertical
                    vho = vho + 1;
                end
            end
            hho = total - vho;
        end
        
        function count = calcPingPongRate(obj, events)
            count = 0;
            if size(events, 1) < 2
                return;
            end
            
            for i = 2:size(events, 1)
                curr_to = events(i, 5);
                prev_from = events(i-1, 4);
                dt = events(i, 1) - events(i-1, 1);
                
                % Return to previous AP within critical window
                if curr_to == prev_from && dt <= obj.PING_PONG_WIN
                    count = count + 1;
                end
            end
        end
        
        function [prob, axis] = calcCoverageProbability(obj, sinr_trace)
            % Computes P(SINR > Gamma)
            % ECDF gives P(SINR <= x), so we want 1 - ECDF
            
            axis = obj.CDF_THRESHOLDS;
            if isempty(sinr_trace)
                prob = zeros(size(axis));
                return;
            end
            
            [f, x] = ecdf(sinr_trace);
            
            % Interpolate to standard axis
            % 'linear' interpolation, 0 for extrapolation (outage)
            cdf_vals = interp1(x, f, axis, 'linear', 0);
            
            prob = 1 - cdf_vals;
        end
    end
end