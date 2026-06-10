# ahenema-imu-pipeline
MATLAB pipeline for quality control, synchronization and kinematic preprocessing of INDIP IMU gait data.

# Ahenema IMU Pipeline

MATLAB pipeline for processing INDIP IMU gait data.

## Current Features

- Timestamp quality control
- Packet drop detection
- Static window detection
- Gravity axis verification
- Gyroscope bias estimation
- Magnetometer stability assessment
- Automated participant/trial processing
- QC plot generation



## Main Script

```matlab
run_study_QC
```

## Future Development

- Sensor synchronization
- Orientation estimation
- Madgwick/Mahony fusion
- OpenSim export
- IMU inverse kinematics
