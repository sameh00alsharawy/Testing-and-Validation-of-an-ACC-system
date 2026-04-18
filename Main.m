%% CLREAR ALL AND CLOSE ALL
close all
clear all
clc

%% NOMINAL PARAMETERS
% VEHICLE DYNAMICS PARAMETERS
m = 1430;                       %Vehicle's Mass [kg]
Af = 2.46;                      %Frontal area [m^2]
Cd = 0.29;                      %Air-drag coefficient
Cr = 1.75;                      %rolling resistance w.r.t. tyre type
c1 = 0.0328;                    %rolling resistance w.r.t. surface type
c2 = 4.575;                     %rolling resistance w.r.t. surface condition
g = 9.81;                       %gravity acceleration [m/s^2]
slope = 0;
rho_air = 1.2256;               %density air [kg/m^3]

% (ACC) CONTROLLER PARAMETER
time_gap        = 1.5;      % ACC time gap                          (s)
standstill_distance = 1.5;  % ACC default spacing                   (m)
verr_gain       = 0.5;      % ACC velocity error gain               (N/A)
xerr_gain       = 0.2;      % ACC spacing error gain                (N/A)
vx_gain         = 0.4;      % ACC relative velocity gain            (N/A)
max_ac          = 2;        % Maximum acceleration                  (m/s^2)
min_ac          = -3;       % Minimum acceleration                  (m/s^2)
V_set           = 25;
% INITIAL CONDITIONS
x_ego = 0;                      % initial position [m]
v_ego = 1;
x_leader = 30;
v_leader = 1;
ego_length = 4;

%% CREATE A MATRIX OF THE INPUT FACTORS
Labels = {'min_ac', 'Time Gap', 'Slope ', 'Mass (kg)', 'Set speed', 'Af', 'Cd'};

min_ac_bound   = [-9.0, -2.5];  
time_gap_bound = [1.5, 2.5];      
slope_bound = [-3, 3]*(pi/180);         
m_bound     = [1200, 2000];    
V_set_bound    = [15, 25];               %m/s
Af_bound        = [1.8, 2.6];       % Frontal Area [m^2]
Cd_bound        = [0.25, 0.40];     % Drag Coefficient [-]

N = 200; %number of simulation runs
M = length(Labels); %number of inputs
rng(42); 
LHS = lhsdesign(N, M); 

min_ac_vec   = min_ac_bound(1) + (min_ac_bound(2)-min_ac_bound(1)) * LHS(:,1);
time_gap_vec = time_gap_bound(1) + (time_gap_bound(2)-time_gap_bound(1)) * LHS(:,2);
slope_vec    = slope_bound(1) + (slope_bound(2)-slope_bound(1)) * LHS(:,3);
m_vec        = m_bound(1) + (m_bound(2)-m_bound(1)) * LHS(:,4);
V_set_vec    = V_set_bound(1)+(V_set_bound(2)-V_set_bound(1))*LHS(:,5);
Af_vec       = Af_bound(1) + (Af_bound(2)-Af_bound(1)) * LHS(:,6);
Cd_vec       = Cd_bound(1) + (Cd_bound(2)-Cd_bound(1)) * LHS(:,7);

% Combine
Input_Parameters = [min_ac_vec, time_gap_vec, slope_vec, m_vec, V_set_vec, Af_vec, Cd_vec];

% Calculate Theoretical Stats for all 8 variables
[Stat(1,1), Stat(1,2)] = unifstat(min_ac_bound(1), min_ac_bound(2));
[Stat(2,1), Stat(2,2)] = unifstat(time_gap_bound(1), time_gap_bound(2));
[Stat(3,1), Stat(3,2)] = unifstat(slope_bound(1), slope_bound(2));
[Stat(4,1), Stat(4,2)] = unifstat(m_bound(1), m_bound(2));
[Stat(5,1), Stat(5,2)] = unifstat(V_set_bound(1), V_set_bound(2));    
[Stat(6,1), Stat(6,2)] = unifstat(Af_bound(1), Af_bound(2));       
[Stat(7,1), Stat(7,2)] = unifstat(Cd_bound(1), Cd_bound(2));       

Stat_estimate(:,1) = mean(Input_Parameters);
Stat_estimate(:,2) = var(Input_Parameters);
Stat_estimate(:,3) = median(Input_Parameters);
Stat_estimate(:,4) = mode(Input_Parameters);
Stat_estimate(:,5) = std(Input_Parameters);
Stat_estimate(:,6) = skewness(Input_Parameters);

%% --- Input VALIDATION  ---

% --- VALIDATION REPORT ---
fprintf('\n=============================================================================================\n');
fprintf('                           SAMPLING QUALITY CHECK (LHS N=%d)                                 \n', N);
fprintf('=============================================================================================\n');
fprintf('%-15s | %-10s %-10s %-9s | %-10s %-10s %-9s\n', ...
    'Variable', '   Th. Mean', '   Act. Mean', '   Err %', '   Th. Var', '   Act. Var', '   Err %');
fprintf('---------------------------------------------------------------------------------------------\n');

for k = 1:M
    % 1. MEAN CALCULATION
    theory_mean = Stat(k,1);
    actual_mean = Stat_estimate(k,1);
    
    % Handle division by zero for centered variables (Slope, V_Leader, min_ac potentially)
    if abs(theory_mean) < 1e-6
        mean_err = abs(theory_mean - actual_mean);
        mean_tag = '(Abs)'; % Mark that this is absolute error, not percent
    else
        mean_err = abs((theory_mean - actual_mean)/theory_mean) * 100;
        mean_tag = '%    ';
    end
    
    % 2. VARIANCE CALCULATION
    theory_var = Stat(k,2);
    actual_var = Stat_estimate(k,2);
    var_err = abs((theory_var - actual_var)/theory_var) * 100;
    
    % 3. PRINT ROW
    fprintf('%-15s | %10.4f %10.4f %8.2f%s | %10.4f %10.4f %8.2f%%\n', ...
        Labels{k}, theory_mean, actual_mean, mean_err, mean_tag, ...
        theory_var, actual_var, var_err);
end
fprintf('---------------------------------------------------------------------------------------------\n');

% Independence Check
avg_corr = mean(abs(corr(Input_Parameters) - eye(M)), 'all');
fprintf('Average Correlation between Inputs: %.4f (Target: 0.0000)\n', avg_corr);
fprintf('=============================================================================================\n');

figure();
plotmatrix(Input_Parameters)

figure();
for i = 1:M
    subplot(2, 4, i); 
    histogram(Input_Parameters(:,i), 'Normalization', 'probability', NumBins=20);
    xlabel(Labels{i});
    ylabel("Relative Probability")
    title(Labels{i});
end



%%
cartella = strcat('Simulation_Output_', string(datetime('now','Format','yyyy-MM-dd''_''HH-mm')));
mkdir(cartella)
PathName = 'C:\Users\sameh\OneDrive - Università di Napoli Federico II\Documents\10-Testing and validation\project2025\Project_Material\New folder'; %cambiare percorso se necessario
addpath(PathName)  


%% SIMULATION LOOP
N = length(Input_Parameters(:,1));
digitsN =  floor(log10(N))+1;
for i = 1:N
    min_ac   = Input_Parameters(i,1);
    time_gap = Input_Parameters(i,2);
    slope    = Input_Parameters(i,3);
    m        = Input_Parameters(i,4);
    V_set    = Input_Parameters(i,5);
    Af       = Input_Parameters(i,6);
    Cd       = Input_Parameters(i,7);
    sim('Model.slx');        % run simulation
    disp(i)
    Input = [min_ac time_gap slope m V_set Af Cd];

    % MOVE THE SIMULATION OUTPUT INTO A DEDICATED FOLDER
    attuale = cd;
    digitsi = floor(log10(i))+1;
    padding = digitsN - digitsi;
    paddstr = '';
    for j = 1:padding
        paddstr = strcat(paddstr, '0');
    end
    name = strcat('Simulation_',paddstr,num2str(i),'.mat'); 
    save(name)
    movefile(name,cartella)
end

