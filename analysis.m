clear all
close all
clc
%% TAKE DATA FROM FOLDER
% directory corrente
Folders = dir(pwd);
dirFlags = [Folders.isdir];
subFolders = Folders(dirFlags);
subFolderNames = {subFolders(3:end).name}; 
subFolderNames = subFolderNames(contains(subFolderNames,'Simulation_Output_'));
% consider the newest folder
PathName = fullfile(pwd, subFolderNames{end});
%% Add all matrixes
addpath(PathName)                   
file_all = dir(fullfile(PathName,'*.mat'));
matfile = file_all([file_all.isdir] == 0); 
clear file_all
%% MATRIX CREATION
N = length(matfile);            
T = 7;                          % Number of Outputs 
Output_Matrix = (zeros(N,T));
Input_Labels =  {'max_dec', 'Time Gap', 'Slope', 'Mass', 'Set speed', 'Af', 'Cd'};
Output_Labels = {'Min TTC','TeT', 'RMS Jerk', 'KWH100KM', 'RMS Spacing Error', 'RMS Rel Vel', 'RMS Set Speed Error'}; 
%% KPIs calculations
dt = 0.1;
for i=1:N
    load(matfile(i).name);
    
    if i == 1 && exist('Input_Parameters', 'var')
        Input_Matrix = Input_Parameters;
        Input_Matrix(:,1) = -1*Input_Matrix(:,1);
    end
    
    % KPI 1: Safety
    Output_Matrix(i,1) = min(ans.TTC);
    % KPI 2: Safety (TeT)
    Output_Matrix(i,2) = sum(dt*ans.TTCI); 
    
    % KPI 3: Comfort (RMS Jerk)
    jerk = [0; diff(ans.Ego_Acceleration) / dt];      
    Output_Matrix(i,3) = sqrt(mean(jerk.^2)); 
    
    % KPI 4: Energy
    P_inst = ans.Instantaneous_power; 
    P_inst(P_inst<0) = 0; 
    Total_Energy = sum(P_inst * dt)/ 3.6e6; 
    Total_distance = max(ans.Ego_Position)/1000; 
    Output_Matrix(i,4) = (Total_Energy/Total_distance)*100; 
    
    % KPI 5: System Req (Spacing)
    Output_Matrix(i,5) = sqrt(mean(ans.Tracking_error.^2));
    
    % KPI 6: System Req (Relative Velocity)
    Output_Matrix(i,6) = sqrt(mean(ans.Relative_velocity.^2));
    
    % KPI 7: System Req (Set Speed)
    Output_Matrix(i,7) = sqrt(mean(ans.Set_speed_error.^2));
end
%% OUTPUT ANALYSIS
Stat_Out(:,1) = mean(Output_Matrix);
Stat_Out(:,2) = var(Output_Matrix);
Stat_Out(:,3) = median(Output_Matrix);
Stat_Out(:,5) = std(Output_Matrix);

% Plot Histograms, Boxplots, and PLOTMATRIX
for i = 1:T
    % 1. Distribution & Boxplot
    figure('Name', ['Dist: ' Output_Labels{i}]);
    subplot(1,2,1); histogram(Output_Matrix(:,i),'Normalization','probability',NumBins=50);
    title(['Dist: ' Output_Labels{i}]);
    subplot(1,2,2); boxplot(Output_Matrix(:,i));
    title(['Boxplot: ' Output_Labels{i}]);
    
    % 2. PLOTMATRIX 
    figure('Name', ['Scatter Matrix: ' Output_Labels{i}]);
    % Plots all 8 Inputs vs the Current Output (last column)
    [S, AX, BigAx, H, HAx] = plotmatrix([Input_Matrix, Output_Matrix(:,i)]);
    title(BigAx, ['Scatter Matrix: Inputs vs ' Output_Labels{i}]);
    
    % Label the axes for clarity
    Matrix_Labels = [Input_Labels, Output_Labels(i)];
    for k = 1:length(Matrix_Labels)
        xlabel(AX(end, k), Matrix_Labels{k}, 'FontSize', 8, 'Rotation', 45); 
        ylabel(AX(k, 1), Matrix_Labels{k}, 'FontSize', 8);   
    end
end

%% QUANTITATIVE ANALYSIS
R_threshold = 0.2;
P_threshold = 0.05;
Index_Sign_Total = cell(1, T);    
for j = 1:T
    fprintf('Processing KPI: %s...\n', Output_Labels{j});
    
    % 1. Identify Significant Variables
    Index_Sign = [];
    [R,P] = corrcoef([Input_Matrix, Output_Matrix(:,j)]);
    
    for k = 1:length(Input_Labels)
        if abs(R(end,k)) >= R_threshold && P(end,k) <= P_threshold
            Index_Sign = [Index_Sign; k];
        end
    end
    Index_Sign_Total{j} = Index_Sign;
    
    % --------------------------------------------------------
    % PLOT 1: HEATMAP (Fixed to show R and P values clearly)
    % --------------------------------------------------------
    figure('Name', ['Correlation: ' Output_Labels{j}]);
    Combined_Data = [Input_Matrix, Output_Matrix(:,j)];
    Matrix_Labels = [Input_Labels, Output_Labels(j)];
    
    [R_sq, P_sq] = corr(Combined_Data);
    
    imagesc(R_sq); colormap(jet); caxis([-1, 1]); colorbar;
    num_vars_total = length(Matrix_Labels);
    
    % Overlay Text
    for x = 1:num_vars_total
        for y = 1:num_vars_total
            r_val = R_sq(y, x);
            p_val = P_sq(y, x);
            if p_val < 0.001, p_str = '<.001'; else, p_str = sprintf('=%.3f', p_val); end
            
            % White text for dark colors, Black for light
            txt_color = 'black';
            if abs(r_val) > 0.5, txt_color = 'white'; end
            
            text(x, y, sprintf('\\bf%.2f\\rm\n{\\fontsize{7}p%s}', r_val, p_str), ...
                'HorizontalAlignment', 'center', 'Color', txt_color);
        end
    end
    xticks(1:num_vars_total); xticklabels(Matrix_Labels); xtickangle(45);
    yticks(1:num_vars_total); yticklabels(Matrix_Labels);
    title(['Correlation Structure: ' Output_Labels{j}]);
    % --------------------------------------------------------
    % PLOT 2: REGRESSION 
    % --------------------------------------------------------
    if isempty(Index_Sign), continue; end
    
    x_significant = Input_Matrix(:, Index_Sign);
    num_vars = length(Index_Sign);
    
    % Normalize
    X_min = min(x_significant); 
    X_max = max(x_significant); 
    X_range = X_max - X_min; 
    X_range(X_range==0)=1;
    X_norm = (x_significant - X_min) ./ X_range;
    
    % Regress
    [beta, ~] = regress(Output_Matrix(:,j), [ones(N,1), X_norm]);
    
    % Plot
    figure('Name', ['Sensitivity: ' Output_Labels{j}]);
    X_mean_norm = mean(X_norm); 
    
    for k = 1:num_vars
        subplot(num_vars, 1, k);
        idx_real = Index_Sign(k);
        
        % A. Scatter Real Data (Blue Dots)
        scatter(Input_Matrix(:, idx_real), Output_Matrix(:,j), 15, 'b', 'filled', 'MarkerFaceAlpha', 0.2);
        hold on;
        
        % B. Plot CLEAN Line (Sweep 0 to 1)
        X_dummy = linspace(0, 1, 100)';
        X_fake = [ones(100,1), repmat(X_mean_norm, 100, 1)];
        X_fake(:, k+1) = X_dummy; % Sweep current var
        
        y_pred = X_fake * beta;
        x_real_axis = X_dummy * X_range(k) + X_min(k);
        
        plot(x_real_axis, y_pred, 'r-', 'LineWidth', 2.5);
        
        xlabel(Input_Labels{idx_real});
        ylabel(Output_Labels{j});
        grid on;
        
        % Calculate Slope
        real_slope = beta(k+1) / X_range(k);
        title(['Slope: ' num2str(real_slope, '%.2e')]);
    end
    % --------------------------------------------------------
    % PLOT 3: 3D PLOT WITH REGRESSION PLANE
    % --------------------------------------------------------
    % Check how many inputs you actually have (M)
    M = length(Input_Labels); 
    
    if num_vars >= 2
        % 1. Get correlations for inputs only
        R_vals = R(end, 1:M); 
        [~, sorted_idx] = sort(abs(R_vals), 'descend');
        
        % Pick the two most correlated inputs
        idx1 = sorted_idx(1); 
        idx2 = sorted_idx(2); 
        
        % REVISION: Instead of ismember, just check if we have the coefficients 
        % in our 'beta' vector to actually draw the plane.
        loc_1 = find(Index_Sign == idx1);
        loc_2 = find(Index_Sign == idx2);
        
        if ~isempty(loc_1) && ~isempty(loc_2)
            figure('Name', ['3D Impact: ' Output_Labels{j}]);
            
            % A. SCATTER REAL DATA
            scatter3(Input_Matrix(:, idx1), Input_Matrix(:, idx2), Output_Matrix(:,j), ...
                30, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
            hold on;
            
            % B. CALCULATE REGRESSION PLANE
            grid_res = 20;
            range_norm = linspace(0, 1, grid_res);
            [M1, M2] = meshgrid(range_norm, range_norm);
            
            % Use X_mean_norm which was calculated in the Regression section
            X_design_surf = [ones(grid_res^2, 1), repmat(X_mean_norm, grid_res^2, 1)];
            
            % Map the meshgrid to the correct beta coefficients
            X_design_surf(:, loc_1 + 1) = M1(:);
            X_design_surf(:, loc_2 + 1) = M2(:);
            
            Z_flat = X_design_surf * beta;
            Z_surf = reshape(Z_flat, grid_res, grid_res);
            
            % C. CONVERT TO REAL UNITS
            X1_real = M1 * X_range(loc_1) + X_min(loc_1);
            X2_real = M2 * X_range(loc_2) + X_min(loc_2);
            
            % D. PLOT
            surf(X1_real, X2_real, Z_surf, 'FaceColor', 'r', 'FaceAlpha', 0.5, 'EdgeColor', 'none');
            
            xlabel(Input_Labels{idx1});
            ylabel(Input_Labels{idx2});
            zlabel(Output_Labels{j});
            grid on; view(135, 30);
            legend('Simulation Data', 'Regression Model');
            title(['Top 2 Significant Drivers: ' Input_Labels{idx1} ' & ' Input_Labels{idx2}]);
        else
            fprintf('Skipping 3D plot for %s: One of the top drivers is not statistically significant.\n', Output_Labels{j});
        end
    
  
    end
end
%% --- FINAL REPORT GENERATION ---
fprintf('\n\n================================================================\n');
fprintf('              ANALYSIS SUMMARY                  \n');
fprintf('================================================================\n');
for j = 1:T
    fprintf('\nKPI #%d: %s\n', j, Output_Labels{j});
    fprintf('----------------------------------------------------------------\n');
    fprintf('%-20s | %-12s | %-12s\n', 'Input Variable', 'Correlation', 'P-Value');
    fprintf('----------------------------------------------------------------\n');
    
    idx_list = Index_Sign_Total{j};
    
    if isempty(idx_list)
        fprintf('  No significant correlations found.\n');
    else
        [R, P] = corrcoef([Input_Matrix, Output_Matrix(:,j)]);
        for k = 1:length(idx_list)
            input_idx = idx_list(k);
            fprintf('%-20s | %12.4f | %12.4e\n', ...
                Input_Labels{input_idx}, R(end, input_idx), P(end, input_idx));
        end
    end
end
Safe_Percentage = sum(Output_Matrix(:, 2)==0)/N;
fprintf('\nPercentage of runs with ZERO safety violations: %.1f%%\n', Safe_Percentage*100);


%% --- CRITICAL FAILURE ANALYSIS (FULL 8 INPUTS) ---
% 1. Find the specific runs where TTC < 0.1
critical_idx = find(Output_Matrix(:,1) < 0.1);

% 2. Extract the Inputs and Outputs for these runs
Critical_Inputs = Input_Matrix(critical_idx, :);
Critical_TTC = Output_Matrix(critical_idx, 1);

% 3. Create a readable table with ALL 8 Inputs
% Note: Converting Slope to Degrees and Speed to km/h for readability
Table_Data = [critical_idx, ...
              Critical_Inputs(:,1), ...           % 1. Max Decel (m/s^2)
              Critical_Inputs(:,2), ...           % 2. Time Gap (s)
              Critical_Inputs(:,3)*(180/pi), ...  % 4. Slope (deg)
              Critical_Inputs(:,4), ...           % 5. Mass (kg)
              Critical_Inputs(:,5)*3.6, ...       % 6. Set Speed (km/h)
              Critical_Inputs(:,6), ...           % 7. Frontal Area (m^2)
              Critical_Inputs(:,7), ...           % 8. Drag Coeff (Cd)
              Critical_TTC];                      % Result: Min TTC

VarNames = {'Run_ID', 'Max_Decel', 'Time_Gap', ...
            'Slope_Deg', 'Mass_kg', 'V_Set_kmh', 'Af', 'Cd', 'Min_TTC'};

Failure_Table = array2table(Table_Data, 'VariableNames', VarNames);

% 4. Display the culprits
fprintf('\n=========================================================================\n');
fprintf('                  CRITICAL FAILURE ANALYSIS (N=%d)                       \n', length(critical_idx));
fprintf('=========================================================================\n');
disp(Failure_Table);

%% REMOVE PATH
rmpath(PathName);