clear; clc; close all;

%% SELECT SYNC FOLDER
syncFolder = uigetdir(pwd, 'Select SYNC_Results_TimestampBased folder');

if isequal(syncFolder, 0)
    error('No folder selected.');
end

%% FILE PATHS
kneeAnkleFile = fullfile(syncFolder, ...
    'Orientation_Results_HybridAligned', ...
    'OpenSim_Results_API', ...
    'Knee_Ankle_Plots', ...
    'Extracted_Knee_Ankle_HybridAligned.csv');

eventFolder = fullfile(syncFolder, ...
    'Orientation_Results_HybridAligned', ...
    'OpenSim_Results_API', ...
    'SideSpecific_GaitCycles');

rightEventFile = fullfile(eventFolder, 'RightFoot_Contacts.csv');
leftEventFile  = fullfile(eventFolder, 'LeftFoot_Contacts.csv');

if ~isfile(kneeAnkleFile)
    error('Missing knee/ankle file:\n%s', kneeAnkleFile);
end

if ~isfile(rightEventFile)
    error('Missing right foot contact file:\n%s', rightEventFile);
end

if ~isfile(leftEventFile)
    error('Missing left foot contact file:\n%s', leftEventFile);
end

%% LOAD
K = readtable(kneeAnkleFile);
R = readtable(rightEventFile);
L = readtable(leftEventFile);

%% LOAD WALKING START TIME FOR TIME ALIGNMENT
syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');
load(syncMatFile, 'walk_start_s');

%% ALIGN FOOT CONTACT TIMES TO KNEE/ANKLE TIME BASE
rightIC = R.ContactTime_s - walk_start_s;
leftIC  = L.ContactTime_s  - walk_start_s;

rightIC = rightIC(rightIC >= min(K.time) & rightIC <= max(K.time));
leftIC  = leftIC(leftIC  >= min(K.time) & leftIC  <= max(K.time));

%% OUTPUT FOLDER
diagFolder = fullfile(eventFolder, 'Diagnostics');

if ~exist(diagFolder, 'dir')
    mkdir(diagFolder);
end

%% PLOT RAW KINEMATICS WITH CONTACTS
fig = figure('Visible','on', 'Position', [100 100 1300 850]);

subplot(2,2,1);
plot(K.time, K.knee_angle_r, 'k', 'LineWidth', 1.5); hold on;
yl = ylim;
for i = 1:length(rightIC)
    xline(rightIC(i), 'r--', 'LineWidth', 1.0);
end
ylim(yl);
grid on;
title('Right Knee with Right Foot Contacts');
xlabel('Time (s)');
ylabel('Angle (deg)');

subplot(2,2,2);
plot(K.time, K.ankle_angle_r, 'k', 'LineWidth', 1.5); hold on;
yl = ylim;
for i = 1:length(rightIC)
    xline(rightIC(i), 'r--', 'LineWidth', 1.0);
end
ylim(yl);
grid on;
title('Right Ankle with Right Foot Contacts');
xlabel('Time (s)');
ylabel('Angle (deg)');

subplot(2,2,3);
plot(K.time, K.knee_angle_l, 'k', 'LineWidth', 1.5); hold on;
yl = ylim;
for i = 1:length(leftIC)
    xline(leftIC(i), 'b--', 'LineWidth', 1.0);
end
ylim(yl);
grid on;
title('Left Knee with Left Foot Contacts');
xlabel('Time (s)');
ylabel('Angle (deg)');

subplot(2,2,4);
plot(K.time, K.ankle_angle_l, 'k', 'LineWidth', 1.5); hold on;
yl = ylim;
for i = 1:length(leftIC)
    xline(leftIC(i), 'b--', 'LineWidth', 1.0);
end
ylim(yl);
grid on;
title('Left Ankle with Left Foot Contacts');
xlabel('Time (s)');
ylabel('Angle (deg)');

sgtitle('Diagnostic: Foot Contacts Against OpenSim Knee/Ankle Angles');

saveas(fig, fullfile(diagFolder, 'FootContacts_vs_KneeAnkle_Diagnostic.png'));

%% PRINT BASIC RANGE
fprintf('\nKinematic ranges in this trial:\n');
fprintf('Right knee ROM: %.2f deg\n', range(K.knee_angle_r, 'omitnan'));
fprintf('Left knee ROM: %.2f deg\n', range(K.knee_angle_l, 'omitnan'));
fprintf('Right ankle ROM: %.2f deg\n', range(K.ankle_angle_r, 'omitnan'));
fprintf('Left ankle ROM: %.2f deg\n', range(K.ankle_angle_l, 'omitnan'));

fprintf('\nRight foot contacts: %d\n', length(rightIC));
fprintf('Left foot contacts: %d\n', length(leftIC));

fprintf('\nSaved diagnostic plot to:\n%s\n', fullfile(diagFolder, 'FootContacts_vs_KneeAnkle_Diagnostic.png'));