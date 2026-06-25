clear; clc; close all;

%% ADD MOBILISE-D PATHS
repoDir = 'C:\Users\USER\Desktop\sorted_files\ahenema-imu-pipeline\Mobilise-D-TVS-Recommended-Algorithms';

addpath(fullfile(repoDir, 'ICDA'));
addpath(fullfile(repoDir, 'ICDA', 'Library'));

%% SELECT SYNC FOLDER
syncFolder = uigetdir(pwd, 'Select SYNC_Results_TimestampBased folder');

if isequal(syncFolder, 0)
    error('No folder selected.');
end

syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');

if ~isfile(syncMatFile)
    error('Synchronized_IMU_Data.mat not found.');
end

%% LOAD DATA
load(syncMatFile, 'SyncTable', 'fs_sync', 'walk_start_s', 'walk_end_s');

fprintf('\nLoaded synchronized data.\n');
fprintf('Walking window: %.3f to %.3f s\n', walk_start_s, walk_end_s);
fprintf('Sampling rate: %.2f Hz\n', fs_sync);

%% CHECK LOWERBACK COLUMNS
requiredCols = { ...
    'LowerBack_AccX_g', ...
    'LowerBack_AccY_g', ...
    'LowerBack_AccZ_g'};

for i = 1:length(requiredCols)
    if ~ismember(requiredCols{i}, SyncTable.Properties.VariableNames)
        error('Missing column: %s', requiredCols{i});
    end
end

%% CONVERT LOWERBACK ACCELERATION
% Your synchronized acceleration is in g.
% Mobilise-D expects acceleration signal, usually in m/s^2.
g = 9.80665;

accX = SyncTable.LowerBack_AccX_g * g;
accY = SyncTable.LowerBack_AccY_g * g;
accZ = SyncTable.LowerBack_AccZ_g * g;

%% IMPORTANT AXIS ASSUMPTION
% StepDetection expects:
% imu_acc(:,1) = Vertical
% imu_acc(:,2) = Medio-lateral
% imu_acc(:,3) = Antero-posterior
%
% For now, we start with this assumption:
% Vertical = AccZ
% ML       = AccY
% AP       = AccX
%
% If IC detection looks wrong, we will test other axis mappings.

imu_acc = [accZ, accY, accX];

%% DEFINE GAIT SEQUENCE
GS = struct();
GS(1).Start = walk_start_s;
GS(1).End = walk_end_s;

%% RUN STEP DETECTION
plot_results = 1;

SD_Output = StepDetection(imu_acc, GS, fs_sync, plot_results);

%% EXTRACT INITIAL CONTACTS
if isempty(SD_Output) || ~isfield(SD_Output, 'IC') || isempty(SD_Output(1).IC)
    warning('No initial contacts detected.');
    IC_times = [];
else
    IC_times = SD_Output(1).IC(:);
end

fprintf('\nDetected %d initial contacts.\n', length(IC_times));
disp(IC_times);

%% SAVE OUTPUT
outFolder = fullfile(syncFolder, 'MobiliseD_GaitEvents');

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

GaitEvents = table();
GaitEvents.IC_Time_s = IC_times;

writetable(GaitEvents, fullfile(outFolder, 'InitialContacts_MobiliseD.csv'));

save(fullfile(outFolder, 'MobiliseD_StepDetection_Output.mat'), ...
    'SD_Output', 'IC_times', 'GS', 'imu_acc', 'fs_sync', 'walk_start_s', 'walk_end_s');

fprintf('\nSaved gait events to:\n%s\n', fullfile(outFolder, 'InitialContacts_MobiliseD.csv'));