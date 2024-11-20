%matlab
%clc;
clearvars;
warning 'off';
addpath('/matlab/');
for i=1:6
clear dati_soggetto results_soggetto DATI DATI_puliti

dati_soggetto=strcat('/sub-003/ses-aud/func/run',num2str(i),'_preproc_norm_sm6.nii.gz');

%
%run2_preproc_norm.nii.gz
%run3_preproc_norm.nii.gz
%run4_preproc_norm.nii.gz
%run5_preproc_norm.nii.gz
%run6_preproc_norm.nii.gz



%file maschera
maschera_soggetto='/sub-003/ses-aud/func/mask_AND.nii.gz';

%results
results_soggetto=strcat('/sub-003/ses-aud/func/run', num2str(i) ,'_sm6_detrend+orig');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%Apriamo la maschera
disp(sprintf('Apro il file %s di maschera...', str2mat(maschera_soggetto)));
[err, MASK, InfoM, ErrMessage] = BrikLoad (maschera_soggetto);
[x_m,y_m,z_m]=size(MASK);


%%%%Apriamo i dati fmri
disp(sprintf('Apro il file %s di dati fMRI...', str2mat(dati_soggetto)));
[err, DATI, InfoD, ErrMessage] = BrikLoad (dati_soggetto);
[x,y,z,t]=size(DATI);


DATI_puliti=zeros(size(DATI));


for i=1:x
for j=1:y
for k=1:z

if (MASK(i,j,k)>0)
timeserie=squeeze(DATI(i,j,k,:));

%media_timeserie=mean(timeserie);

%p = polyfit([1:numel(timeserie)]',timeserie,8);
%sgf = polyval(p,[1:numel(timeserie)]');

sgf = sgolayfilt(timeserie,3,201);
timeserie_cleaned=timeserie-sgf;
%timeserie_cleaned=timeserie_cleaned+media_timeserie;
DATI_puliti(i,j,k,:)=timeserie_cleaned(:);
end

end
end
disp(sprintf('Processato fetta %d...', i));
end


Opt.Prefix = results_soggetto;
[err, ErrMessage, Info] = WriteBrik (DATI_puliti, InfoD, Opt);


end



