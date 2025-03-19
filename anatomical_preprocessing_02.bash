#!/bin/bash

#----------------------------------------------------------------------------------------------------------------------------------------------------------
# 2024/25 IMT Lucca
# fMRI preprocessing script adapted by Tea Tucic & Marco Pagani from original script made by Francesca Setti and Giacomo Handjaras
# Original script used in Setti et al., 2023 - https://www.nature.com/articles/s41562-022-01507-3
#
# Use this pipeline before you use functional preprocessing pipelinie!!
# beacuse this does segmentation of the WM and CFS required for the functional pipeline to work
#----------------------------------------------------------------------------------------------------------------------------------------------------------
# The study directory is structured as follows (BIDS format):
#
# /home/tea.tucic/2024NatView/ (Study root directory)
# ├── subjects/  (Contains all subject data)
# │   ├── 01_originals/  (Raw fMRI images)
# │   │   ├── subj1/  (Each subject has a dedicated folder)
# │   │   │   ├── func/  (Functional images)
# │   │   │   └──anat/ (Anatomical images)
# │   │   │   
# │   │   ├── subj2/  (Next subject, same structure)
# │   │   │  
# │   ├── 02_preprocessing/  (Processed fMRI images)
# │   │   ├── subj1/  
# │   │   │   ├── func/  (Preprocessed functional images)
# │   │   │   └──anat/ (Preprocessed Anatomical images)
# │   │   │ 
# │   │   ├── subj2/
# │   │   └── ...
# │
# ├── code/  (Scripts and reference files, e.g., slice timing patterns)
# │   ├── preprocessing_script.sh
# │   ├── slice.txt  (Slice timing protocol)
# │   └── ...
#----------------------------------------------------------------------------------------------------------------------------------------------------------


# Defining paths
study_dir=/home/tea.tucic/2024NatView # study root folder
path_raw_t1=${study_dir}/subjects/01_originals # Folder containing subjects raw images
path_raw_t1_example=${path_raw_t1}/subj3/

# Input ts with path
t1=${path_raw_t1_example}/anat/T1w.nii.gz  

# This extracts the subject name, you could be required to change this for future studies
subj_name=subj3

# Create output directories for subjects, you could be required to change this for future studies
mkdir -p "${study_dir}/subjects/02_preprocessing/${subj_name}/anat"
path_preprocessed_t1=${study_dir}/subjects/02_preprocessing/${subj_name}/anat


#I couldn find 3mm mni in our folders or online. This is the solution i found, but im not sure its corrct. Can you please send me where i can download it?
# Createing 3mm MNI brain template
3dresample \
-input /home/programmi/fsl/data/linearMNI/MNI152lin_T1_2mm_brain_mask.nii.gz \
-prefix ${study_dir}/templates/MNI152lin_T1_3mm_brain_mask.nii.gz \
-dxyz 3 3 3

# ------------------------------------------
# Preprocessing is starting here
# ------------------------------------------  
	
	# 1. Bias correction with SPM -  standardizing the orientation of the T1
		fslreorient2std \
			"$t1" "${path_preprocessed_t1}/T1w_r.nii.gz"

#------------------------------------------- 

	# 2. Brain extraction
		antsBrainExtraction.sh \
			-d 3 \
			-a "${path_preprocessed_t1}/T1w_r.nii.gz" \
			-e /home/programmi/ANTS-v2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz \
			-f /home/programmi/ANTS-v2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumExtractionMask.nii.gz \
			-m /home/programmi/ANTS-v2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz \
			-o "${path_preprocessed_t1}/T1w_R_"

#-------------------------------------------

	# 3. Aligning anatomical image to epi 
		align_epi_anat.py \
			-anat "${path_preprocessed_t1}/T1w_R_BrainExtractionBrain.nii.gz" \
			-epi "${study_dir}/subjects/02_preprocessing/${subj_name}/func/Movie1_slice_time_corrected_mean.nii.gz" \
			-epi_base 0 \
			-anat_has_skull no
			-output_dir "${path_preprocessed_t1}"
		
#-------------------------------------------	

	# 4. Segmentaion of gray matter, white matter and CSF
		fast \
			-t 1 \
			-n 3 \
			-o "${path_preprocessed_t1}/T1w_segmented" \
			"${path_preprocessed_t1}/T1w_R_BrainExtractionBrain.nii.gz" 
			
#-------------------------------------------

	# 5. Nonlinear wraping to mni
		3dQwarp \
			-prefix "${path_preprocessed_t1}/T1w_wraped_to_MNI" \
			-allineate \
			-allopt '-cost nmi -automask -twopass -final wsinc5' \
			-minpatch 17 \
			-useweight \
			-blur 0 3 \
			-iwarp \
			-base /home/tea.tucic/2024NatView/templates/mni_icbm152_t1_tal_nlin_sym_09c_masked.nii.gz \
			-source  "${path_preprocessed_t1}/T1w_R_BrainExtractionBrain_al+orig"

#-------------------------------------------

	
