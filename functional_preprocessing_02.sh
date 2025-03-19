#!/bin/bash

#----------------------------------------------------------------------------------------------------------------------------------------------------------
# 2024/25 IMT Lucca
# fMRI preprocessing script adapted by Tea Tucic & Marco Pagani from original script made by Francesca Setti and Giacomo Handjaras
# Original script used in Setti et al., 2023 - https://www.nature.com/articles/s41562-022-01507-3
#
# Before using this pipeline you have to run the anatomical preprocessing pipelinie first 
# beacuse that segements the WM and CFS required for this pipeline to work!!!
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

# Setting enviromental variables 
AFNI_1D_TRANOUT=YES; export AFNI_1D_TRANOUT

# Defining image parameters	
tr=0.8 # TR (repetion time) in seconds - you should edit this 

# Defining denoising parameters (bandpass filter limits in Hz)
bandpass_from=0.01 # edit this to change filter lower limit
bandpass_to=0.1 # edit this to change filter upper limit

# Defining paths
study_dir=/home/tea.tucic/2024NatView # study root folder
path_raw_ts=${study_dir}/subjects/01_originals # Folder containing subjects raw images
path_raw_ts_example=${path_raw_ts}/subj3/

# Input ts with path
ts=${path_raw_ts_example}/func/Movie1.nii.gz  

# This extracts the subject name, you could be required to change this for future studies
subj_name=subj3

# Create output directories for subjects, you could be required to change this for future studies
mkdir -p "${study_dir}/subjects/02_preprocessing/${subj_name}/func"
path_preprocessed_ts=${study_dir}/subjects/02_preprocessing/${subj_name}/func # Folder that will contain preprocessed images

# ------------------------------------------
# Preprocessing starts here
# ------------------------------------------   
 
# 1. Despiking
3dDespike \
       	-prefix "${path_preprocessed_ts}/Movie1_despiked.nii.gz" \
       	-NEW \
       	"$ts"
        
#-------------------------------------------     
   
# 2. Slice timing correction - this setting works for the specific interleaved 
#    acquisition of this study, as detailed in slice.txt
3dTshift  \
	-prefix "${path_preprocessed_ts}/Movie1_slice_time_corrected.nii.gz" \
	-tpattern @/home/tea.tucic/2024NatView/code/slice.txt \     # file containing slice timing information 
	"${path_preprocessed_ts}/Movie1_despiked.nii.gz" 
		
#------------------------------------------- 
 
# 3. Calculation of framewise displacement
fsl_motion_outliers \
		-v \
		-i "${path_preprocessed_ts}/Movie1_slice_time_corrected.nii.gz" \
		-o "${path_preprocessed_ts}/Movie1_output" \
		-s "${path_preprocessed_ts}/Movie1_framewise_displacement.txt" \
		-p "${path_preprocessed_ts}/Movie1_plot_framewise_displacement.png" \
		--fd 
		
# Calculation of mean and median of framewise displacment
matlab -nodesktop -r 'mean_and_meadian_Framewise_displacment_calculation; exit'
		
#------------------------------------------- 	
 
# 4. Calculating the temporal mean of slice timing corrected ts. This will be used 
# as the reference volume for head motion correction
3dTstat \
	-prefix "${path_preprocessed_ts}/Movie1_slice_time_corrected_mean.nii.gz" \
	"${path_preprocessed_ts}/Movie1_slice_time_corrected.nii.gz"
		
 #------------------------------------------- 
 
# 5. Motion correction and calculation of the six motion traces
3dvolreg \
	-prefix "${path_preprocessed_ts}/Movie1_motion_corrected.nii.gz" \
	-twopass \
	-verbose \
	-base "${path_preprocessed_ts}/Movie1_slice_time_corrected_mean.nii.gz" \
	-1Dfile "${path_preprocessed_ts}/Movie1_six_motion_traces.1D" \
	"${path_preprocessed_ts}/Movie1_slice_time_corrected.nii.gz"
		
 #------------------------------------------- 
		
# 6. Nuisance regression
# First 24 Friston parameters are calculated and put in one single file, then 5 components for WM are calculated
# then mean for CSF is calulated. In the end there is a file with 30 parameters (24 motion, 5 WM, 1 CSF) ready for reggresion
	
# --- Calculating the 24 Friston's motion parameters ---
			
	# Calculating first temporal derivatives of 6 motion parameters 
	1d_tool.py \
		-infile "${path_preprocessed_ts}/Movie1_six_motion_traces.1D" \
		-derivative \
		-write "${path_preprocessed_ts}/Movie1_six_motion_derivatives.1D"
				
	# Merging six motion parameters and their first temporal derivatives in single file with the 12 motion parameters
	1dcat \
		"${path_preprocessed_ts}/Movie1_six_motion_traces.1D" \
		"${path_preprocessed_ts}/Movie1_six_motion_derivatives.1D" > \
		"${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives.1D"
				
	# Calculating squares of the 12 motion parameters
	3dcalc \
		-a "${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives.1D"\' \
		-expr 'a*a' \
		-prefix - > "${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared.1D"
				
	# Formatting the file with the 12 squared motion parameters 
 	# (because after previus step file doesnt have form we need (750x12))
			
		# Puting all of the values in the single line
		 tr \
		'\n' ' ' < \
		"${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared.1D" > \
		"${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared_single_line.1D" 
			
		# Creating 12 columns file 
	        tp=750 # nuber of time points, eddit according to your data
		col=12 # number of columns you want to have in the new file 
				 
		nInfo=$((tp*col))
				 
		awk -v nInfo="$nInfo" -v col="$col" '{
		for (i = 1; i <= nInfo; i++) {
		printf "%s", $i
		if (i % col == 0) {   
		print ""  # New line after every 'col' elements
		} else {
		printf " "
		}
		}
		}' \
		"${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared_single_line.1D" > \
		"${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared_reshaped.1D"
			
	# Merging 12 motion traces and derivatives and 12 squared values of those paremeters in single file
	# Getting the file with 24 motion traces
	1dcat \
		"${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives.1D"\
		"${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared_reshaped.1D"> \
		"${path_preprocessed_ts}/Movie1_twentyfour_motion_traces.1D"
			
	# Converting scientific notation to decimal values
	awk \
		'{for (i=1; i<=NF; i++) printf "%.5f ", $i; print ""}' \
		"${path_preprocessed_ts}/Movie1_twentyfour_motion_traces.1D" > \
		"${path_preprocessed_ts}/Movie1_twentyfour_motion_traces_decimal.1D"
			
# --- Calculating the 5 white matter components with CompCorr ---
		
# Registration of wm mask (previously calculated in the anatomical pipeline) 
# to the mean ts
flirt \
	-in /home/tea.tucic/2024NatView/subjects/01_originals/subj3/anat/T1w.nii.gz \
	-ref "${path_preprocessed_ts}/Movie1_slice_time_corrected_mean.nii.gz" \
	-omat "${path_preprocessed_ts}/wm_mask2func.mat"
flirt \
	-in /home/tea.tucic/2024NatView/subjects/02_preprocessing/subj3/anat/T1w_segmented_pve_2.nii.gz \
	-ref "${path_preprocessed_ts}/Movie1_slice_time_corrected_mean.nii.gz" \
	-applyxfm -init "${path_preprocessed_ts}/wm_mask2func.mat" \
	-out "${path_preprocessed_ts}/wm_coregistred.nii.gz"
			
# Thresholding wm mask 
fslmaths \
	 "${path_preprocessed_ts}/wm_coregistred.nii.gz" \
	-thr 0.99 \
	-bin "${path_preprocessed_ts}/wm_thr.nii.gz"
			
# Eroding wm mask
fslmaths \
	"${path_preprocessed_ts}/wm_thr.nii.gz" \
	-ero "${path_preprocessed_ts}/eroded_wm_mask.nii.gz"
			
# CompCor - calculation of 5 components 
matlab -nodesktop -r 'Run_CompCor; exit'
			
			
# --- Calculating mean signal for CSF ---
# Registration of wm mask (previously calculated in the anatomical pipeline) 
# to the mean ts
		
flirt \
	-in /home/tea.tucic/2024NatView/subjects/01_originals/subj3/anat/T1w.nii.gz \
	-ref "${path_preprocessed_ts}/Movie1_slice_time_corrected_mean.nii.gz" \
	-omat "${path_preprocessed_ts}/csf_mask2func.mat"
				
flirt \
	-in /home/tea.tucic/2024NatView/subjects/02_preprocessing/subj3/anat/T1w_segmented_pve_0.nii.gz \
	-ref "${path_preprocessed_ts}/Movie1_slice_time_corrected_mean.nii.gz" \
	-applyxfm -init "${path_preprocessed_ts}/csf_mask2func.mat" \
	-out "${path_preprocessed_ts}/csf_coregistred.nii.gz"
			
# Thresholding csf mask so that most of the signal is ventricular CSF 
fslmaths \
	 "${path_preprocessed_ts}/csf_coregistred.nii.gz" \
	-thr 0.99 \
	-bin "${path_preprocessed_ts}/csf_thresholded.nii.gz"
			
# Calculation of mean csf
fslmeants \
-i "${path_preprocessed_ts}/Movie1_motion_corrected.nii.gz" \
-m "${path_preprocessed_ts}/csf_thresholded" \
-o "${path_preprocessed_ts}/csf_mean.txt"

# --- Regressing out the 30 noise parameters ---
			
# Merging 24 Friston, 5 wm and 1 csf parameters in one file 
1dcat \
	"${path_preprocessed_ts}/Movie1_twentyfour_motion_traces_decimal.1D" \
	"${path_preprocessed_ts}/wm_CompCorPCs.txt"> \
	"${path_preprocessed_ts}/csf_mean.txt"> \
	"${path_preprocessed_ts}/30_traces.1D"
				
# Converting scientific notation to decimal values
awk \
	'{for (i=1; i<=NF; i++) printf "%.5f ", $i; print ""}' \
	"${path_preprocessed_ts}/30_traces.1D" > \
	"${path_preprocessed_ts}/30_traces_decimal.1D"
			
# Regressing out the 30 parameters 
Text2Vest "${path_preprocessed_ts}/30_traces_decimal.1D" "${path_preprocessed_ts}/30_traces.mat"
	
fsl_regfilt \
	-i $ts \
	-d "${path_preprocessed_ts}/30_traces.mat" \
	-f "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30" \
	-o "${path_preprocessed_ts}/Movie1_regressed.nii.gz"
    
 #------------------------------------------- 		
 
# 7. Scaling
3dTstat \
	-prefix "${path_preprocessed_ts}/Movie1_regressed_mean.nii.gz" \
	"${path_preprocessed_ts}/Movie1_regressed.nii.gz"

3dcalc \
	-a "${path_preprocessed_ts}/Movie1_regressed.nii.gz" \
	-b "${path_preprocessed_ts}/Movie1_regressed_mean.nii.gz" \
	-expr '(a/b)*100' \
	-datum float \
	-prefix "${path_preprocessed_ts}/Movie1_normalized.nii.gz" 	
		
 #------------------------------------------- 
 
# 8. Bandpass	
# This bandpass filters the ts
3dBandpass \
	-dt $tr \
	-prefix "${path_preprocessed_ts}/Movie1_bp_filtered.nii.gz" \
	${bandpass_from} ${bandpass_to} \
	"${path_preprocessed_ts}/Movie1_normalized.nii.gz" 
        
# This adds the mean to filtered ts, useful for carpet plot 
3dTstat \
	-mean \
	-prefix "${path_preprocessed_ts}/Movie1_mean_before_bp.nii.gz" \
	"${path_preprocessed_ts}/Movie1_normalized.nii.gz" 

fslmaths \
	"${path_preprocessed_ts}/Movie1_bp_filtered.nii.gz" \
	-add "${path_preprocessed_ts}/Movie1_mean_before_bp.nii.gz" \
	"${path_preprocessed_ts}/Movie1_bp_filtered_with_mean.nii.gz"

 #------------------------------------------- 

# 9. Skull stripping and binary mask creation
bet \
	"${path_preprocessed_ts}/Movie1_normalized.nii.gz" \     # should we do it on bandpass filtered output instead?
	"${path_preprocessed_ts}/Movie1_skull_stripped.nii.gz" \
	-m \
	-F 
	 
 #------------------------------------------- 
 
# 10. Smoothing to 6mm
3dBlurToFWHM \
	-prefix "${path_preprocessed_ts}/Movie1_smoothed.nii.gz" \
	-input "${path_preprocessed_ts}/Movie1_normalized.nii.gz"   # should we do it on bandpass filtered output instead?
	-mask "${path_preprocessed_ts}/Movie1_skull_stripped_mask.nii.gz" \
	-FWHM 6 
			
mv 3dFWHMx.1D "${path_preprocessed_ts}/"    # moving outputs to the right folder 
mv 3dFWHMx.1D.png "${path_preprocessed_ts}/"
	
#------------------------------------------- 

# 11. Registration of pre-processed functional image with MNI 
3dNwarpApply \
	-nwarp "${study_dir}/subjects/02_preprocessing/${subj_name}/anat/T1w_wraped_to_MNI_WARP+tlrc." \
	-master /home/programmi/fsl/data/linearMNI/MNI152lin_T1_2mm_brain_mask.nii.gz \
	-source "${path_preprocessed_ts}/Movie1_smoothed.nii.gz" \
	-prefix "${path_preprocessed_ts}/Movie1_registered_to_MNInlin.nii.gz"
	
 #-------------------------------------------
 
# 12. Warping functional mask to MNI
3dNwarpApply \
	-nwarp "${study_dir}/subjects/02_preprocessing/${subj_name}/anat/T1w_wraped_to_MNI_WARP+tlrc." \
	-master /home/programmi/fsl/data/linearMNI/MNI152lin_T1_2mm_brain_mask.nii.gz \
	-interp NN \
	-source "${path_preprocessed_ts}/Movie1_skull_stripped_mask.nii.gz" \
	-prefix "${path_preprocessed_ts}/Movie1_mask_registerd_to_MNI.nii.gz"

#-------------------------------------------- 
 
# Removing all unnecessary files --- > ADD ALL OF THEM
rm "${path_preprocessed_ts}/Movie1_output" 
rm "${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared_single_line.1D"
rm "${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared.1D"
rm "${path_preprocessed_ts}/Movie1_twentyfour_motion_traces.1D"
rm "${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives.1D"
rm "${path_preprocessed_ts}/Movie1_twelve_motion_traces_and_derivatives_squared_reshaped.1D"
rm "${path_preprocessed_ts}/Movie1_mean_before_bp.nii.gz"

