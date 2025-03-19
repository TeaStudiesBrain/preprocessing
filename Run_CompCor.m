addpath('/home/tea.tucic/matlab/DPABI_V8.2_240510/DPARSF/Subfunctions')
addpath('/home/tea.tucic/matlab/DPABI_V8.2_240510/Subfunctions')
addpath('/home/tea.tucic/matlab/spm12')

ADataDir = '/home/tea.tucic/2024NatView/subjects/02_preprocessing/subj3/func/Movie1_motion_corrected.nii.gz';

OutputName = '/home/tea.tucic/2024NatView/subjects/02_preprocessing/subj3/func/wm_CompCorPCs' ;

PCNum = 5;

Nuisance_MaskFilename = '/home/tea.tucic/2024NatView/subjects/02_preprocessing/subj3/func/eroded_wm_mask.nii.gz' ;

IsNeedDetrend = 1;
Band = [];
TR = [];
IsVarianceNormalization = 1;

[PCs] = y_CompCor_PC(ADataDir,Nuisance_MaskFilename, OutputName, PCNum, IsNeedDetrend, Band, TR, IsVarianceNormalization) ;


