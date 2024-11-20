#!/bin/bash
#fMRI preprocessing script by Giacomo Handjaras, Francesca Setti 

for run in 1 2 3 4 5 6 control

do
# despike
3dDespike \
-prefix run"$run"_ds.nii.gz \
-NEW \
run"$run".nii.gz

sleep 1;

# time shift
3dTshift  \
-prefix run"$run"_dsts.nii.gz \
-tpattern seq+z \
run"$run"_ds.nii.gz

sleep 1;

if [ $run -eq 1 ]
then
	3dTstat -prefix ref_run1.nii.gz run1_dsts.nii.gz
fi

3dvolreg \
-prefix run"$run"_dstsvr.nii.gz \
-twopass \
-verbose \
-base ref_run1.nii.gz \
-1Dfile run"$run"_motion.1D \
-maxdisp1D run"$run"_maxmov.1D \
run"$run"_dsts.nii.gz

sleep 1;

fsl_motion_outliers \
-v \
-i run"$run"_dsts.nii.gz \
-o run"$run"_spikes.1D \
-s run"$run"_metric.txt \
-p run"$run"_plot.png \

sleep 1;

# smoothing to 6mm
bet run"$run"_dstsvr.nii.gz run"$run"_dstsvrSS.nii.gz -F

3dBlurToFWHM -prefix run"$run"_dstsvrsm6.nii.gz \
-input run"$run"_dstsvr.nii.gz \
-mask run"$run"_dstsvrSS_mask.nii.gz \
-FWHM 6 

sleep 1;

# scaling
3dTstat -prefix run"$run"_preproc_mean_sm6.nii.gz \
run"$run"_dstsvrsm6.nii.gz

3dcalc -a run"$run"_dstsvrsm6.nii.gz \
-b run"$run"_preproc_mean_sm6.nii.gz \
-expr '(a/b)*100' \
-datum float \
-prefix run"$run"_preproc_norm_sm6.nii.gz

sleep 1;

paste run"$run"_motion.1D run"$run"_metric.txt > run"$run"_no_interest.1D

done

cat run1_no_interest.1D run2_no_interest.1D run3_no_interest.1D run4_no_interest.1D run5_no_interest.1D run6_no_interest.1D > allruns_no_interest.1D

# functional data of each run are detrended using a Savitzky-Golay filtering by running the matlab script "run_detrend.m"
matlab -nodesktop -r 'run_detrend; exit'

#"/mnt/c/Program Files/MATLAB/R2024b/bin/matlab" -nodesktop -r 'run_detrend; exit'

for run in {1..6}
do
3dcopy run"$run"_sm6_detrend+orig run"$run"_sm6_detrend.nii.gz
sleep 1
rm -f run"$run"_sm6_detrend+orig*
done

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
