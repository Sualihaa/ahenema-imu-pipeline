clear; clc; close all;

%% SELECT ORIENTATION RESULT FOLDER
orientationFolder = uigetdir(pwd, 'Select Orientation_Results_MagOFF folder');

if isequal(orientationFolder, 0)
    error('No folder selected.');
end

%% INPUT QUATERNION FILE
quatFile = fullfile(orientationFolder, 'Segment_Quaternions_Walking_MagOFF.csv');

if ~isfile(quatFile)
    error('Segment_Quaternions_Walking_MagOFF.csv not found in selected folder.');
end

%% READ QUATERNIONS
QuatTable = readtable(quatFile);

%% CHECK REQUIRED TIME COLUMN
if ~ismember('Time_s', QuatTable.Properties.VariableNames)
    error('Time_s column not found in quaternion table.');
end

%% OUTPUT FILE
outputFile = fullfile(orientationFolder, 'OpenSim_Orientations_Walking_MagOFF.sto');

%% WRITE OpenSim STO
write_opensim_quaternion_sto(QuatTable, outputFile, '4.5');

disp(' ');
disp('One-trial OpenSim STO export complete.');