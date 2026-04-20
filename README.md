# Testing and Validation of a standard ACC system

## Project Overview
This project focuses on the testing and validation of an automated road vehicle, specifically evaluating a standard Adaptive Cruise Control (ACC) system. The primary goal is to evaluate the safety, comfort, and efficiency of the ACC controller under stochastic (randomized) driving conditions. 

The evaluation framework relies on modeling the system, defining nominal parameters, generating input factors through Latin Hypercube Sampling (LHS), and running batch simulations to collect and analyze key performance metrics.

## System Architecture: Adaptive Cruise Control (ACC)
The System Under Test (SUT) is a longitudinal ACC controller that calculates desired acceleration based on the ego-vehicle's speed, relative distance to the leader vehicle, and relative speed. 

The system operates in two main modes:
* **Speed Control Mode**: If there is no vehicle ahead, or if the actual relative distance is greater than or equal to the safe distance, the vehicle aims to maintain the driver's desired set speed.
* **Spacing Control Mode**: If the relative distance is less than the safe distance, the vehicle slows down to maintain the calculated safe distance.

**Leader Vehicle Scenario:** * The target vehicle (leader) follows the standard **FTP72 drive cycle** to simulate realistic, transient velocity profiles.

## Simulation Methodology
To efficiently cover the parameter space and test the controller under varying environments and vehicle configurations, the project utilizes **Latin Hypercube Sampling (LHS)** for 200 simulation runs. 

The following 7 independent input variables are randomized:
1.  **Maximum Deceleration** (`min_ac`): Minimum bounds of braking authority [-9.0 to -2.5 $m/s^2$].
2.  **Time Gap**: Driver-selected time gap [1.5 to 2.5 $s$].
3.  **Slope**: Environmental road gradient [-3 to 3 degrees].
4.  **Mass**: Total vehicle mass [1200 to 2000 $kg$].
5.  **Set Speed**: The target cruising speed [15 to 25 $m/s$].
6.  **Frontal Area ($A_f$)**: For aerodynamic drag calculations [1.8 to 2.6 $m^2$].
7.  **Drag Coefficient ($C_d$)**: Vehicle aerodynamic efficiency [0.25 to 0.40].

*Note: The sampling methodology includes automated validation to ensure uniform distribution checks and independence (zero correlation) among input variables prior to simulation execution.*

## Key Performance Indicators (KPIs)
The simulation outputs are assessed across four main categories:

**1. Safety**
* **Minimum Time To Collision (TTC)**: Evaluates the lowest predicted time until a crash if both vehicles maintained their current paths and velocities.
* **Time Exposed to TTC (TET)**: The total accumulated duration during the trip where the TTC falls below a specified critical threshold.

**2. Comfort**
* **RMS Jerk**: Quantifies the continuous oscillation and roughness of acceleration over time, serving as a direct metric for passenger comfort and motion sickness.

**3. Energy Efficiency**
* **kWh per 100 km**: An efficiency metric that integrates positive instantaneous power and normalizes total energy usage over the total distance traveled.

**4. System Requirements**
* **RMS Tracking Error**: Measures the root mean square difference between the desired safe distance and actual relative distance to quantify obedience to the time-gap policy.
* **RMS Relative Velocity**: Measures speed differences between vehicles to identify "nervous" controllers that constantly hunt for target speeds.
* **RMS Set Speed Error**: Measures the deviation between the driver's selected speed and actual vehicle speed, influenced by traffic obstructions.

## Key Findings & Analysis Highlights
* **Safety Dependency**: The user-selected **Time Gap** is the overwhelmingly dominant determinant of safety. A high negative correlation (-0.90) exists between Time Gap and TET, meaning larger gaps drastically reduce exposure to dangerous scenarios.
* **Ride Comfort**: Comfort is negatively correlated with Time Gap (-0.59) and positively correlated with Set Speed (0.35). Larger time gaps allow the controller to filter out the leader's velocity noise, yielding smoother accelerations. Conversely, higher set speeds force sharper, more aggressive accelerations.
* **Energy Efficiency**: Energy consumption (kWh/100km) is strictly dictated by the physical plant (Mass, Aerodynamics), the environment (Slope), and the Set Speed.
* **Controller Reliability**: Overall, the standard ACC gains are robustly tuned. [cite_start]In 99.5% of the simulated stochastic runs, the minimum TTC remained above 0.1s. 

## Repository Structure
* `MAIN.m`: The primary simulation script. It defines nominal parameters, executes LHS to generate input spaces, validates sampling distributions, and runs the Simulink model (`Model.slx`) in a batch loop. Simulation outputs are dynamically routed to timestamped output folders.
* `ANALYSIS.m`: The data processing script. It automatically aggregates data from the generated output folders, calculates all 7 KPIs, and generates statistical plots including distributions, boxplots, multi-variable scatter matrices, correlation heatmaps, and 3D regression planes. It also outputs a critical failure analysis report to the console.
* `Model.slx`: The Simulink model representing the longitudinal dynamics of the ego vehicle and the ACC control logic (Requires MATLAB/Simulink).

## How to Run
1.  Open MATLAB.
2.  Ensure `MAIN.m`, `ANALYSIS.m`, and `Model.slx` are in the same working directory.
3.  Run `MAIN.m`. This will execute 200 simulations and create a new directory named `Simulation_Output_YYYY-MM-DD_HH-mm` containing the `.mat` results for each run.
4.  Run `ANALYSIS.m`. This script will automatically detect the newest output folder, load the matrices, compute the KPIs, and generate analytical figures and statistical reports.

## Credits
* **Performed by**: Sameh Alshaarawy (Matricola: D18000042) 
* **Supervised by**: Angelo Coppola 
