#!/bin/bash
#fMRI preprocessing script by Giacomo Handjaras, Francesca Setti 

# despike
3dDespike \
-prefix run_ds.nii.gz \
-NEW \
run.nii.gz

sleep 1;

# time shift
3dTshift  \
-prefix run_dsts.nii.gz \
-tpattern seq+z \
run_ds.nii.gz

sleep 1;

if [ $run -eq 1 ]
then
	3dTstat -prefix ref_run1.nii.gz run1_dsts.nii.gz
fi

3dvolreg \
-prefix run_dstsvr.nii.gz \
-twopass \
-verbose \
-base ref_run1.nii.gz \
-1Dfile run_motion.1D \
-maxdisp1D run_maxmov.1D \
run_dsts.nii.gz

sleep 1;

fsl_motion_outliers \
-v \
-i run_dsts.nii.gz \
-o run_spikes.1D \
-s run_metric.txt \
-p run_plot.png \

sleep 1;

# smoothing to 6mm
bet run_dstsvr.nii.gz run_dstsvrSS.nii.gz -F

3dBlurToFWHM -prefix run_dstsvrsm6.nii.gz \
-input run_dstsvr.nii.gz \
-mask run_dstsvrSS_mask.nii.gz \
-FWHM 6 

sleep 1;

# scaling
3dTstat -prefix run_preproc_mean_sm6.nii.gz \
run_dstsvrsm6.nii.gz

3dcalc -a run_dstsvrsm6.nii.gz \
-b run_preproc_mean_sm6.nii.gz \
-expr '(a/b)*100' \
-datum float \
-prefix run_preproc_norm_sm6.nii.gz

sleep 1;

#paste run"$run"_motion.1D run"$run"_metric.txt > run"$run"_no_interest.1D



#cat run1_no_interest.1D run2_no_interest.1D run3_no_interest.1D run4_no_interest.1D run5_no_interest.1D run6_no_interest.1D > allruns_no_interest.1D

# functional data of each run are detrended using a Savitzky-Golay filtering by running the matlab script "run_detrend.m"
matlab -nodesktop -r 'run_detrend; exit'
#"/mnt/c/Program Files/MATLAB/R2024b/bin/win64/matlab.exe" -nodesktop -r run_detrend; exit"


3dcopy run_sm6_detrend+orig run_sm6_detrend.nii.gz
sleep 1
rm -f run_sm6_detrend+orig*


3dTcat -prefix allruns_preproc_norm_sm6_SG.nii.gz \
run1_sm6_detrend.nii.gz \
run2_sm6_detrend.nii.gz \
run3_sm6_detrend.nii.gz \
run4_sm6_detrend.nii.gz \
run5_sm6_detrend.nii.gz \
run6_sm6_detrend.nii.gz


# masking
3dMean -prefix mask_sum.nii.gz run*_dstsvrSS_mask.nii.gz 
3dcalc -datum byte -a mask_sum.nii.gz -prefix mask_AND.nii.gz -expr 'equals(a,1)'

# deconvolution
3dDeconvolve -input allruns_preproc_norm_sm6_SG.nii.gz \
-mask mask_AND.nii.gz \
-concat '1D: 0 268 493 813 1138 1374' \
-polort 0 \
-ortvec allruns_no_interest.1D no_interest \
-nobucket \
-x1D deco_clean_SG.xmat.1D \
-errts allruns_cleaned_sm6_SG.nii.gz 

exit 0;
