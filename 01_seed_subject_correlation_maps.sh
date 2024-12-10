#!/bin/bash

# This code carries out seed based mapping for multiple ts and
# multiple seeds. You should manually draw the seeds before
# running this code. You may want to draw the seeds where you
# seed inter-group differences measured with global connectivity
# as in Pagani et al NatComm 2020 (Figure 1). The output is a
# voxelwise pearson's correlation map for each ts and each seed,
# that you will use for intergroup comparisons (e.g. wild-type
# mice vs ko mice).
#
# -----------------------------------------------------------
# Script written by Marco Pagani
# Functional Neuroimaging Lab,
# Istituto Italiano di Tecnologia, Rovereto
# (2018)
# -----------------------------------------------------------


path_ts=$PWD/01_subjects/ # edit this, folder containing ts
path_seeds=$PWD/02_seeds/ # edit this, folder containing seeds

numjobs=7


function warnings_seed_names {
  seed=$1
  seed_name=$(basename $seed .nii.gz)
  SUB='_' #offending character

  if [[ "$seed_name" == *"$SUB"* ]]; then
    echo -e "\e[43m {$seed_name}: Please use a seed name without underscores (_), as this might be problematic for group-level analyses\e[0m"
  fi
}

function seed_subject_correlation_map {
    ts=$1
    seed=$2
    brainmask=/home/seed_based_bug/chd8_functional_template_mask.nii.gz #edit this

    subj_name=$(basename $ts .nii.gz)
    seed_name=$(basename $seed .nii.gz)

    # calculate seed ts
    fslmeants \
	-i $ts \
	-m $seed \
	-o 03_subject_maps/${subj_name}_${seed_name}.txt

    # calculate correlation map
    3dTcorr1D \
        -prefix 03_subject_maps/${subj_name}_${seed_name}_r.nii.gz \
        -mask $brainmask \
        $ts \
        03_subject_maps/${subj_name}_${seed_name}.txt

    # convert to z
    3dcalc \
        -a 03_subject_maps/${subj_name}_${seed_name}_r.nii.gz \
        -expr 'atanh(a)' \
        -prefix 03_subject_maps/${subj_name}_${seed_name}_z.nii.gz
}
export -f seed_subject_correlation_map

# Main starts here

echo $path_ts/ag*.nii.gz | tr " " "\n" > tslist.txt
echo $path_seeds/*.nii.gz | tr " " "\n" > seedlist.txt

mkdir 03_subject_maps


while read -r seed;
	do
	warnings_seed_names $seed
	done < seedlist.txt

while read -r seed;
do
    parallel \
        -j $numjobs \
        seed_subject_correlation_map {} $seed \
        < tslist.txt
done < seedlist.txt
