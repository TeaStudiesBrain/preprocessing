#!/bin/bash
#fMRI preprocessing script by Giacomo Handjaras, Francesca Setti 

for run in 1 2 3 4 5 6 control   #bc in their experiment they have 6 runs for each participant 

do
# despike
3dDespike \
-prefix run"$run"_ds.nii.gz \    #output name
-NEW \                           #Activates the newer despiking algorithm
run"$run".nii.gz                 #input file 

sleep 1;

# time shift
3dTshift  \
-prefix run"$run"_dsts.nii.gz \  #output name
-tpattern seq+z \                #seq+z means the slices were acquired sequentially (not interleaved) from bottom to top along the z-axis
run"$run"_ds.nii.gz              #inout file (despiked from the previous step)

sleep 1;

if [ $run -eq 1 ]                #This checks if the current run ($run) is the first run (1) It ensures that the reference volume (ref_run1.nii.gz) is only created for the first run, as all subsequent runs will use this same reference for alignment
then
	3dTstat -prefix ref_run1.nii.gz run1_dsts.nii.gz      #An AFNI command that computes statistical summaries of a dataset along the time axis
                                                              #creates a mean volume across all time points, which serves as the reference for motion correction 
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
bet run"$run"_dstsvr.nii.gz run"$run"_dstsvrSS.nii.gz -F     #remove non-brain areas

3dBlurToFWHM -prefix run"$run"_dstsvrsm6.nii.gz \
-input run"$run"_dstsvr.nii.gz \
-mask run"$run"_dstsvrSS_mask.nii.gz \
-FWHM 6 

sleep 1;

# scaling
3dTstat -prefix run"$run"_preproc_mean_sm6.nii.gz \     #computes mean of each voxel time series
run"$run"_dstsvrsm6.nii.gz                            

3dcalc -a run"$run"_dstsvrsm6.nii.gz \                  #The original smoothed data (numerator)
-b run"$run"_preproc_mean_sm6.nii.gz \                  #The mean intensity (denominator)
-expr '(a/b)*100' \                                     #converts the time series into percent signal change
-datum float \                                          #output data type is a floating-point number
-prefix run"$run"_preproc_norm_sm6.nii.gz

sleep 1;

paste run"$run"_motion.1D run"$run"_metric.txt > run"$run"_no_interest.1D

done

cat run1_no_interest.1D run2_no_interest.1D run3_no_interest.1D run4_no_interest.1D run5_no_interest.1D run6_no_interest.1D > allruns_no_interest.1D

# functional data of each run are detrended using a Savitzky-Golay filtering by running the matlab script "run_detrend.m"
matlab -nodesktop -r 'run_detrend; exit'

for run in {1..6}
do
3dcopy run"$run"_sm6_detrend+orig run"$run"_sm6_detrend.nii.gz            #Converts the detrended functional data from AFNI format (+orig) to NIfTI format (.nii.gz)
sleep 1
rm -f run"$run"_sm6_detrend+orig*                                         #Deletes the AFNI format files
done

3dTcat -prefix allruns_preproc_norm_sm6_SG.nii.gz \                       #Concatenates all the preprocessed, detrended runs into a single 4D dataset
run1_sm6_detrend.nii.gz \
run2_sm6_detrend.nii.gz \
run3_sm6_detrend.nii.gz \
run4_sm6_detrend.nii.gz \
run5_sm6_detrend.nii.gz \
run6_sm6_detrend.nii.gz


# masking
3dMean -prefix mask_sum.nii.gz run*_dstsvrSS_mask.nii.gz                                     #Creates a mean mask by averaging the brain masks from all runs
3dcalc -datum byte -a mask_sum.nii.gz -prefix mask_AND.nii.gz -expr 'equals(a,1)'            #Creates a final intersection mask (mask_AND.nii.gz) that includes only voxels consistently present across all run. 'equals(a,1)' ensures only those voxels that are present in all masks are retained.

# deconvolution
3dDeconvolve -input allruns_preproc_norm_sm6_SG.nii.gz \
-mask mask_AND.nii.gz \
-concat '1D: 0 268 493 813 1138 1374' \                                                 #time where each run starts in the concatenated dataset
-polort 0 \
-ortvec allruns_no_interest.1D no_interest \
-nobucket \
-x1D deco_clean_SG.xmat.1D \
-errts allruns_cleaned_sm6_SG.nii.gz 

exit 0;
