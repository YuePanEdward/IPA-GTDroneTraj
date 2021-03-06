% Matlab codes for the automatic control of a Leica total station (TS50/60,
% TPS 1200, etc.)
% By Yue Pan @ ETHZ IGP 
% IPA project: Measuring Drone Trajectory using Total Stations with Visual Tracking

% Note! You shall open another matlab window for the automatic audio
% triggering

%%
clear; clc; close all;
addpath(['..' filesep '..' filesep 'common']);
mkdir ('results');

%% Set GeoCOM port, dB (Baud) rate
% For TPS1200, set it in configure->interfaces setting->GSI/GeoCOM mode on

% For Nova TS 50/60, set it in (TODO)

% COM port number (check in the device manager)
% COMPort = '/dev/ttyUSB1';  %on Linux
COMPort = 'COM4';            %on Windows

% dB (Baud) rate
%dB = 115200;
dB = 19200;
%dB=9600;

%% Set PRSIM TYPE
% PRISM_ROUND = 0,
% PRISM_MINI = 1,
% PRISM_TAPE = 2,
% PRISM_360 = 3,     [used,large one]
% PRISM_USER1 = 4,
% PRISM_USER2 = 5,
% PRISM_USER3 = 6,
% PRISM_360_MINI = 7, [used,small one]
% PRISM_MINI_ZERO = 8,
% PRISM_USER = 9
% PRISM_NDS_TAPE = 10
prism_type = 7; 

%% Set TARGET TYPE
% REFLECTOR_TARGET = 0
% REFLECTORLESS_TARGET = 1
target_type = 0; 

%% Automatic Target Recognition (ATR) on or not
atr_state = 0; % ATR state on (1)

%%
% ANGLE MEASUREMENT TOLERANCE
% The maximum resolution of the angle measurement system depends on the instrument accuracy class. If
% smaller positioning tolerances are required, the positioning time can increase drastically.
% For Nova TS-50/60
% RANGE FROM 1[cc] ( =1.57079 E-06[ rad ], highest resolution, slowest) 
% TO 100[cc] ( =1.57079 E-04[ rad ], lowest resolution, fastest)
% For TPS-1200, the value can be a bit higher for faster performance
hz_tol = 1.57079e-04; % Horizontal tolerance (moderate resolution) 
v_tol = 1.57079e-04; % Vertical tolerance (moderate resolution)

%%
% DISTANCE MEASUREMENT MODE
% IR-Mode: Dist. Meas. With Reflector
% SINGLE_REF_STANDARD = 0,
% SINGLE_REF_FAST = 1,      [IR Fast]
% SINGLE_REF_VISIBLE = 2    [LO Standard]
% SINGLE_RLESS_VISIBLE = 3,
% CONT_REF_STANDARD = 4,    [used, IR Tracking]
% CONT_REF_FAST = 5,
% CONT_RLESS_VISIBLE = 6,
% AVG_REF_STANDARD = 7,
% AVG_REF_VISIBLE = 8,
% AVG_RLESS_VISIBLE = 9
% CONT_REF_SYNCHRO = 10;
% SINGLE_REF_PRECISE = 11;

distmode =4; % Default distance mode (from BAP_SetMeasPrg)  4
 
%% Open port, connect to TPS
TPSport = connect_tps(COMPort, dB);

%ts_start = tps_now(TPSport); % in 12, out 34  (byte) , transmission time ~20ms; total consuming time ~42ms

%% Configure TPS for measurements
set_properties_tps(TPSport, prism_type, target_type, atr_state, hz_tol, v_tol); 

% check face (if is face II, change to face I)
% change_face(TPSport);

%% Begin tracking
begin_time_str = datestr(now,'yyyymmddHHMMSS');  % get current time

% figure for listening the keyboard event
figure(1);
plot3(0,0,0,'o','MarkerEdgeColor','k','MarkerFaceColor','k','MarkerSize',12);
hold on;
grid on;
axis equal;
set(gca, 'Fontname', 'Times New Roman','FontSize',12);
title('Enter E on the keyboard to terminate the tracking', 'Fontname', 'Times New Roman','FontSize',16); % but remember not to press 'e' too many times
xlabel('X(m)','Fontname', 'Times New Roman','FontSize',14);
ylabel('Y(m)','Fontname', 'Times New Roman','FontSize',14);
zlabel('Z(m)','Fontname', 'Times New Roman','FontSize',14);
pause(1.0); % pause for 1 second

meas_polar=[];
meas_cart=[];
meas_ts=[];
meas_status =[];   %0: ok, 1: warning, 2: error, 3: fatal
meas_count = 0;

track_status = track_prism(TPSport); % track the prism ?begining)

if(strcmpi(get(gcf,'CurrentCharacter'),'e'))
   disp('Please press any key except for [E]'); 
   pause(5.0);
end

error_count=0; 
error_count_thre=50;  % tolerance for the continous measurements with problem % ~ 6 seconds

ms_in_day = 1/24/3600/1000;

% keep take measurements (both in polar and cartesian coordinate systems)
while(1)
    
     % to stop the tracking, press pause first, press [E] and then resume
    if (meas_count > 1 && strcmpi(get(gcf,'CurrentCharacter'),'e')) 
          disp('[E] is pressed, terminate the tracking.'); 
          break;
    end
   
    %pause(0.001); % wait for 1 ms
         
    meas_count=meas_count+1;
    fprintf('Measurement [%s]\n',num2str(meas_count));
    
    % take measurement
    [D,Hr,V,cur_meas_ts,status] = getMeasurements(TPSport, distmode);   % in 14, out 68  (byte),  transmission time ~35ms , cnsuming time ~110ms
    
    % the following codes takes only about 1ms.
    
    % depend on the tracking status
    if (status==3 || error_count > error_count_thre) % fatal
        break; % don't record this error measurement
    elseif (status==2) % error
         error_count=error_count+1; 
    else   % warning or well
          error_count=0;  % restart the count
    end
    
    meas_status = [meas_status; status];
    meas_polar = [meas_polar; [D,Hr,V]]; % in m, deg, deg
    [X,Y,Z]= polar2cart(D,Hr,V); % convert to cartesian coordinate system
    
    fprintf('x = %.3f [m]; y = %.3f [m]; z = %.3f [m]\n',X,Y,Z); % in meter
    meas_cart = [meas_cart; [X,Y,Z]]; % in m, m, m
   
    meas_ts = [meas_ts; cur_meas_ts]; % record the timestamp in datenum
     
%     if (status<2)  % warning or well   
%          scatter3(X,Y,Z,20,'ro','filled'); % plot in real-time (took ~ 10ms, too much)
%     end
    
%     if(meas_count==300)  % define a checking point
%          ;
%     end
end

%% save coordinates
mkdir ('results',  begin_time_str);
save(['results' filesep begin_time_str filesep 'meas_cart_' begin_time_str '.mat'],'meas_cart');
save(['results' filesep begin_time_str filesep 'meas_polar_' begin_time_str '.mat'],'meas_polar');
save(['results' filesep begin_time_str filesep 'meas_ts_' begin_time_str '.mat'],'meas_ts');
save(['results' filesep begin_time_str filesep 'meas_status_' begin_time_str '.mat'],'meas_status');
disp('Save done');

%% plot results 
% If you just want to use the example data and plot the results, please
% just run this block

%begin_time_str='20210104111312';  % example data 1
begin_time_str='20210119155250';  % example data 2 

load(['results' filesep begin_time_str filesep 'meas_cart_' begin_time_str '.mat'],'meas_cart');
load(['results' filesep begin_time_str filesep 'meas_status_' begin_time_str '.mat'],'meas_status');
load(['results' filesep begin_time_str filesep 'meas_ts_' begin_time_str '.mat'],'meas_ts');

meas_ts_vec = datevec(meas_ts); % [YYYY, MM, DD, hh, mm, ss.sss]
time_origin = meas_ts(1); % important, project time origin

meas_ts_s_project = (meas_ts-time_origin)*24*3600; % shifted project time (unit: s)  
meas_ts_interval = meas_ts_s_project(2:end) - meas_ts_s_project(1:end-1);

% tracking trajectory
figure(2);
plot3(0,0,0,'o','MarkerEdgeColor','k','MarkerFaceColor','k','MarkerSize',12);
hold on;
plottraj(meas_cart, meas_status);
grid on;
axis equal;
set(gca, 'Fontname', 'Times New Roman','FontSize',16);
xlabel('X(m)','Fontname', 'Times New Roman','FontSize',18);
ylabel('Y(m)','Fontname', 'Times New Roman','FontSize',18);
zlabel('Z(m)','Fontname', 'Times New Roman','FontSize',18);
legend('Total station', 'Drone - start', 'Drone - end','Fontname', 'Times New Roman','FontSize',20);
title('Prism position measured by the total station','Fontname', 'Times New Roman','FontSize',24);

% tracking status
figure(3);
plot(meas_ts_s_project, meas_status, 'Linewidth', 3);
grid on;
set(gca, 'Fontname', 'Times New Roman','FontSize',14);
xlabel('Time (s)','Fontname', 'Times New Roman','FontSize',16);
ylabel('tracking status','Fontname', 'Times New Roman','FontSize',16);
%xlim([0,200]);
ylim([0,2]);
yticks([0,1,2]);
title('Tracking status','Fontname', 'Times New Roman','FontSize',20);


figure(4);
plot(meas_ts_interval, 'Linewidth', 3);
grid on;
set(gca, 'Fontname', 'Times New Roman','FontSize',14);
xlabel('Measurement index','Fontname', 'Times New Roman','FontSize',16);
ylabel('interval (s)','Fontname', 'Times New Roman','FontSize',16);
ylim([0,1.0]);
title('Tracking sampling interval','Fontname', 'Times New Roman','FontSize',20);
