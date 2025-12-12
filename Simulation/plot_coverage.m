% Plot Coverage Regions for LiFi vs WiFi
% This script generates a coverage map showing where LiFi SINR > WiFi SINR
% and vice versa, similar to the figures in the paper.

clear; clc;

addpath('environment');
addpath('figures');

%% Setup Environment
fprintf('Setting up simulation environment...\n');
env = Simulation();
env.setupEnvironment();

%% Generate Coverage Map
% Higher resolution = more detailed but slower (0.1 is good balance)
% Try 0.05 for very detailed, or 0.2 for faster preview
resolution = 0.1;

fprintf('\nGenerating coverage regions map...\n');
Plotter.plotCoverageRegions(env, resolution);

fprintf('\nDone! The coverage map shows:\n');
fprintf('  - WHITE regions: LiFi has better SINR\n');
fprintf('  - GRAY regions: WiFi has better SINR\n');
fprintf('  - Blue circles: LiFi AP locations (16 total)\n');
fprintf('  - Red triangles: WiFi AP locations (4 total)\n');
