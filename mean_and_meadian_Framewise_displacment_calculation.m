%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this small script calulcates the mean and median of framewise
% displacement (fd)
%
% created by Tea Tucic
% IMT Lucca, 2025
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Define the root study directory
study_dir = '/home/tea.tucic/2024NatView';  

% List all contents inside the '02_preprocessing' folder
folder_contents = dir(fullfile(study_dir, 'subjects', '02_preprocessing'));

% Filter to get only directories (excluding '.' and '..')
subject_dirs = folder_contents([folder_contents.isdir] & ~ismember({folder_contents.name}, {'.', '..'}));

% Check if any subject directories were found
if isempty(subject_dirs)
    error('No subject directories found. Please check the path.');
end

% Loop through each subject directory
for i = 1:length(subject_dirs)
    subj = subject_dirs(i).name;  % Get subject name

    % Display which subject is being processed
    fprintf('Processing subject: %s\n', subj);

    % Define the path to the FD file
    fd_file = fullfile(study_dir, 'subjects', '02_preprocessing', subj, 'func', 'Movie1_framewise_displacement.txt');
    
    % Check if FD file exists
    if ~isfile(fd_file)
        fprintf('FD file does not exist for subject %s: %s\n', subj, fd_file);
        continue;  % Skip this subject if FD file doesn't exist
    end
    
    % Load the FD values
    fd_values = dlmread(fd_file);  
    
    % Calculate mean and median
    mean_fd = mean(fd_values);
    median_fd = median(fd_values);
    
    % Define the output file for storing results
    output_file = fullfile(study_dir, 'subjects', '02_preprocessing', subj, 'func', 'framewise_displacement_mean_median.txt');
    
    % Write the mean and median values to the output file
    fid = fopen(output_file, 'w');
    fprintf(fid, 'Mean Framewise Displacement: %.4f\n', mean_fd);
    fprintf(fid, 'Median Framewise Displacement: %.4f\n', median_fd);
    fclose(fid);
    
    % Print success message
    fprintf('%s processed successfully. Mean FD: %.4f, Median FD: %.4f\n', subj, mean_fd, median_fd);
end

fprintf('All subjects processed.\n');
