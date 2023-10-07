function dataStruct = createDataStructure()

% create experiment dataStruct from the single 'dataStruct_store'.xlsx'
%
% 57 subjects (1:28 PAT, 29:57 CON)
% the sample (sm) variables (sm.allId, conId, patId, med_ptId, unmed_ptId)
% are all INDICES w.r.t. 1:57 numbering)

%clear all
dataStruct = struct;
apriori_exclusions = [47 32];
dataStruct.sm.ex = apriori_exclusions; % excluded from all analyses, a priori
dataStruct.sm.patId = setdiff(1:28, []); % no exclusions indices w.r.t 57
dataStruct.sm.conId = setdiff(29:57, []);
dataStruct.sm.allId = [dataStruct.sm.patId dataStruct.sm.conId];


%% demographics
[NUM, TXT, ~] = xlsread('data_store_repo.xlsx', 'demog');
dataStruct.megID = NUM(:, 8);

dataStruct.sm.subject_list = TXT(2:58,1);

dataStruct.demog.age = NUM(:,2);
dataStruct.demog.male = NUM(:,3);
dataStruct.demog.rh = NUM(:,4);
dataStruct.demog.ethnicity = NUM(:,5); % (1=white, 2=black british, 3=indian, 4=asian, 5=mixed, 6=other)
dataStruct.demog.emp = NUM(:,6); % (1 = full time, 2 = part time, 3 = student, 4 = unemployed)
dataStruct.demog.education = NUM(:,7);

%% cognitive scores
[NUM, ~, ~] = xlsread('data_store_repo.xlsx', 'cognitive');
dataStruct.cog.vIQ = NUM(:,2);
dataStruct.cog.pIQ = NUM(:,3);
dataStruct.cog.fsIQ = NUM(:,4);
dataStruct.cog.fDS = NUM(:,5);
dataStruct.cog.bDS = NUM(:,6);


%% clinical scores
[NUM, ~, ~] = xlsread('data_store_repo.xlsx', 'clinical');
dataStruct.clin.sz = NUM(:,2);
dataStruct.clin.med = NUM(:,3);
dataStruct.clin.gaf = NUM(:,4);
dataStruct.clin.panssALL = NUM(:,9:38);
dataStruct.clin.madrsALL = NUM(:, 39:48);
dataStruct.clin.madrs = sum(dataStruct.clin.madrsALL,2);
dataStruct.clin.panssP = sum(dataStruct.clin.panssALL(:,[1:7]),2);
dataStruct.clin.panssN = sum(dataStruct.clin.panssALL(:,[8:14]),2);
dataStruct.clin.panssG = sum(dataStruct.clin.panssALL(:,[15:30]),2);

dataStruct.sm.med_ptId = intersect(dataStruct.sm.patId, find(dataStruct.clin.med)); % intersection of included patients and medicated patients
dataStruct.sm.unmed_ptId = setdiff(dataStruct.sm.patId, find(dataStruct.clin.med))'; % only included patients that are not also medicated


[NUM, ~, ~] = xlsread('data_store_repo.xlsx', 'more_clinical');
dataStruct.more_clin.med_naive = NUM(:,3);
dataStruct.more_clin.months_since_fep = NUM(:,4);
dataStruct.more_clin.months_recent_ep = NUM(:,5);
dataStruct.more_clin.admissions = NUM(:,6);
dataStruct.more_clin.episodes = NUM(:,7);
dataStruct.more_clin.smoke = NUM(:,8); % cigs/day
dataStruct.more_clin.etoh = NUM(:,9); % units/week
dataStruct.more_clin.thc = NUM(:,10); % current recreational thc;
dataStruct.more_clin.med_CPZ_MPG = NUM(:,11);  % MPG 14th Ed


%% meg - sequenceness
[NUM, ~, ~] = xlsread('data_store_repo.xlsx', 'sqn');

% fwd-bwd structural
dataStruct.rp.sqn4050 = NUM(:, [2 3 4 5]+8); % [r0 r1 r2 r12]
dataStruct.rp.d_sqn4050 = NUM(:, [6 7 8]+8); % [r0->1 r0->2 r0->12]


%% meg - tf on WHOLE REST SESSSION (not smoothing the TF matrices)
[NUM, ~, ~] = xlsread('data_store_repo.xlsx', 'TF');

% peak ripple change for epoch (-10:60), ripple = 120-150Hz
dataStruct.tf.peakEpoch = NUM(:, [7 8 9 10]); % r0, r1, r2, r12

clear NUM TXT apriori_exclusions orig_ex

end