function status = export_magoff_rajagopal_sto_one_trial_function(magOffFolder)

status = struct();
status.Success = false;
status.Message = "";

if ~isfolder(magOffFolder)
    error('Orientation_Results_MagOFF folder not found:\n%s', magOffFolder);
end

%% Required input CSV files
staticCSV = fullfile(magOffFolder, 'Segment_Quaternions_Static_MagOFF.csv');
walkingCSV = fullfile(magOffFolder, 'Segment_Quaternions_Walking_MagOFF.csv');

if ~isfile(staticCSV)
    error('Missing Segment_Quaternions_Static_MagOFF.csv');
end

if ~isfile(walkingCSV)
    error('Missing Segment_Quaternions_Walking_MagOFF.csv');
end

%% Read quaternion tables
StaticTable = readtable(staticCSV);
WalkingTable = readtable(walkingCSV);

%% Output STO files expected by OpenSense batch
staticSTO = fullfile(magOffFolder, 'Rajagopal_Orientations_Static_MagOFF.sto');
walkingSTO = fullfile(magOffFolder, 'Rajagopal_Orientations_Walking_MagOFF.sto');

%% Write Rajagopal/OpenSense STOs
write_opensim_quaternion_sto_rajagopal(StaticTable, staticSTO, '4.5');
write_opensim_quaternion_sto_rajagopal(WalkingTable, walkingSTO, '4.5');

if ~isfile(staticSTO)
    error('Static STO was not created.');
end

if ~isfile(walkingSTO)
    error('Walking STO was not created.');
end

status.Success = true;
status.Message = "MagOFF Rajagopal static and walking STO files exported.";

end