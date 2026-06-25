clear; clc; close all;

%% Import OpenSim API
import org.opensim.modeling.*

%% ================= USER SETTINGS =================

% Path to your Rajagopal OpenSense model
modelFileName = 'C:\Users\USER\Documents\OpenSim\4.5\Code\Matlab\OpenSenseExample\Rajagopal_2015.osim';

% Select orientation result folder
orientationFolder = uigetdir(pwd, 'Select Orientation_Results_HybridAligned, MagON, or MagOFF folder');

if isequal(orientationFolder, 0)
    error('No folder selected.');
end

% Choose option
% Options: 'HybridAligned', 'MagON', 'MagOFF'
optionName = 'HybridAligned';

% OpenSense settings
baseIMUName = 'pelvis_imu';
baseIMUHeading = 'y';

% This should match what worked in GUI.
% You have mostly been using no extra rotation, so start with Vec3(0,0,0).
sensor_to_opensim_rotations = Vec3(0, 0, 0);

visualizeCalibration = false;
visualizeTracking = false;

%% ================= FILE PATHS =================
% 
% staticOrientationsFile = fullfile(orientationFolder, ...
%     ['Rajagopal_Orientations_Static_' optionName '.sto']);
% 
% walkingOrientationsFile = fullfile(orientationFolder, ...
%     ['Rajagopal_Orientations_Walking_' optionName '.sto']);

staticOrientationsFile = fullfile(orientationFolder, ...
    'Rajagopal_Orientations_Static_HybridAligned_PelvisCorrected.sto');

walkingOrientationsFile = fullfile(orientationFolder, ...
    'Rajagopal_Orientations_Walking_HybridAligned_PelvisCorrected.sto');

if ~isfile(staticOrientationsFile)
    error('Static orientations file not found:\n%s', staticOrientationsFile);
end

if ~isfile(walkingOrientationsFile)
    error('Walking orientations file not found:\n%s', walkingOrientationsFile);
end

if ~isfile(modelFileName)
    error('Model file not found:\n%s', modelFileName);
end

%% ================= OUTPUT FOLDER =================

resultsDirectory = fullfile(orientationFolder, 'OpenSim_Results_API');

if ~exist(resultsDirectory, 'dir')
    mkdir(resultsDirectory);
end

calibratedModelFile = fullfile(resultsDirectory, ...
    ['calibrated_model_' optionName '.osim']);

%% ================= GET TIME RANGE =================

walkingTime = read_sto_time_vector(walkingOrientationsFile);

startTime = walkingTime(1);
endTime = walkingTime(end);

fprintf('\nTime range: %.4f to %.4f seconds\n', startTime, endTime);

%% ================= IMU PLACER / CALIBRATION =================

fprintf('\nRunning OpenSense calibration using IMUPlacer...\n');

imuPlacer = IMUPlacer();

imuPlacer.set_model_file(modelFileName);
imuPlacer.set_orientation_file_for_calibration(staticOrientationsFile);
imuPlacer.set_sensor_to_opensim_rotations(sensor_to_opensim_rotations);
imuPlacer.set_base_imu_label(baseIMUName);
imuPlacer.set_base_heading_axis(baseIMUHeading);

imuPlacer.run(visualizeCalibration);

calibratedModel = imuPlacer.getCalibratedModel();

calibratedModel.print(calibratedModelFile);

fprintf('Calibrated model saved:\n%s\n', calibratedModelFile);

%% ================= IMU IK / ORIENTATION TRACKING =================

fprintf('\nRunning OpenSense IMU Inverse Kinematics...\n');

imuIK = IMUInverseKinematicsTool();

imuIK = IMUInverseKinematicsTool();

imuIK.set_model_file(calibratedModelFile);
imuIK.set_orientations_file(walkingOrientationsFile);
imuIK.set_sensor_to_opensim_rotations(sensor_to_opensim_rotations);

imuIK.set_time_range(0, startTime);
imuIK.set_time_range(1, endTime);

imuIK.set_results_directory(resultsDirectory);

%% Set output motion file
outputMotionFile = fullfile(resultsDirectory, ...
    ['IK_' optionName '_pelvis0.mot']);

imuIK.set_output_motion_file(outputMotionFile);

%% Set IMU tracking weights
weights = struct();

weights.pelvis_imu  = 0;
weights.femur_r_imu = 1;
weights.tibia_r_imu = 1;
weights.calcn_r_imu = 1;
weights.femur_l_imu = 1;
weights.tibia_l_imu = 1;
weights.calcn_l_imu = 1;

imuIK = set_imu_orientation_weights(imuIK, weights);

%% Save the IK setup XML too, so we can inspect it
ikSetupFile = fullfile(resultsDirectory, ...
    ['IMUIK_Setup_' optionName '_pelvis0.xml']);

imuIK.print(ikSetupFile);

fprintf('\nIMU IK setup saved:\n%s\n', ikSetupFile);

%% Run IK
imuIK.run(visualizeTracking);

fprintf('\nOpenSense API run complete.\n');
fprintf('Results folder:\n%s\n', resultsDirectory);