classdef StrategyHMM < HandoverStrategy
    % HMM-based Predictive Handover Strategy
    % Uses Hidden Markov Model to predict user trajectory and make proactive handover decisions
    
    properties (Access = private)
        Env                 % Simulation environment
        HOM                 % Handover margin (dB)
        PredictionHorizon   % How far ahead to predict (seconds)
        
        % HMM Components
        HMMModel            % Trained HMM model
        StateHistory        % History of observed states
        PositionHistory     % History of positions
        TimeHistory         % History of timestamps
        
        % Configuration
        NumStates           % Number of hidden states (motion patterns)
        HistoryWindow       % Number of past observations to keep
        MinHistorySize      % Minimum history needed before prediction
        
        % Internal state
        LastUpdateTime      % Last time HMM was updated
        UpdateInterval      % How often to retrain HMM (seconds)
    end
    
    methods
        function obj = StrategyHMM(hom, env, varargin)
            % Constructor
            % Inputs:
            %   hom: Handover margin (dB)
            %   env: Simulation environment
            %   Optional name-value pairs:
            %     'NumStates': Number of HMM hidden states (default: 4)
            %     'PredictionHorizon': Prediction time ahead in seconds (default: 2.0)
            %     'HistoryWindow': Max history size (default: 100)
            %     'UpdateInterval': HMM retraining interval (default: 1.0)
            
            obj@HandoverStrategy();
            obj.Env = env;
            obj.HOM = hom;
            
            % Parse optional parameters
            p = inputParser;
            addParameter(p, 'NumStates', 4);
            addParameter(p, 'PredictionHorizon', 2.0);
            addParameter(p, 'HistoryWindow', 100);
            addParameter(p, 'UpdateInterval', 1.0);
            parse(p, varargin{:});
            
            obj.NumStates = p.Results.NumStates;
            obj.PredictionHorizon = p.Results.PredictionHorizon;
            obj.HistoryWindow = p.Results.HistoryWindow;
            obj.UpdateInterval = p.Results.UpdateInterval;
            
            % Initialize history
            obj.StateHistory = [];
            obj.PositionHistory = [];
            obj.TimeHistory = [];
            obj.MinHistorySize = 20;  % Need at least this many observations
            
            obj.LastUpdateTime = -inf;
            obj.HMMModel = [];
        end
        
        function target_ap = decideHandover(obj, current_t, serving_ap, meas)
            % Main decision logic with HMM prediction
            
            target_ap = serving_ap;  % Default: stay connected
            
            % Extract current position from SINR measurements
            % (We need position - in practice, estimate from measurements)
            current_pos = obj.estimatePositionFromSINR(meas.SINR);
            
            % Update history
            obj.updateHistory(current_t, current_pos, serving_ap);
            
            % Check if we have enough history
            if length(obj.StateHistory) < obj.MinHistorySize
                % Fall back to simple SINR-based decision
                target_ap = obj.fallbackDecision(serving_ap, meas);
                return;
            end
            
            % Retrain HMM periodically
            if isempty(obj.HMMModel) || (current_t - obj.LastUpdateTime) >= obj.UpdateInterval
                obj.trainHMM();
                obj.LastUpdateTime = current_t;
            end
            
            % Predict future AP based on trajectory
            predicted_ap = obj.predictFutureAP(current_t);
            
            % Make handover decision based on prediction
            target_ap = obj.makeDecisionFromPrediction(serving_ap, predicted_ap, meas);
        end
        
        function updateHistory(obj, t, pos, ap_id)
            % Add observation to history
            obj.TimeHistory(end+1) = t;
            obj.PositionHistory(end+1, :) = pos;
            obj.StateHistory(end+1) = ap_id;  % Use serving AP as observable state
            
            % Maintain sliding window
            if length(obj.StateHistory) > obj.HistoryWindow
                obj.TimeHistory(1) = [];
                obj.PositionHistory(1, :) = [];
                obj.StateHistory(1) = [];
            end
        end
        
        function trainHMM(obj)
            % Train HMM from position history
            % Hidden states represent motion patterns (velocity/direction clusters)
            
            if length(obj.StateHistory) < obj.MinHistorySize
                return;
            end
            
            % Extract velocity features from position history
            velocities = diff(obj.PositionHistory, 1, 1);
            
            % Discretize velocities into observation symbols
            % Quantize based on speed and direction
            speeds = sqrt(sum(velocities.^2, 2));
            angles = atan2(velocities(:,2), velocities(:,1));
            
            % Create discrete observations (4 speed bins × 8 direction bins = 32 symbols)
            speed_bins = discretize(speeds, 4);
            angle_bins = discretize(angles, linspace(-pi, pi, 9));
            observations = (speed_bins - 1) * 8 + angle_bins;
            observations(isnan(observations)) = 1;  % Handle edge cases
            
            try
                % Train HMM using hmmestimate or create simple transition matrix
                % For simplicity, use empirical transition probabilities
                obj.HMMModel = obj.buildEmpiricalHMM(observations);
            catch
                % If training fails, use default model
                obj.HMMModel = [];
            end
        end
        
        function model = buildEmpiricalHMM(obj, observations)
            % Build simple HMM from empirical transition counts
            
            % Count transitions
            num_symbols = max(observations);
            trans_count = zeros(num_symbols, num_symbols);
            
            for i = 1:length(observations)-1
                from = observations(i);
                to = observations(i+1);
                trans_count(from, to) = trans_count(from, to) + 1;
            end
            
            % Normalize to get transition probabilities
            trans_prob = trans_count ./ (sum(trans_count, 2) + eps);
            
            % Store in model structure
            model.TransitionMatrix = trans_prob;
            model.Observations = observations;
            model.NumStates = num_symbols;
        end
        
        function predicted_ap = predictFutureAP(obj, current_t)
            % Predict which AP the user will be near in the future
            
            if isempty(obj.HMMModel) || length(obj.PositionHistory) < 2
                predicted_ap = obj.StateHistory(end);
                return;
            end
            
            % Get current velocity
            recent_vel = obj.PositionHistory(end, :) - obj.PositionHistory(end-1, :);
            time_step = obj.TimeHistory(end) - obj.TimeHistory(end-1);
            velocity = recent_vel / (time_step + eps);
            
            % Predict future position using linear extrapolation
            % (HMM helps refine this based on learned patterns)
            predicted_pos = obj.PositionHistory(end, :) + velocity * obj.PredictionHorizon;
            
            % Apply HMM-based correction if available
            if ~isempty(obj.HMMModel) && ~isempty(obj.HMMModel.TransitionMatrix)
                % Use most likely state transition to adjust prediction
                current_state = obj.StateHistory(end);
                if current_state <= size(obj.HMMModel.TransitionMatrix, 1)
                    % Weight prediction by transition probabilities
                    predicted_pos = obj.refinePositionWithHMM(predicted_pos, current_state);
                end
            end
            
            % Find best AP for predicted position
            [sinr_db, ~] = obj.Env.getChannelResponse(predicted_pos);
            [~, predicted_ap] = max(sinr_db);
        end
        
        function refined_pos = refinePositionWithHMM(obj, predicted_pos, current_state)
            % Refine position prediction using HMM state probabilities
            % This is a simplified approach - could be more sophisticated
            
            % For now, use simple linear prediction
            % In advanced implementation, could use Viterbi algorithm
            refined_pos = predicted_pos;
        end
        
        function target_ap = makeDecisionFromPrediction(obj, serving_ap, predicted_ap, meas)
            % Decide handover based on current and predicted AP
            
            current_sinr = meas.SINR(serving_ap);
            predicted_sinr = meas.SINR(predicted_ap);
            
            % If prediction suggests different AP with sufficient margin, handover
            if predicted_ap ~= serving_ap && predicted_sinr > current_sinr + obj.HOM
                target_ap = predicted_ap;
            else
                target_ap = serving_ap;
            end
        end
        
        function target_ap = fallbackDecision(obj, serving_ap, meas)
            % Simple fallback when not enough history
            % Use standard best-SINR selection with margin
            
            current_sinr = meas.SINR(serving_ap);
            [max_sinr, best_ap] = max(meas.SINR);
            
            if best_ap ~= serving_ap && max_sinr > current_sinr + obj.HOM
                target_ap = best_ap;
            else
                target_ap = serving_ap;
            end
        end
        
        function pos = estimatePositionFromSINR(obj, sinr_values)
            % Estimate position from SINR fingerprinting. use weighted centroid of AP positions based on SINR
            ap_positions = zeros(length(sinr_values), 2);
            for i = 1:length(sinr_values)
                % Extract only x,y coordinates (ignore z)
                ap_positions(i, :) = obj.Env.APs(i).Position(1:2);
            end
            
            % Convert SINR to linear scale for weighting
            weights = 10.^(sinr_values / 10);
            weights = weights / sum(weights);
            
            % Weighted average position (reshape weights to column vector)
            pos = sum(ap_positions .* weights(:), 1);
        end
    end
end
