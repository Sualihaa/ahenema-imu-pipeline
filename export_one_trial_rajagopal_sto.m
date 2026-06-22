clear; clc; close all;

%% SELECT ORIENTATION RESULT FOLDER
orientationFolder = uigetdir(pwd, 'Select Orientation_Results_MagOFF folder');

if isequal(orientationFolder, 0)
    error('No folder selected.');
end

%% Walking quaternion file
walkingQuatFile = fullfile(orientationFolder, 'Segment_Quaternions_Walking_MagOFF.csv');

if ~isfile(walkingQuatFile)
    error('Segment_Quaternions_Walking_MagOFF.csv not found.');
end

WalkingQuatTable = readtable(walkingQuatFile);

walkingSTO = fullfile(orientationFolder, 'Rajagopal_Orientations_Walking_MagOFF.sto');

write_opensim_quaternion_sto_rajagopal(WalkingQuatTable, walkingSTO, '4.5');

%% Static quaternion file
staticQuatFile = fullfile(orientationFolder, 'Segment_Quaternions_Static_MagOFF.csv');

if isfile(staticQuatFile)

    StaticQuatTable = readtable(staticQuatFile);

    staticSTO = fullfile(orientationFolder, 'Rajagopal_Orientations_Static_MagOFF.sto');

    write_opensim_quaternion_sto_rajagopal(StaticQuatTable, staticSTO, '4.5');

else
    warning('Static quaternion file not found. Only walking STO was exported.');
end

disp(' ');
disp('Rajagopal/OpenSense one-trial STO export complete.');