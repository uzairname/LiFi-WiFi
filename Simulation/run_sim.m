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
HOM = 0.0; 
TTT = 0.160;

% Visualization Settings
ENABLE_VIZ = true;  % Set to false to disable visualization
VIZ_UPDATE_RATE = 0.1;  % Update visualization every N seconds (reduces overhead)
VIZ_DELAY = 0.05;  % Delay between simulation steps when visualizing (seconds) 

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
  %  @() StrategyNaive(), 'NAIVE';
   % @() StrategySTD(HOM, TTT, env), 'STD'
    @() StrategySkipping(HOM, TTT, env, 0.4), 'SKIPPING'  % Lower Lambda = skip less
};

% Storage for all loggers
all_loggers = {};

%% 2. Run Simulations for All Configurations
fprintf('Starting Simulations...\n');
fprintf('Testing %d speed ranges × %d schemes = %d total runs\n\n', ...
    size(speed_configs, 1), size(schemes, 1), size(speed_configs, 1) * size(schemes, 1));

for speed_idx = 1:size(speed_configs, 1)
    SPEED_RANGE = speed_configs{speed_idx, 1};
    speed_tag = speed_configs{speed_idx, 2};
    
    for scheme_idx = 1:size(schemes, 1)
        strategy_factory = schemes{scheme_idx, 1};
        scheme_tag = schemes{scheme_idx, 2};
        
        fprintf('Simuating Speed: %s, Scheme: %s\n', speed_tag, scheme_tag);
        
        % Initialize for this run
        mobility = ModifiedRWP(ROOM_SIZE, SPEED_RANGE);
        strategy = strategy_factory();
        logger = Logger(speed_tag, scheme_tag);
        
        % Initialize visualizer if enabled
        if ENABLE_VIZ
            viz = Visualizer(env, ROOM_SIZE, scheme_tag);
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
        all_loggers{end+1} = logger;
        fprintf('  Completed. Handovers: %d\n\n', size(logger.HandoverEvents, 1));
        
        % Close visualizer if enabled (clean up for next run)
        if ENABLE_VIZ
            close(viz.FigHandle);
        end
    end
end

%% analysis

% Print logger summary
for i = 1:length(all_loggers)
    logger = all_loggers{i};
    fprintf('Logger %d: Speed=%s, Scheme=%s, Handovers=%d, Duration=%.2f s\n', ...
        i, logger.SpeedTag, logger.SchemeTag, size(logger.HandoverEvents, 1), logger.Time(end));
end


fprintf('All Simulations Finished.\n');
