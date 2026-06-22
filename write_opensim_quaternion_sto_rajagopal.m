function write_opensim_quaternion_sto_rajagopal(quatTable, outputFile, opensimVersion)

if nargin < 3
    opensimVersion = '4.5';
end

%% Map your segment names to Rajagopal/OpenSense IMU labels
segmentMap = containers.Map();

segmentMap('LowerBack')  = 'pelvis_imu';
segmentMap('RightThigh') = 'femur_r_imu';
segmentMap('RightShank') = 'tibia_r_imu';
segmentMap('RightFoot')  = 'calcn_r_imu';

segmentMap('LeftThigh')  = 'femur_l_imu';
segmentMap('LeftShank')  = 'tibia_l_imu';
segmentMap('LeftFoot')   = 'calcn_l_imu';

%% Desired OpenSim order
segmentOrder = { ...
    'pelvis_imu', ...
    'femur_r_imu', ...
    'tibia_r_imu', ...
    'calcn_r_imu', ...
    'femur_l_imu', ...
    'tibia_l_imu', ...
    'calcn_l_imu'};

%% Reverse lookup: OpenSim IMU label -> original segment label
imuToSegment = containers.Map();

keysList = keys(segmentMap);

for i = 1:length(keysList)
    originalSegment = keysList{i};
    opensimIMU = segmentMap(originalSegment);
    imuToSegment(opensimIMU) = originalSegment;
end

%% Check time column
if ~ismember('Time_s', quatTable.Properties.VariableNames)
    error('Time_s column not found in quaternion table.');
end

time = quatTable.Time_s;

%% Check required quaternion columns exist
for i = 1:length(segmentOrder)

    imuName = segmentOrder{i};
    seg = imuToSegment(imuName);

    requiredCols = { ...
        [seg '_q0'], ...
        [seg '_q1'], ...
        [seg '_q2'], ...
        [seg '_q3']};

    for c = 1:length(requiredCols)
        if ~ismember(requiredCols{c}, quatTable.Properties.VariableNames)
            error('Missing quaternion column: %s', requiredCols{c});
        end
    end
end

%% Open output file
fid = fopen(outputFile, 'w');

if fid == -1
    error('Could not create output file: %s', outputFile);
end

%% Header
fprintf(fid, 'DataRate=100.000000\n');
fprintf(fid, 'DataType=Quaternion\n');
fprintf(fid, 'version=3\n');
fprintf(fid, 'OpenSimVersion=%s\n', opensimVersion);
fprintf(fid, 'endheader\n');

%% Column labels
fprintf(fid, 'time');

for i = 1:length(segmentOrder)
    fprintf(fid, '\t%s', segmentOrder{i});
end

fprintf(fid, '\n');

%% Data rows
for r = 1:height(quatTable)

    fprintf(fid, '%.6f', time(r));

    for i = 1:length(segmentOrder)

        imuName = segmentOrder{i};
        seg = imuToSegment(imuName);

        q0 = quatTable.([seg '_q0'])(r);
        q1 = quatTable.([seg '_q1'])(r);
        q2 = quatTable.([seg '_q2'])(r);
        q3 = quatTable.([seg '_q3'])(r);

        fprintf(fid, '\t%.10f,%.10f,%.10f,%.10f', q0, q1, q2, q3);
    end

    fprintf(fid, '\n');
end

fclose(fid);

fprintf('Rajagopal/OpenSense quaternion STO written:\n%s\n', outputFile);

end