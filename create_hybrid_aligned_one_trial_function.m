function status = create_hybrid_aligned_one_trial_function(syncFolder)

close all;

status = struct();
status.Success = false;
status.SyncFolder = string(syncFolder);
status.Message = "";

syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');

if ~isfile(syncMatFile)
    error('Synchronized_IMU_Data.mat not found.');
end

magONFolder = fullfile(syncFolder, 'Orientation_Results_MagON');
magOFFFolder = fullfile(syncFolder, 'Orientation_Results_MagOFF');

if ~isfolder(magONFolder)
    error('Orientation_Results_MagON folder not found.');
end

if ~isfolder(magOFFFolder)
    error('Orientation_Results_MagOFF folder not found.');
end

magONStaticFile = fullfile(magONFolder, 'Segment_Quaternions_Static_MagON.csv');
magONWalkingFile = fullfile(magONFolder, 'Segment_Quaternions_Walking_MagON.csv');

magOFFStaticFile = fullfile(magOFFFolder, 'Segment_Quaternions_Static_MagOFF.csv');
magOFFWalkingFile = fullfile(magOFFFolder, 'Segment_Quaternions_Walking_MagOFF.csv');

if ~isfile(magONStaticFile), error('Missing MagON static quaternion file.'); end
if ~isfile(magONWalkingFile), error('Missing MagON walking quaternion file.'); end
if ~isfile(magOFFStaticFile), error('Missing MagOFF static quaternion file.'); end
if ~isfile(magOFFWalkingFile), error('Missing MagOFF walking quaternion file.'); end

MagON_Static = readtable(magONStaticFile);
MagON_Walking = readtable(magONWalkingFile);

MagOFF_Static = readtable(magOFFStaticFile);
MagOFF_Walking = readtable(magOFFWalkingFile);

hybridFolder = fullfile(syncFolder, 'Orientation_Results_HybridAligned');

if ~exist(hybridFolder, 'dir')
    mkdir(hybridFolder);
end

plotFolder = fullfile(hybridFolder, 'Euler_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

pelvisSegment = "LowerBack";

segments = ["LowerBack", ...
            "RightThigh", "RightShank", "RightFoot", ...
            "LeftThigh", "LeftShank", "LeftFoot"];

Hybrid_Static = table();
Hybrid_Static.Time_s = 0;

Hybrid_Walking = table();
Hybrid_Walking.Time_s = MagOFF_Walking.Time_s;

Hybrid_Euler = table();
Hybrid_Euler.Time_s = MagOFF_Walking.Time_s;

CorrectionTable = table();

for s = 1:length(segments)

    seg = char(segments(s));

    requiredCols = { ...
        [seg '_q0'], ...
        [seg '_q1'], ...
        [seg '_q2'], ...
        [seg '_q3']};

    for c = 1:length(requiredCols)
        if ~ismember(requiredCols{c}, MagON_Static.Properties.VariableNames)
            error('Missing column in MagON static: %s', requiredCols{c});
        end

        if ~ismember(requiredCols{c}, MagON_Walking.Properties.VariableNames)
            error('Missing column in MagON walking: %s', requiredCols{c});
        end

        if ~ismember(requiredCols{c}, MagOFF_Static.Properties.VariableNames)
            error('Missing column in MagOFF static: %s', requiredCols{c});
        end

        if ~ismember(requiredCols{c}, MagOFF_Walking.Properties.VariableNames)
            error('Missing column in MagOFF walking: %s', requiredCols{c});
        end
    end

    qON_static = [ ...
        MagON_Static.([seg '_q0'])(1), ...
        MagON_Static.([seg '_q1'])(1), ...
        MagON_Static.([seg '_q2'])(1), ...
        MagON_Static.([seg '_q3'])(1)];

    qOFF_static = [ ...
        MagOFF_Static.([seg '_q0'])(1), ...
        MagOFF_Static.([seg '_q1'])(1), ...
        MagOFF_Static.([seg '_q2'])(1), ...
        MagOFF_Static.([seg '_q3'])(1)];

    qON_walk = [ ...
        MagON_Walking.([seg '_q0']), ...
        MagON_Walking.([seg '_q1']), ...
        MagON_Walking.([seg '_q2']), ...
        MagON_Walking.([seg '_q3'])];

    qOFF_walk = [ ...
        MagOFF_Walking.([seg '_q0']), ...
        MagOFF_Walking.([seg '_q1']), ...
        MagOFF_Walking.([seg '_q2']), ...
        MagOFF_Walking.([seg '_q3'])];

    qON_static = qON_static ./ norm(qON_static);
    qOFF_static = qOFF_static ./ norm(qOFF_static);
    qON_walk = qON_walk ./ vecnorm(qON_walk, 2, 2);
    qOFF_walk = qOFF_walk ./ vecnorm(qOFF_walk, 2, 2);

    if string(seg) == pelvisSegment

        qHybrid_static = qON_static;
        qHybrid_walk = qON_walk;
        fusionMode = "MagON_direct";
        qCorrection = [1 0 0 0];

    else

        qCorrection = quat_multiply_scalar_first( ...
            qON_static, ...
            quat_inverse_scalar_first(qOFF_static));

        qHybrid_static = quat_multiply_scalar_first(qCorrection, qOFF_static);
        qHybrid_walk = quat_multiply_scalar_first(qCorrection, qOFF_walk);

        fusionMode = "MagOFF_aligned_to_MagON_static";

    end

    Hybrid_Static.([seg '_q0']) = qHybrid_static(1);
    Hybrid_Static.([seg '_q1']) = qHybrid_static(2);
    Hybrid_Static.([seg '_q2']) = qHybrid_static(3);
    Hybrid_Static.([seg '_q3']) = qHybrid_static(4);

    Hybrid_Walking.([seg '_q0']) = qHybrid_walk(:,1);
    Hybrid_Walking.([seg '_q1']) = qHybrid_walk(:,2);
    Hybrid_Walking.([seg '_q2']) = qHybrid_walk(:,3);
    Hybrid_Walking.([seg '_q3']) = qHybrid_walk(:,4);

    eul = quat_to_euler_zyx_degrees(qHybrid_walk);

    Hybrid_Euler.([seg '_Yaw_deg']) = eul(:,1);
    Hybrid_Euler.([seg '_Pitch_deg']) = eul(:,2);
    Hybrid_Euler.([seg '_Roll_deg']) = eul(:,3);

    newRow = table( ...
        string(seg), ...
        fusionMode, ...
        qCorrection(1), qCorrection(2), qCorrection(3), qCorrection(4), ...
        'VariableNames', {'Segment','FusionMode','Correction_q0','Correction_q1','Correction_q2','Correction_q3'});

    CorrectionTable = [CorrectionTable; newRow];

    fig = figure('Visible','off');
    plot(Hybrid_Euler.Time_s, eul(:,1)); hold on;
    plot(Hybrid_Euler.Time_s, eul(:,2));
    plot(Hybrid_Euler.Time_s, eul(:,3)); hold off;

    title(['Hybrid aligned Euler: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Angle (deg)');
    legend('Yaw','Pitch','Roll');

    saveas(fig, fullfile(plotFolder, [seg '_Euler_Walking_HybridAligned.png']));
    close(fig);

end

writetable(Hybrid_Static, fullfile(hybridFolder, 'Segment_Quaternions_Static_HybridAligned.csv'));
writetable(Hybrid_Walking, fullfile(hybridFolder, 'Segment_Quaternions_Walking_HybridAligned.csv'));
writetable(Hybrid_Euler, fullfile(hybridFolder, 'EulerAngles_Walking_HybridAligned.csv'));
writetable(CorrectionTable, fullfile(hybridFolder, 'HybridAligned_Correction_Table.csv'));

staticSTO = fullfile(hybridFolder, 'Rajagopal_Orientations_Static_HybridAligned.sto');
walkingSTO = fullfile(hybridFolder, 'Rajagopal_Orientations_Walking_HybridAligned.sto');

write_opensim_quaternion_sto_rajagopal(Hybrid_Static, staticSTO, '4.5');
write_opensim_quaternion_sto_rajagopal(Hybrid_Walking, walkingSTO, '4.5');

save(fullfile(hybridFolder, 'Orientation_Results_HybridAligned.mat'), ...
    'Hybrid_Static', ...
    'Hybrid_Walking', ...
    'Hybrid_Euler', ...
    'CorrectionTable', ...
    'segments', ...
    'pelvisSegment');

status.Success = true;
status.Message = "HybridAligned orientation completed successfully.";

end