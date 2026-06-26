# Ahenema IMU–OpenSim Gait Analysis Pipeline

This repository contains MATLAB scripts for processing synchronized multi-IMU gait data from the Ahenema footwear study. The workflow supports three orientation-processing options:

1. **MagON** — accelerometer + gyroscope + magnetometer
2. **MagOFF** — accelerometer + gyroscope only
3. **HybridAligned** — lower-back/pelvis from MagON, lower-limb MagOFF orientations aligned to the MagON static frame

The final analysis can be run with any of these options by changing the selected `optionName` or `optionsToRun` variable in the scripts.

---

## 1. Expected data structure

The root folder should contain participant folders named `P#`.

Example:

```text
sorted_files/
│
├── P2/
│   ├── T1/
│   ├── T1W/
│   ├── T2/
│   ├── T2W/
│   ├── T3/
│   └── T3W/
│
├── P3/
│   ├── T1/
│   ├── T1W/
│   └── ...
│
└── P20/
```

Trial naming convention:

```text
T1, T2, T3      = Without Ahenema
T1W, T2W, T3W  = With Ahenema
```

Each trial folder should contain the raw IMU `.txt` files.

---

## 2. Sensor mapping

The pipeline assumes the following sensor-to-segment mapping:

```text
INDIP#005 → LowerBack
INDIP#012 → RightThigh
INDIP#007 → RightShank
INDIP#010 → RightFoot
INDIP#008 → LeftThigh
INDIP#002 → LeftShank
INDIP#006 → LeftFoot
```

OpenSim/Rajagopal IMU labels:

```text
LowerBack  → pelvis_imu
RightThigh → femur_r_imu
RightShank → tibia_r_imu
RightFoot  → calcn_r_imu
LeftThigh  → femur_l_imu
LeftShank  → tibia_l_imu
LeftFoot   → calcn_l_imu
```

---

# 3. Full processing pipeline

## Stage 1 — Raw IMU quality control

Run:

```matlab
run_study_QC.m
```

Supporting functions:

```text
process_trial_QC.m
qc_single_INDIP_sensor.m
save_sensor_qc_plots.m
```

Purpose:

```text
Checks raw IMU files for missing data, duplicate timestamps, dropped packets,
negative time jumps, sampling-rate issues, and sensor saturation.
```

Main output:

```text
QC_AllParticipants.csv
```

---

## Stage 2 — Timestamp-based synchronization

Run:

```matlab
batch_sync_all_trials.m
```

Supporting functions:

```text
sync_trial_IMUs.m
sync_one_trial_IMUs.m
load_clean_INDIP_sensor_for_sync.m
detect_walking_onset.m
detect_walking_window_from_combined_signal.m
plot_timestamp_based_sync.m
```

Purpose:

```text
Synchronizes the seven IMUs using timestamps and identifies the walking window.
```

Main outputs per trial:

```text
SYNC_Results_TimestampBased/
│
├── Synchronized_IMU_Data_Full.csv
├── Synchronized_IMU_Data_WalkingOnly.csv
├── Synchronization_Summary.csv
└── Synchronized_IMU_Data.mat
```

---

# 4. Orientation estimation options

The pipeline supports three orientation options.

---

## Option A — MagON

MagON uses:

```text
accelerometer + gyroscope + magnetometer
```

Run:

```matlab
batch_estimate_orientations_magON_all_trials.m
```

Supporting functions:

```text
estimate_orientations_magON_one_trial.m
estimate_orientations_magON_one_trial_function.m
```

Output folder:

```text
Orientation_Results_MagON/
```

Use MagON when:

```text
A global heading reference is important and magnetometer disturbance is acceptable.
```

Potential limitation:

```text
Lower-limb orientations may be noisier if magnetic disturbance is present.
```

---

## Option B — MagOFF

MagOFF uses:

```text
accelerometer + gyroscope only
```

Run:

```matlab
batch_estimate_orientations_all_trials.m
```

Supporting functions:

```text
estimate_orientations_one_trial_function.m
quat_to_euler_zyx_degrees.m
```

Output folder:

```text
Orientation_Results_MagOFF/
```

Use MagOFF when:

```text
Avoiding magnetic disturbance is more important than preserving global heading.
```

Potential limitation:

```text
Heading drift or global-frame inconsistency may occur because magnetometer correction is not used.
```

---

## Option C — HybridAligned

HybridAligned combines MagON and MagOFF.

Concept:

```text
LowerBack / pelvis = MagON
Lower-limb segments = MagOFF aligned to the MagON static frame
```

Formula:

```matlab
qCorrection = qStaticMagON * inverse(qStaticMagOFF)
qHybridWalking = qCorrection * qMagOFFWalking
```

Run:

```matlab
batch_create_hybrid_aligned_all_trials.m
```

Supporting functions:

```text
create_hybrid_aligned_one_trial.m
create_hybrid_aligned_one_trial_function.m
quat_multiply_scalar_first.m
quat_inverse_scalar_first.m
write_opensim_quaternion_sto_rajagopal.m
```

Output folder:

```text
Orientation_Results_HybridAligned/
```

Use HybridAligned when:

```text
You want to preserve smoother MagOFF lower-limb motion while aligning it to a more stable MagON static/global frame.
```

Potential limitation:

```text
This is a custom hybrid strategy and should be visually validated before final analysis.
```

---

# 5. Export OpenSim orientation STO files

Before OpenSim IK, export static and walking orientation files.

For HybridAligned, this is handled during HybridAligned creation.

For MagOFF, run:

```matlab
batch_export_magoff_rajagopal_sto_all_trials.m
```

Supporting function:

```text
export_magoff_rajagopal_sto_one_trial_function.m
```

Expected MagOFF outputs per trial:

```text
Orientation_Results_MagOFF/
│
├── Rajagopal_Orientations_Static_MagOFF.sto
└── Rajagopal_Orientations_Walking_MagOFF.sto
```

For MagON or HybridAligned, expected files are similarly named with the corresponding option name.

---

# 6. OpenSim IMU inverse kinematics

Run:

```matlab
batch_run_opensense_api_all_options.m
```

Supporting functions:

```text
run_opensense_api_one_trial.m
run_opensense_api_one_option_function.m
set_imu_orientation_weights.m
```

Choose the orientation option inside the script:

```matlab
optionsToRun = ["HybridAligned"];
```

or:

```matlab
optionsToRun = ["MagON"];
```

or:

```matlab
optionsToRun = ["MagOFF"];
```

You may also run multiple options:

```matlab
optionsToRun = ["HybridAligned", "MagON", "MagOFF"];
```

Recommended IK settings used in this project:

```matlab
baseIMUName = 'pelvis_imu';
baseIMUHeading = 'y';

weights.pelvis_imu  = 0;
weights.femur_r_imu = 1;
weights.tibia_r_imu = 1;
weights.calcn_r_imu = 1;
weights.femur_l_imu = 1;
weights.tibia_l_imu = 1;
weights.calcn_l_imu = 1;
```

Reason:

```text
The lower-back IMU was used as the base IMU, but pelvis/root motion was not interpreted as a primary outcome.
Pelvis IMU tracking weight was set to zero because pelvis/root posture was sensitive to lower-back sensor alignment.
Lower-limb IMUs were weighted to extract knee and ankle kinematics.
```

Main output per trial:

```text
OpenSim_Results_API/
└── IK_<Option>_pelvis0.mot
```

Example:

```text
IK_HybridAligned_pelvis0.mot
IK_MagOFF_pelvis0.mot
IK_MagON_pelvis0.mot
```

---

# 7. Extract knee and ankle kinematics

Run:

```matlab
batch_extract_knee_ankle_kinematics.m
```

Supporting functions:

```text
extract_and_plot_knee_ankle_from_mot.m
read_opensim_mot.m
trial_to_condition.m
```

Inside the script, select the option to analyze:

```matlab
optionsToAnalyze = ["HybridAligned"];
```

or:

```matlab
optionsToAnalyze = ["MagON"];
```

or:

```matlab
optionsToAnalyze = ["MagOFF"];
```

Extracted coordinates:

```text
knee_angle_r
knee_angle_l
ankle_angle_r
ankle_angle_l
```

Main output per trial:

```text
Extracted_Knee_Ankle_<Option>.csv
```

Example:

```text
Extracted_Knee_Ankle_HybridAligned.csv
Extracted_Knee_Ankle_MagOFF.csv
Extracted_Knee_Ankle_MagON.csv
```

---

# 8. Preliminary with-vs-without plots

Run:

```matlab
plot_with_vs_without_knee_ankle_all_participants.m
```

Supporting functions:

```text
plot_one_participant_with_vs_without.m
plot_condition_overlay_and_mean.m
collect_normalized_trials.m
normalize_one_curve.m
build_mean_curve_table.m
```

Set:

```matlab
optionName = "HybridAligned";
```

or:

```matlab
optionName = "MagON";
```

or:

```matlab
optionName = "MagOFF";
```

Purpose:

```text
Creates preliminary with-vs-without plots before true gait-cycle segmentation.
These plots are useful for visual inspection but should not be treated as final gait-cycle plots.
```

---

# 9. Gait-cycle segmentation

## 9.1 One-trial test

Run first on one clean trial:

```matlab
segment_knee_ankle_by_foot_events_one_trial.m
```

Supporting functions:

```text
get_sync_time_vector.m
detect_foot_contacts_from_synctable.m
segment_side_kinematics_from_contacts.m
make_mean_side_specific_cycle_table.m
plot_side_specific_trial_cycles.m
```

Set:

```matlab
optionName = "HybridAligned";
```

or:

```matlab
optionName = "MagON";
```

or:

```matlab
optionName = "MagOFF";
```

Important correction:

```matlab
rightContactTimes_forIK = rightEvents.ContactTime_s - walk_start_s;
leftContactTimes_forIK  = leftEvents.ContactTime_s  - walk_start_s;
```

Reason:

```text
Foot contact events are detected in full synchronized-trial time, while OpenSim knee/ankle CSVs are usually in walking-only time.
Therefore, contact times must be aligned to the OpenSim walking-trial time base before segmentation.
```

---

## 9.2 Diagnostic event alignment check

Run if curves look wrong:

```matlab
diagnose_foot_events_against_kinematics_one_trial.m
```

Purpose:

```text
Overlays detected foot contacts on raw knee and ankle time-series to confirm correct event alignment.
```

---

## 9.3 Batch side-specific gait-cycle segmentation

Run:

```matlab
batch_side_specific_gaitcycle_knee_ankle_all_participants.m
```

Supporting functions:

```text
side_specific_gaitcycle_one_trial_function.m
get_sync_time_vector.m
detect_foot_contacts_from_synctable.m
segment_side_kinematics_from_contacts.m
make_mean_side_specific_cycle_table.m
plot_side_specific_trial_cycles.m
trial_to_condition.m
```

Set:

```matlab
optionName = "HybridAligned";
```

or:

```matlab
optionName = "MagON";
```

or:

```matlab
optionName = "MagOFF";
```

Method:

```text
Right foot contacts → right knee and right ankle cycles
Left foot contacts  → left knee and left ankle cycles
```

Main output folder:

```text
SIDE_SPECIFIC_GAITCYCLE_RESULTS_<Option>/
```

Examples:

```text
SIDE_SPECIFIC_GAITCYCLE_RESULTS_HybridAligned/
SIDE_SPECIFIC_GAITCYCLE_RESULTS_MagOFF/
SIDE_SPECIFIC_GAITCYCLE_RESULTS_MagON/
```

Main outputs:

```text
AllParticipants_AllCycles_Long_<Option>.csv
AllParticipants_TrialMeans_Long_<Option>.csv
Batch_SideSpecific_GaitCycle_Log_<Option>.csv
```

---

# 10. Cycle-level quality control

Run:

```matlab
qc_side_specific_gait_cycles_all_participants.m
```

Set:

```matlab
optionName = "HybridAligned";
```

or:

```matlab
optionName = "MagON";
```

or:

```matlab
optionName = "MagOFF";
```

Input:

```text
SIDE_SPECIFIC_GAITCYCLE_RESULTS_<Option>/
└── AllParticipants_AllCycles_Long_<Option>.csv
```

Cycle QC rejects cycles based on:

```text
1. Abnormal gait-cycle duration
2. Unrealistic knee/ankle range of motion
3. Poor waveform correlation with the within-trial median waveform
```

Main output folder:

```text
SIDE_SPECIFIC_GAITCYCLE_RESULTS_<Option>/
└── QC_CycleFiltering/
```

Main outputs:

```text
AllParticipants_AllCycles_Long_<Option>_QC_CLEAN.csv
AllParticipants_AllCycles_Long_<Option>_QC_REJECTED.csv
CycleLevel_QC_Report_<Option>.csv
TrialLevel_QC_Report_<Option>.csv
ParticipantCondition_QC_Report_<Option>.csv
Manuscript_QC_Summary_<Option>.csv
Cycle_RejectionReason_Summary_<Option>.csv
```

Important note:

```text
Cycle-level QC is performed after OpenSim IK and gait-cycle segmentation because it depends on the extracted knee and ankle waveforms.
```

---

# 11. Participant metrics and figures

Run:

```matlab
build_qc_participant_metrics_and_figures.m
```

Set:

```matlab
optionName = "HybridAligned";
```

or:

```matlab
optionName = "MagON";
```

or:

```matlab
optionName = "MagOFF";
```

Supporting functions:

```text
plot_one_participant_condition_curves.m
plot_group_waveforms_from_participant_means.m
group_mean_sem.m
plot_shaded_mean.m
```

Input:

```text
QC_CycleFiltering/
└── AllParticipants_AllCycles_Long_<Option>_QC_CLEAN.csv
```

Outputs:

```text
Participant_Metrics_and_Figures/
│
├── ParticipantCondition_MeanCurves_<Option>_QC.csv
├── ParticipantCondition_KinematicMetrics_<Option>_QC.csv
├── Participant_Inclusion_Report_<Option>_QC.csv
├── Descriptive_Stats_For_Manuscript_<Option>_QC.csv
├── Individual_Participant_Plots/
└── Group_Plots/
```

Participant inclusion rule:

```text
A participant is included in a coordinate-specific paired analysis if they have at least three retained gait cycles in both footwear conditions.
```

---

# 12. Paired statistics and SPSS export

Run:

```matlab
run_paired_statistics_knee_ankle_qc.m
```

Set:

```matlab
optionName = "HybridAligned";
```

or:

```matlab
optionName = "MagON";
```

or:

```matlab
optionName = "MagOFF";
```

Inputs:

```text
ParticipantCondition_KinematicMetrics_<Option>_QC.csv
Participant_Inclusion_Report_<Option>_QC.csv
```

Outputs:

```text
Statistics/
│
├── SPSS_WideFormat_KinematicMetrics_<Option>_QC.csv
├── Paired_Statistics_KneeAnkle_<Option>_QC.csv
├── Paired_Data_Long_KneeAnkle_<Option>_QC.csv
└── Manuscript_Statistics_Table_<Option>_QC.csv
```

Statistical approach:

```text
Paired comparisons are performed between Without Ahenema and With Ahenema.
Normality of paired differences is assessed.
If normal: paired t-test.
If non-normal: Wilcoxon signed-rank test.
```

---

# 13. SPSS confirmation

Use:

```text
SPSS_WideFormat_KinematicMetrics_<Option>_QC.csv
```

In SPSS:

```text
Analyze → Compare Means → Paired-Samples T Test
```

or, if non-normal:

```text
Analyze → Nonparametric Tests → Related Samples → Wilcoxon signed-rank test
```

---

# 14. Recommended script order

Use this if running the full pipeline from raw data:

```text
1. run_study_QC.m
2. batch_sync_all_trials.m

3. batch_estimate_orientations_all_trials.m              % MagOFF
4. batch_estimate_orientations_magON_all_trials.m        % MagON

5. batch_export_static_calibration_sto.m
6. batch_export_magoff_rajagopal_sto_all_trials.m        % required if using MagOFF

7. batch_create_hybrid_aligned_all_trials.m              % required if using HybridAligned

8. batch_run_opensense_api_all_options.m
9. batch_extract_knee_ankle_kinematics.m

10. plot_with_vs_without_knee_ankle_all_participants.m   % preliminary inspection

11. segment_knee_ankle_by_foot_events_one_trial.m        % one-trial test
12. diagnose_foot_events_against_kinematics_one_trial.m  % diagnostic if needed

13. batch_side_specific_gaitcycle_knee_ankle_all_participants.m
14. qc_side_specific_gait_cycles_all_participants.m
15. build_qc_participant_metrics_and_figures.m
16. run_paired_statistics_knee_ankle_qc.m
17. SPSS confirmation
```

---

# 15. Choosing the orientation option

The user can choose one of:

```matlab
optionName = "MagON";
```

```matlab
optionName = "MagOFF";
```

```matlab
optionName = "HybridAligned";
```

Use **MagON** if:

```text
global heading stability is important and magnetic disturbance is minimal.
```

Use **MagOFF** if:

```text
magnetic disturbance is suspected and smoother lower-limb motion is preferred.
```

Use **HybridAligned** if:

```text
a compromise is needed between MagON static/global alignment and MagOFF lower-limb smoothness.
```

Recommended practice:

```text
Run at least two options, inspect individual and group waveforms, compare QC retention,
and select the orientation pipeline that gives the most biomechanically plausible and repeatable knee/ankle curves.
```

---

# 16. Final reporting statement

A manuscript-ready description:

```text
Raw IMU files were first screened for timestamp irregularities, missing samples, and sensor saturation. The seven IMUs were synchronized using timestamp-based alignment, and walking windows were identified from the synchronized signals. Orientation estimates were generated using magnetometer-aided, magnetometer-free, and/or hybrid-aligned approaches. OpenSim IMU inverse kinematics was then performed to extract sagittal-plane knee and ankle angles.

Side-specific gait cycles were defined from consecutive contacts of the same foot, with right-foot contacts used for right knee and ankle cycles and left-foot contacts used for left knee and ankle cycles. Each gait cycle was time-normalized to 101 points. Cycle-level quality control excluded cycles with abnormal duration, unrealistic joint range of motion, or poor waveform agreement with the within-trial median waveform. Retained cycles were averaged within participant and footwear condition. Participants were included in coordinate-specific paired analyses if at least three retained gait cycles were available in both footwear conditions. Paired statistical comparisons were then performed between the Without Ahenema and With Ahenema conditions.
```
