#!/bin/bash
#fMRI preprocessing script by Giacomo Handjaras, Francesca Setti 

# despike
3dDespike \
-prefix Movie1_ds.nii.gz \
-NEW \
Movie1.nii.gz

sleep 1;

# time shift
3dTshift  \
-prefix Movie1_dsts.nii.gz \
-tpattern seq+z \
Movie1_ds.nii.gz

sleep 1;

#if [ $run -eq 1 ]
#then
	3dTstat -prefix ref_Movie1.nii.gz Movie1_dsts.nii.gz
#fi

3dvolreg \
-prefix Movie1_dstsvr.nii.gz \
-twopass \
-verbose \
-base ref_Movie1.nii.gz \
-1Dfile Movie1_motion.1D \
-maxdisp1D Movie1_maxmov.1D \
Movie1_dsts.nii.gz

sleep 1;

fsl_motion_outliers \
-v \
-i Movie1_dsts.nii.gz \
-o Movie1_spikes.1D \
-s Movie1_metric.txt \
-p Movie1_plot.png \

sleep 1;

# smoothing to 6mm
bet Movie1_dstsvr.nii.gz Movie1_dstsvrSS.nii.gz -F

3dBlurToFWHM -prefix Movie1_dstsvrsm6.nii.gz \
-input Movie1_dstsvr.nii.gz \
-mask Movie1_dstsvrSS_mask.nii.gz \
-FWHM 6 

sleep 1;

# scaling
3dTstat -prefix Movie1_preproc_mean_sm6.nii.gz \
Movie1_dstsvrsm6.nii.gz

3dcalc -a Movie1_dstsvrsm6.nii.gz \
-b Movie1_preproc_mean_sm6.nii.gz \
-expr '(a/b)*100' \
-datum float \
-prefix Movie1_preproc_norm_sm6.nii.gz

sleep 1;

#what is this?
paste Movie1_motion.1D Movie1_metric.txt > Movie1_no_interest.1D


#we dont need this
#cat run1_no_interest.1D run2_no_interest.1D run3_no_interest.1D run4_no_interest.1D run5_no_interest.1D run6_no_interest.1D > allruns_no_interest.1D

# functional data of each run are detrended using a Savitzky-Golay filtering by running the matlab script "run_detrend.m"
matlab -nodesktop -r 'run_detrend; exit'

#for run in {1..6}
#do
3dcopy Movie1_sm6_detrend+orig Movie1_sm6_detrend.nii.gz
sleep 1
rm -f Movie1_sm6_detrend+orig*
#done

#concatination of all runs - we dont need this 
#3dTcat -prefix allruns_preproc_norm_sm6_SG.nii.gz \
#run1_sm6_detrend.nii.gz \
#run2_sm6_detrend.nii.gz \
#run3_sm6_detrend.nii.gz \
#run4_sm6_detrend.nii.gz \
#run5_sm6_detrend.nii.gz \
#run6_sm6_detrend.nii.gz


# masking
3dMean -prefix mask_sum.nii.gz Movie1_dstsvrSS_mask.nii.gz 
3dcalc -datum byte -a mask_sum.nii.gz -prefix mask_AND.nii.gz -expr 'equals(a,1)'

# deconvolution
3dDeconvolve -input Movie1_sm6_detrend.nii.gz \  
-mask mask_AND.nii.gz \
-concat '1D: 0 268 493 813 1138 1374' \     #these i think are timepoints of start of each run 
-polort 0 \
-ortvec Movie1_no_interest.1D no_interest \
-nobucket \
-x1D deco_clean_SG.xmat.1D \
-errts Movie1_cleaned_sm6_SG.nii.gz 

exit 0;
