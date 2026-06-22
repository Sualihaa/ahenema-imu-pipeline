function write_opensim_quaternion_sto(quatTable, outputFile, opensimVersion)

if nargin < 3
    opensimVersion = '4.5';
end

%% Get time and quaternion column names
time = quatTable.Time_s;
vars = quatTable.Properties.VariableNames;

q0Vars = vars(contains(vars, '_q0'));
imuNames = erase(q0Vars, '_q0');

if isempty(imuNames)
    error('No quaternion columns found. Expected columns like LeftFoot_q0, LeftFoot_q1, etc.');
end

%% Open file
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

%% Column names
fprintf(fid, 'time');

for i = 1:length(imuNames)
    fprintf(fid, '\t%s_imu', imuNames{i});
end

fprintf(fid, '\n');

%% Data rows
for r = 1:height(quatTable)

    fprintf(fid, '%.6f', time(r));

    for i = 1:length(imuNames)

        name = imuNames{i};

        q0 = quatTable.([name '_q0'])(r);
        q1 = quatTable.([name '_q1'])(r);
        q2 = quatTable.([name '_q2'])(r);
        q3 = quatTable.([name '_q3'])(r);

        % OpenSim quaternion format: q0,q1,q2,q3 in one tab-separated cell
        fprintf(fid, '\t%.10f,%.10f,%.10f,%.10f', q0, q1, q2, q3);
    end

    fprintf(fid, '\n');
end

fclose(fid);

fprintf('OpenSim quaternion STO written:\n%s\n', outputFile);

end