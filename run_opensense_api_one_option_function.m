function status = run_opensense_api_one_option_function( ...
    syncFolder, ...
    optionName, ...
    modelFileName, ...
    baseIMUName, ...
    baseIMUHeading, ...
    sensor_to_opensim_rotations, ...
    weights, ...
    visualizeCalibration, ...
    visualizeTracking)

import org.opensim.modeling.*

status = struct();
status.Success = false;
status.Message = "";
status.MOTFile = "";

if ~isfolder(syncFolder)
    error('SYNC_Results_TimestampBased folder not found:\n%s', syncFolder);
end

%% Determine orientation folder and files
switch string(optionName)

    case "HybridAligned"

        orientationFolder = fullfile(syncFolder, 'Orientation_Results_HybridAligned');
        staticOrientationsFile = fullfile(orientationFolder, ...
            'Rajagopal_Orientations_Static_HybridAligned.sto');
        walkingOrientationsFile = fullfile(orientationFolder, ...
            'Rajagopal_Orientations_Walking_HybridAligned.sto');

    case "MagON"

        orientationFolder = fullfile(syncFolder, 'Orientation_Results_MagON');
        staticOrientationsFile = fullfile(orientationFolder, ...
            'Rajagopal_Orientations_Static_MagON.sto');
        walkingOrientationsFile = fullfile(orientationFolder, ...
            'Rajagopal_Orientations_Walking_MagON.sto');

    case "MagOFF"

        orientationFolder = fullfile(syncFolder, 'Orientation_Results_MagOFF');
        staticOrientationsFile = fullfile(orientationFolder, ...
            'Rajagopal_Orientations_Static_MagOFF.sto');
        walkingOrientationsFile = fullfile(orientationFolder, ...
            'Rajagopal_Orientations_Walking_MagOFF.sto');

    otherwise
        error('Unknown optionName: %s', optionName);
end

if ~isfolder(orientationFolder)
    error('Orientation folder not found:\n%s', orientationFolder);
end

if ~isfile(staticOrientationsFile)
    error('Static orientation STO not found:\n%s', staticOrientationsFile);
end

if ~isfile(walkingOrientationsFile)
    error('Walking orientation STO not found:\n%s', walkingOrientationsFile);
end

%% Output folder
resultsDirectory = fullfile(orientationFolder, 'OpenSim_Results_API');

if ~exist(resultsDirectory, 'dir')
    mkdir(resultsDirectory);
end

calibratedModelFile = fullfile(resultsDirectory, ...
    ['calibrated_model_' optionName '.osim']);

motFile = fullfile(resultsDirectory, ...
    ['IK_' optionName '_pelvis0.mot']);

%% Time range
walkingTime = read_sto_time_vector(walkingOrientationsFile);

startTime = walkingTime(1);
endTime = walkingTime(end);

%% Calibration
imuPlacer = IMUPlacer();

imuPlacer.set_model_file(modelFileName);
imuPlacer.set_orientation_file_for_calibration(staticOrientationsFile);
imuPlacer.set_sensor_to_opensim_rotations(sensor_to_opensim_rotations);
imuPlacer.set_base_imu_label(baseIMUName);
imuPlacer.set_base_heading_axis(baseIMUHeading);

imuPlacer.run(visualizeCalibration);

calibratedModel = imuPlacer.getCalibratedModel();
calibratedModel.print(calibratedModelFile);

if ~isfile(calibratedModelFile)
    error('Calibrated model was not created.');
end

%% IMU IK
imuIK = IMUInverseKinematicsTool();

imuIK.set_model_file(calibratedModelFile);
imuIK.set_orientations_file(walkingOrientationsFile);
imuIK.set_sensor_to_opensim_rotations(sensor_to_opensim_rotations);

imuIK.set_time_range(0, startTime);
imuIK.set_time_range(1, endTime);

imuIK.set_results_directory(resultsDirectory);
imuIK.set_output_motion_file(motFile);

imuIK = set_imu_orientation_weights(imuIK, weights);

setupFile = fullfile(resultsDirectory, ...
    ['IMUIK_Setup_' optionName '_pelvis0.xml']);

imuIK.print(setupFile);

imuIK.run(visualizeTracking);

if ~isfile(motFile)
    error('OpenSim finished but MOT file was not created:\n%s', motFile);
end

status.Success = true;
status.Message = "OpenSense API completed.";
status.MOTFile = motFile;

end