% Get clinical data (MEG ordering, dataStruct)

if ~exist('dataStruct')
    dataStruct = createDataStructure_repo;
end

% clincial (PANSS subscores - add in sub123 [unmedicated])
s123PANSS = [2,2,3,1,1,3,1,2,3,1,3,2,1,1,1,4,5,4,1,6,2,1,2,1,3,1,1,1,1,4];
s123MADRS = [5,4,4,6,3,3,3,4,4,2];
allPANSS = [dataStruct.clin.panssALL; s123PANSS];
allMed = [dataStruct.clin.med; 0];

% clinical (can add s58, no MEG)
clin = nan(58, 4); clinName = {};
clin (1:57,1) = dataStruct.clin.panssP;            clin(58,1) = sum(s123PANSS(1:7));        clinName{1} = 'Positive symptoms';% slot meg data into array
clin (1:57,2) = dataStruct.clin.panssN;            clin(58,2) = sum(s123PANSS(8:14));       clinName{2} = 'Negative symptoms';% slot meg data into array
clin (1:57,3) = dataStruct.clin.panssG;            clin(58,3) = sum(s123PANSS(15:end));     clinName{3} = 'General symptoms';% slot meg data into array
clin (1:57,4) = dataStruct.clin.madrs;             clin(58, 4) = sum(s123MADRS);            clinName{4} = 'Depressive symptoms';% slot meg data into array
new_clin = map_MEG_to_lexical(clin, dataStruct.sm.subject_list, iSja);
all_clin = map_MEG_to_lexical(allPANSS, dataStruct.sm.subject_list, iSja);
new_med = map_MEG_to_lexical(allMed, dataStruct.sm.subject_list, iSja);

% lines to compare medicated and unmedicated
% clin_p = new_clin(patId, :); med_p = new_med(patId, :);
% for ii = 1:4; disp(clinName{ii}), mmn_group_compar(clin_p(med_p == 0, ii), clin_p(med_p == 1, ii)), end

% cognitive
cog = nan(58, 3); cogName = {};
cog (1:57,1) = dataStruct.cog.fDS;            cog(58,1) = 7;        cogName{1} = 'forward DS';% slot meg data into array
cog (1:57,2) = dataStruct.cog.bDS;            cog(58,2) = 3.5;      cogName{2} = 'backward DS';% slot meg data into array
cog(:,3) = mean(cog(:, [1, 2]),2);                                  cogName{2} = 'mean DS';
cog (1:57,4) = dataStruct.cog.fsIQ;            cog(58,4) = 108;     cogName{4} = 'fsIQ';% slot meg data into array
new_cog = map_MEG_to_lexical(cog, dataStruct.sm.subject_list, iSja);

% meg
meg_name = {'change replay4050', 'post replay4050', 'post peakRipple'};
in = [dataStruct.rp.d_sqn4050(:,1) dataStruct.rp.sqn4050(:,2)  dataStruct.tf.peakEpoch(:,2)];
new_meg = map_MEG_to_lexical(in, dataStruct.sm.subject_list, iSja);


% cell tf exclusions [22 32 47 16]
cell_tf_ex = [22 32 47 16];
in_tf_ex = in;
in_tf_ex(cell_tf_ex, :) = NaN;
new_meg_tf_ex = map_MEG_to_lexical(in_tf_ex, dataStruct.sm.subject_list, iSja);


%---------------------------------
% demog
s123Med = [0 1]; % [current, naive]
s123Age = 30;
s123Female = 0;
demogName = {'female', 'age', 'medicated', 'naive'};
demog = [ [~dataStruct.demog.male; s123Female] [dataStruct.demog.age; s123Age] [ [dataStruct.clin.med dataStruct.more_clin.med_naive]; s123Med]];
new_demog =  map_MEG_to_lexical(demog, dataStruct.sm.subject_list, iSja);

clear demog clin in



