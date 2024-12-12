#!/bin/bash

# Define paths (edit these paths)
path_fmri=$PWD/01_subjects/  # Folder containing subjects
numjobs=3  # Number of parallel jobs

# Function to process 
function process_subject {
    fmri=$1  # Input functional MRI file path
    subj_name=$(basename $(dirname $fmri))  # Extract subject name from the parent directory
    subj_func_dir=$(dirname $fmri)
    
    #creating output directories 
    mkdir -p 02_subjects_preproc/$subj_name # Create the func subfolder for each subject


    # Despike
    3dDespike \
        -prefix "02_subjects_preproc/$subj_name/Movie1_ds.nii.gz" \
        -NEW \
        "$fmri"
}
export -f process_subject

find $path_subjects -type f -name "*.nii.gz" | grep "/func/" > fmrilist.txt

# Process all subjects in parallel
parallel -j $numjobs process_subject {} < fmrilist.txt
