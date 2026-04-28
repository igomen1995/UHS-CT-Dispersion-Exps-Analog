function data_out = import_inputCTExp(input_name_xlsx)

%IMPORT_INPUTCAL Summary of this function goes here
% import fields for importing data of experiments

% Do not change unless input excel format changed

opts = spreadsheetImportOptions("NumVariables", 38);
% Specify sheet and range
opts.Sheet = "Sheet1";
opts.DataRange = [3,Inf];
% Specify column names and types
opts.VariableNames = ["Key", "Date", "Type","Fluid1", "Fluid2", ...
    "T", "P", "Q", "C1init", "C1j", "Run", "D", "L", "phi", "K", "Vcore", ...
    "setupVersion", "IDlines_cm", "Vlinesbefore", "Vlinesafter", "Vtotal", "Comments", "workingPump", "cushionPump", "confiningPump", "st", "et", "dt", ...
    "path", "pumps_data_name", "trans_data_name", "MFM_data_name", "PGD1_data_name", "PGD2_data_name","GMT_PGD",...
    "CT_data_exp","CT_data_ref_init","CT_data_ref_final"];
opts.VariableTypes = ["string", "string","string", "string", "string", ...
    "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", ...
    "string", "double","double", "double", "double","string", "string","string","string","datetime", "datetime", "double", ...
    "string", "string", "string", "string", "string", "string", "string",...
    "string", "string", "string"];
data_out = readtable(input_name_xlsx,opts);

data_out.st = datetime(data_out.st,'Format','MM/dd/uuuu HH:mm:ss');
data_out.et = datetime(data_out.et,'Format','MM/dd/uuuu HH:mm:ss');

end

