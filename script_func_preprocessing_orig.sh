#!/bin/bash

# Define paths (edit these paths)
path_ts=$PWD/01_subjects/  # Folder containing subjects
path_output=$PWD/02_subjects_preproc/  # Output folder
numjobs=3  # Number of parallel jobs

# Function to process a single subject
function process_subject {
    subj=$1  # Subject name or folder
    ts="${path_ts}/${subj}/func/Movie1.nii.gz"  # Update to point to func subfolder
    subj_dir="${path_ts}/${subj}"
    func_output="${path_output}/${subj}/func"  # Define the output folder inside each subject's func folder
    mkdir -p "$func_output"  # Create the func subfolder for each subject

    echo "Processing subject ${subj}..."

    # Despike
    3dDespike \
        -prefix "${func_output}/Movie1_ds.nii.gz" \
        -NEW \
        "$ts"

    # Time shift
    3dTshift \
        -prefix "${func_output}/Movie1_dsts.nii.gz" \
        -tpattern seq+z \
        "${func_output}/Movie1_ds.nii.gz"

    # Reference mean image
    3dTstat \
        -prefix "${func_output}/ref_Movie1.nii.gz" \
        "${func_output}/Movie1_dsts.nii.gz"

    # Motion correction
    3dvolreg \
        -prefix "${func_output}/Movie1_dstsvr.nii.gz" \
        -twopass \
        -verbose \
        -base "${func_output}/ref_Movie1.nii.gz" \
        -1Dfile "${func_output}/Movie1_motion.1D" \
        -maxdisp1D "${func_output}/Movie1_maxmov.1D" \
        "${func_output}/Movie1_dsts.nii.gz"

    # Detect motion outliers
    fsl_motion_outliers \
        -v \
        -i "${func_output}/Movie1_dsts.nii.gz" \
        -o "${func_output}/Movie1_spikes.1D" \
        -s "${func_output}/Movie1_metric.txt" \
        -p "${func_output}/Movie1_plot.png"

    # Smoothing
    3dBlurToFWHM \
        -prefix "${func_output}/Movie1_dstsvrsm6.nii.gz" \
        -input "${func_output}/Movie1_dstsvr.nii.gz" \
        -mask "${func_output}/Movie1_dstsvrSS_mask.nii.gz" \
        -FWHM 6

    # Scaling
    3dTstat \
        -prefix "${func_output}/Movie1_preproc_mean_sm6.nii.gz" \
        "${func_output}/Movie1_dstsvrsm6.nii.gz"

    3dcalc \
        -a "${func_output}/Movie1_dstsvrsm6.nii.gz" \
        -b "${func_output}/Movie1_preproc_mean_sm6.nii.gz" \
        -expr '(a/b)*100' \
        -datum float \
        -prefix "${func_output}/Movie1_preproc_norm_sm6.nii.gz"

    # Masking
    3dMean \
        -prefix "${func_output}/mask_sum.nii.gz" \
        "${func_output}/Movie1_dstsvrSS_mask.nii.gz"
    
    3dcalc \
        -datum byte \
        -a "${func_output}/mask_sum.nii.gz" \
        -prefix "${func_output}/mask_AND.nii.gz" \
        -expr 'equals(a,1)'

    # Convert mask to .HEAD format
    3dcopy "${func_output}/mask_AND.nii.gz" "${func_output}/mask_AND"

    # Detrending (requires external MATLAB script)
    matlab -nodesktop -r "cd('/home/tea.tucic/2024NatView/codes/preprocessing'); run_detrend; exit"

    # Copy detrended data
    3dcopy "${subj_dir}/func/Movie1_sm6_detrend+orig" "${func_output}/Movie1_sm6_detrend.nii.gz"

    # Deconvolution
    3dDeconvolve \
        -input "${func_output}/Movie1_sm6_detrend.nii.gz" \
        -mask "${func_output}/mask_AND.nii.gz" \
        -polort 0 \
        -ortvec "${func_output}/Movie1_no_interest.1D" no_interest \
        -nobucket \
        -x1D "${func_output}/deco_clean_SG.xmat.1D" \
        -errts "${func_output}/Movie1_cleaned_sm6_SG.nii.gz"

    echo "Finished processing ${subj}"
}
export -f process_subject

# Create the output directory for each subject
mkdir -p $path_output

# Generate a list of subjects dynamically from the input directory
subjects=($(ls -d $path_ts/* | xargs -n 1 basename))

# Process all subjects in parallel
parallel -j $numjobs process_subject ::: "${subjects[@]}"
