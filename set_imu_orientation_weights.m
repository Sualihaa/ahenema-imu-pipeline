function imuIK = set_imu_orientation_weights(imuIK, weights)

import org.opensim.modeling.*

imuNames = fieldnames(weights);

orientationWeights = OrientationWeightSet();

for i = 1:length(imuNames)

    imuName = imuNames{i};
    imuWeight = weights.(imuName);

    ow = OrientationWeight(imuName, imuWeight);
    orientationWeights.cloneAndAppend(ow);

end

% Method 1: direct setter
try
    imuIK.set_orientation_weights(orientationWeights);
    fprintf('Orientation weights set using set_orientation_weights().\n');
    return;
catch
    fprintf('Direct set_orientation_weights() failed. Trying upd_orientation_weights().\n');
end

% Method 2: update internal set
try
    currentWeights = imuIK.upd_orientation_weights();
    currentWeights.clearAndDestroy();

    for i = 1:length(imuNames)

        imuName = imuNames{i};
        imuWeight = weights.(imuName);

        ow = OrientationWeight(imuName, imuWeight);
        currentWeights.cloneAndAppend(ow);

    end

    fprintf('Orientation weights set using upd_orientation_weights().\n');
    return;

catch ME
    error('Could not set orientation weights. OpenSim error: %s', ME.message);
end

end