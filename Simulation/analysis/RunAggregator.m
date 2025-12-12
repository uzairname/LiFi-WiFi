classdef RunAggregator < handle
    % RunAggregator - Aggregates multiple Logger instances with same tags
    % Computes statistics across multiple Monte Carlo runs
    
    properties
        SpeedTag
        SchemeTag
        Loggers  % Cell array of Logger instances
    end
    
    methods
        function obj = RunAggregator(speed_tag, scheme_tag)
            % Constructor
            obj.SpeedTag = speed_tag;
            obj.SchemeTag = scheme_tag;
            obj.Loggers = {};
        end
        
        function addRun(obj, logger)
            % Add a Logger instance to this aggregator
            % Validates that tags match
            if ~strcmp(logger.SpeedTag, obj.SpeedTag) || ...
               ~strcmp(logger.SchemeTag, obj.SchemeTag)
                error('Logger tags (Speed=%s, Scheme=%s) do not match aggregator tags (Speed=%s, Scheme=%s)', ...
                    logger.SpeedTag, logger.SchemeTag, obj.SpeedTag, obj.SchemeTag);
            end
            obj.Loggers{end+1} = logger;
        end
        
        function num = getNumRuns(obj)
            % Get number of runs in this aggregator
            num = length(obj.Loggers);
        end
        
        function [avg_rate, std_rate] = getHandoverRateStats(obj)
            % Compute average and standard deviation of handover rate
            rates = cellfun(@(log) size(log.HandoverEvents, 1) / log.Time(end), ...
                           obj.Loggers);
            avg_rate = mean(rates);
            std_rate = std(rates);
        end
        
        function [avg_sinr, std_sinr] = getAverageSINRStats(obj)
            % Compute mean SINR across all runs
            all_sinr = cellfun(@(log) mean(log.ActiveSINR), obj.Loggers);
            avg_sinr = mean(all_sinr);
            std_sinr = std(all_sinr);
        end
        
        function [avg_capacity, std_capacity] = getAverageCapacityStats(obj)
            % Compute mean capacity across all runs
            all_capacity = cellfun(@(log) mean(log.ActiveCapacity), obj.Loggers);
            avg_capacity = mean(all_capacity);
            std_capacity = std(all_capacity);
        end
        
        function total_handovers = getTotalHandovers(obj)
            % Get total number of handovers across all runs
            total_handovers = sum(cellfun(@(log) size(log.HandoverEvents, 1), obj.Loggers));
        end
        
        function printSummary(obj)
            % Print summary statistics for this configuration
            [avg_rate, std_rate] = obj.getHandoverRateStats();
            [avg_sinr, std_sinr] = obj.getAverageSINRStats();
            
            fprintf('Speed: %s, Scheme: %s, Runs: %d\n', ...
                obj.SpeedTag, obj.SchemeTag, obj.getNumRuns());
            fprintf('  Handover Rate: %.3f ± %.3f HO/s\n', avg_rate, std_rate);
            fprintf('  Avg SINR: %.2f ± %.2f dB\n', avg_sinr, std_sinr);
            fprintf('  Total Handovers: %d\n', obj.getTotalHandovers());
        end
    end
end
