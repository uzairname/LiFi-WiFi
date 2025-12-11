clear; clc;

addpath('Simulation/mobility-models');
addpath('Simulation/strategies');
addpath('Simulation/figures');
addpath('Simulation/analysis')

%% 1. Setup
DT = 0.05;
DURATION = 30;          
SPEED_RANGE = [1.5, 2.5]; 
ROOM_SIZE = [10, 10];
HOM = 1.0; 
TTT = 0.160; 
LAMBDA = 0.0; % Aggressive skipping for visualization

% Initialize Classes
env = Simulation(); 
env.setupEnvironment();
mobility = ModifiedRWP(ROOM_SIZE, SPEED_RANGE);
ap_types = [ones(1, 16), ones(1, 4)*2]; 
strategy = StrategySkipping(HOM, TTT, ap_types, LAMBDA); % Using Proposed Scheme
% strategy = StrategyNaive();

logger = Logger();

%% 2. Initialize Real-Time Visualizer
% Extract positions from environment for the plotter
viz = Visualizer(env.LiFi_Pos, env.WiFi_Pos, ROOM_SIZE);

%% 3. Simulation Loop
fprintf('Starting Real-Time Simulation. Press Ctrl+C to stop.\n');

current_t = 0;
current_ap = 1;


test_pos = [5, 5];
[sinr_db, capacity] = env.getChannelResponse(test_pos);
fprintf('\n--- Channel Response at (%.1f, %.1f) ---\n', test_pos(1), test_pos(2));
disp('SINR (dB) per AP:');
disp(sinr_db);
disp('Capacity (Mbps) per AP:');
disp(capacity / 1e6);


while current_t < DURATION
    % Physics Step
    user_pos = mobility.step(DT);
    [sinr_db, ~] = env.getChannelResponse(user_pos);
    
    % Strategy Step
    meas.SINR = sinr_db; 
    meas.Time = current_t;
    
    new_ap = strategy.decideHandover(current_t, current_ap, meas);
    if new_ap ~= current_ap
        logger.logHandover('PROP', current_t, user_pos, current_ap, new_ap);
        current_ap = new_ap;
    end
    
    % --- VISUALIZATION UPDATE ---
    viz.update(user_pos, current_ap);
    % ----------------------------
    
    % Time Step
    current_t = current_t + DT;
    
    % Optional: Enforce real-time speed (otherwise it runs as fast as CPU allows)
    pause(0.01); 
end


% record metrics

analyzer = MetricsAnalyzer();
report = analyzer.generateReport(logger, 'STD');

% 4. Print Summary
fprintf('--- Standard Scheme ---\n');
fprintf('HO Rate: %.2f/s | VHO Ratio: %.2f | Downtime: %.2fs\n', ...
    report_std.HandoverFrequency, report_std.VHO_Ratio, report_std.TotalDowntime);

% 5. Visualize
analyzer.plotComparison({report_std, report_prop});


fprintf('Simulation Finished.\n');