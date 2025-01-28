#!/bin/bash

# bias correction with SPM (optional here)

fslreorient2std mprage.nii.gz mprage_R

antsBrainExtraction.sh \
-d 3 \
-a mprage_R.nii.gz \
-e /home/programmi/ANTS-v.2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz \
-f /home/programmi/ANTS-v.2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumExtractionMask.nii.gz \
-m /home/programmi/ANTS-v.2.3.5-126/templates/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz \
-o mprage_R_

# align anat to epi (optional here)
align_epi_anat.py -anat mprage_R_BrainExtractionBrain.nii.gz -epi ../func/ref_run1.nii.gz -epi_base 0 -anat_has_skull no 


3dQwarp \
-prefix mprage_ICBM_nlin \
-allineate \
-allopt '-cost nmi -automask -twopass -final wsinc5' \
-minpatch 17 \
-useweight \
-blur 0 3 \
-iwarp \
-base /mni_icbm152_nlin_sym_09c/mni_icbm152_t1_tal_nlin_sym_09c_masked.nii.gz \
-source mprage_R_BrainExtractionBrain_al+orig


exit 0;


### comandi per warp serie temporali di ogni tipo

# warp MNI della maschera come sanity check
3dNwarpApply \
-nwarp ../anat/mprage_ICBM_nlin_WARP+tlrc. \
-master /MNI152_mask_3mm.nii.gz \
-interp NN \
-source mask_AND.nii.gz \
-prefix mask_AND_MNInlin.nii.gz

sleep 3;


# warp MNI dei dati con smoothing 6mm
3dNwarpApply \
-nwarp ../anat/mprage_ICBM_nlin_WARP+tlrc. \
-master /MNI152_mask_3mm.nii.gz \
-source allruns_cleaned_sm6.nii.gz \
-prefix allruns_cleaned_sm6_MNInlin.nii.gz

sleep 3;



# savitzky
3dNwarpApply \
-nwarp ../anat/mprage_ICBM_nlin_WARP+tlrc. \
-master /MNI152_mask_3mm.nii.gz \
-source allruns_cleaned_sm6_SG.nii.gz \
-prefix allruns_cleaned_sm6_SG_MNInlin.nii.gz


