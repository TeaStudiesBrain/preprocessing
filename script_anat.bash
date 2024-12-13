#!/bin/bash

# Define paths (edit these paths)
path_subject=$PWD/subjects/  # Folder containing subjects
#numjobs=2  # Number of parallel jobs

# Function to process a single subject's fMRI data
function process_subject {
    mri=$1  # Input functional MRI file path
    subj_name=$(basename $(dirname $(dirname $mri)))  # Extract subject name from the grandparent directory

    # Create output directories for this subject
    mkdir -p "subjects_preproc/${subj_name}/anat"  # Ensure func subfolder exist
        


    # bias correction with SPM (optional here)
    fslreorient2std  "$mri" "subjects_preproc/${subj_name}/anat/T1w_R"

    antsBrainExtraction.sh \
    -d 3 \
    -a "subjects_preproc/${subj_name}/anat/T1w_R.nii.gz" \
    -e /home/programmi/ANTS-v.2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz \
    -f /home/programmi/ANTS-v.2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumExtractionMask.nii.gz \
    -m /home/programmi/ANTS-v.2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz \
    -o "subjects_preproc/${subj_name}/anat/T1w_R_"

    # align anat to epi (optional here)
    align_epi_anat.py -anat "subjects_preproc/${subj_name}/anat/T1w_R_BrainExtractionBrain.nii.gz" -epi "subjects_preproc/${subj_name}/func/ref_Movie1.nii.gz" -epi_base 0 -anat_has_skull no 


    3dQwarp \
    -prefix  "subjects_preproc/${subj_name}/anat/T1w_ICBM_nlin" \
    -allineate \
    -allopt '-cost nmi -automask -twopass -final wsinc5' \
    -minpatch 17 \
    -useweight \
    -blur 0 3 \
    -iwarp \
    -base /mni_icbm152_nlin_sym_09c/mni_icbm152_t1_tal_nlin_sym_09c_masked.nii.gz \
    -source  "subjects_preproc/${subj_name}/anat/T1w_R_BrainExtractionBrain_al+orig"
    

#exit 0;


        ### comandi per warp serie temporali di ogni tipo
        
        # warp MNI della maschera come sanity check
        3dNwarpApply \
        -nwarp "subjects_preproc/${subj_name}/anat/T1w_ICBM_nlin_WARP+tlrc." \
        -master /MNI152_mask_3mm.nii.gz \
        -interp NN \
        -source "subjects_preproc/${subj_name}/func/mask_AND.nii.gz" \
        -prefix "subjects_preproc/${subj_name}/anat/mask_AND_MNInlin.nii.gz"
        
        #sleep 3;
        
        
        # warp MNI dei dati con smoothing 6mm
        3dNwarpApply \
        -nwarp "subjects_preproc/${subj_name}/anat/T1w_ICBM_nlin_WARP+tlrc." \
        -master /MNI152_mask_3mm.nii.gz \
        -source "subjects_preproc/${subj_name}/func/Movie1_cleaned_sm6.nii.gz" \ #name has to be changed 
        -prefix "subjects_preproc/${subj_name}/anat/Movie1_cleaned_sm6_MNInlin.nii.gz"
        
        #sleep 3;
        
        
        
        # savitzky
        3dNwarpApply \
        -nwarp "subjects_preproc/${subj_name}/anat/mprage_ICBM_nlin_WARP+tlrc". \
        -master /MNI152_mask_3mm.nii.gz \
        -source "subjects_preproc/${subj_name}/func/Movie1_cleaned_sm6_SG.nii.gz" \
        -prefix "subjects_preproc/${subj_name}/anat/Movie1_cleaned_sm6_SG_MNInlin.nii.gz"
}

# Find all fMRI files in the func subfolders of each subject
find "$path_subject" -type f -name "*.nii.gz" | grep "/func/" > fmrilist.txt

# Process each subject sequentially
while IFS= read -r fmri; do
    process_subject "$fmri"
done < fmrilist.txt



