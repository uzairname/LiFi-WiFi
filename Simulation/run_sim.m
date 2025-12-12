clear; clc;

addpath('Simulation/mobility-models');
addpath('Simulation/strategies');
addpath('Simulation/figures');
addpath('Simulation/analysis')
addpath('Simulation/environment');

%% 1. Setup
DT = 0.01;
DURATION = 30;          
ROOM_SIZE = [10, 10];
HOM = 1.0;
TTT = 0.160;

% Visualization Settings
ENABLE_VIZ = false;
% ENABLE_VIZ = true;  % Set to false to disable visualization
SHOW_COVERAGE = true;  % Show coverage regions in background (slower but informative)
COVERAGE_RESOLUTION = 0.2;  % Grid spacing for coverage map (lower = more detail, slower)
VIZ_UPDATE_RATE = 0.1;  % Update visualization every N seconds (reduces overhead)
VIZ_DELAY = 0.02;  % Delay between simulation steps when visualizing (seconds) 

% Monte Carlo Runs (only when visualization is disabled)
NUM_RUNS = 2;  % Number of runs to average over when ENABLE_VIZ = false

% Define speed ranges to test
speed_configs = {
    [0.5, 1.5], '1.0';
    [1.5, 2.5], '2.0';
    [3.0, 4.0], '3.5'
};

% Initialize environment (shared across all runs)
env = Simulation(); 
env.setupEnvironment();

% Define handover schemes to test
schemes = {
    % @() StrategyNaive(), 'NAIVE';
    @() StrategyHMM(HOM, env), 'HMM';
    @() StrategySTD(HOM, TTT, env), 'STD'
    @() StrategySkipping(HOM, TTT, env, 0.4), 'SKIPPING'  % Lower Lambda = skip less
};

% Storage: Use aggregators when running multiple times, loggers for single viz run
if ENABLE_VIZ
    all_loggers = {};
else
    aggregators = containers.Map();
end

%% 2. Run Simulations for All Configurations
fprintf('Starting Simulations...\n');
if ENABLE_VIZ
    fprintf('Visualization enabled: Running single pass\n');
    fprintf('Testing %d speed ranges × %d schemes = %d total runs\n\n', ...
        size(speed_configs, 1), size(schemes, 1), size(speed_configs, 1) * size(schemes, 1));
    num_runs = 1;
else
    fprintf('Running %d Monte Carlo iterations\n', NUM_RUNS);
    fprintf('Testing %d speed ranges × %d schemes × %d runs = %d total simulations\n\n', ...
        size(speed_configs, 1), size(schemes, 1), NUM_RUNS, size(speed_configs, 1) * size(schemes, 1) * NUM_RUNS);
    num_runs = NUM_RUNS;
end

for run_idx = 1:num_runs
    if ~ENABLE_VIZ && num_runs > 1
        fprintf('\n=== Run %d/%d ===\n', run_idx, num_runs);
    end
    
    for speed_idx = 1:size(speed_configs, 1)
    SPEED_RANGE = speed_configs{speed_idx, 1};
    speed_tag = speed_configs{speed_idx, 2};
    
    for scheme_idx = 1:size(schemes, 1)
        strategy_factory = schemes{scheme_idx, 1};
        scheme_tag = schemes{scheme_idx, 2};
        
        if ENABLE_VIZ || num_runs == 1
            fprintf('Simulating Speed: %s, Scheme: %s\n', speed_tag, scheme_tag);
        else
            fprintf('  Speed: %s, Scheme: %s ... ', speed_tag, scheme_tag);
        end
        
        % Initialize for this run
        mobility = ModifiedRWP(ROOM_SIZE, SPEED_RANGE);
        strategy = strategy_factory();
        logger = Logger(speed_tag, scheme_tag);
        
        % Initialize visualizer if enabled
        if ENABLE_VIZ
            viz = Visualizer(env, ROOM_SIZE, scheme_tag, SHOW_COVERAGE, COVERAGE_RESOLUTION);
            last_viz_update = 0;
        end
        
        % Simulation loop
        current_t = 0;
        current_ap = 1;
        
        while current_t < DURATION
            % Physics Step
            user_pos = mobility.step(DT);
            [sinr_db, capacity] = env.getChannelResponse(user_pos);
            
            % Strategy Step
            meas.SINR = sinr_db; 
            meas.Time = current_t;
            
            new_ap = strategy.decideHandover(current_t, current_ap, meas);
            if new_ap ~= current_ap
                logger.logHandover(current_t, user_pos, current_ap, new_ap);
                current_ap = new_ap;
            end
            
            % Log metrics for current timestep
            logger.logStep(current_t, user_pos, sinr_db(current_ap), capacity(current_ap));
            
            % Update visualization (throttled)
            if ENABLE_VIZ && (current_t - last_viz_update >= VIZ_UPDATE_RATE)
                viz.update(user_pos, current_ap, current_t, sinr_db(current_ap));
                last_viz_update = current_t;
                pause(VIZ_DELAY);  % Add delay for smoother visualization
            end
            
            % Time Step
            current_t = current_t + DT;
        end
        
        % Store logger for analysis
        if ENABLE_VIZ
            all_loggers{end+1} = logger;
            fprintf('  Completed. Handovers: %d\n\n', size(logger.HandoverEvents, 1));
            
            % Calculate and display handover statistics for this run
            [hho_count, vho_count, hho_rate, vho_rate] = logger.classifyHandovers(env);
            total_ho = size(logger.HandoverEvents, 1);
            total_rate = total_ho / logger.Time(end);
            fprintf('Total=%d (%.3f/s), HHO=%d (%.3f/s), VHO=%d (%.3f/s)\n', ...
                total_ho, total_rate, hho_count, hho_rate, vho_count, vho_rate);
        else
            % Add to aggregator
            key = sprintf('%s_%s', speed_tag, scheme_tag);
            if ~isKey(aggregators, key)
                agg = RunAggregator(speed_tag, scheme_tag);
                aggregators(key) = agg;
            end
            agg = aggregators(key);
            agg.addRun(logger);
            fprintf('HO=%d\n', size(logger.HandoverEvents, 1));
        end
        
        % Close visualizer if enabled (clean up for next run)
        if ENABLE_VIZ
            close(viz.FigHandle);
        end
    end
    end
end

%% analysis

if ENABLE_VIZ
    % Print logger summary
    fprintf('\n=== Single Run Results ===\n');
    for i = 1:length(all_loggers)
        logger = all_loggers{i};
        fprintf('Logger %d: Speed=%s, Scheme=%s, Handovers=%d, Duration=%.2f s\n', ...
            i, logger.SpeedTag, logger.SchemeTag, size(logger.HandoverEvents, 1), logger.Time(end));
    end
    
    % Generate handover rate comparison plots (Fig. 7)
    Plotter.plotHandoverRateComparison(all_loggers, env, 'HHO');
    Plotter.plotHandoverRateComparison(all_loggers, env, 'VHO');
else
    % Print aggregated statistics
    fprintf('\n=== Aggregated Results (averaged over %d runs) ===\n', NUM_RUNS);
    agg_keys = keys(aggregators);
    for i = 1:length(agg_keys)
        agg = aggregators(agg_keys{i});
        agg.printSummary();
        fprintf('\n');
    end
    
    % Generate handover rate comparison plots with error bars
    Plotter.plotHandoverRateComparison(aggregators, env, 'HHO');
    Plotter.plotHandoverRateComparison(aggregators, env, 'VHO');
end

fprintf('All Simulations Finished.\n');
