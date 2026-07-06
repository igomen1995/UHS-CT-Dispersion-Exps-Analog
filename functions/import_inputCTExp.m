function data_out = import_inputCTExp(input_name_xlsx)

%IMPORT_INPUTCTEXP Import CT experiment metadata from a standardized Excel file.
%
%   data_out = import_inputCTExp(input_name_xlsx) reads experiment
%   information from an Excel workbook and returns the contents as a MATLAB
%   table. The function is designed for the standardized CT experiment
%   input template and automatically assigns variable names, data types,
%   and datetime formats.
%
%   Inputs:
%       input_name_xlsx - String or character vector containing the path
%                         to the Excel input file.
%
%   Output:
%       data_out - Table containing experiment metadata, operating
%                  conditions, file locations, and CT scan references.
%
%   Imported Fields Include:
%       - Experiment identifiers and dates
%       - Fluid information
%       - Temperature, pressure, and flow rate
%       - Core properties (diameter, length, porosity, permeability)
%       - Experimental setup configuration
%       - Pump assignments
%       - Start and end timestamps
%       - Raw data file names and paths
%       - CT scan references
%
%   Notes:
%       - This function assumes the Excel workbook follows the standard
%         CT experiment template.
%       - The worksheet name and column structure must remain unchanged.
%       - Update the import options only if the template format changes.
%
%   Example:
%       expData = import_inputCTExp('inputs_CTExperiments.xlsx');
%
%   See also:
%       readtable, spreadsheetImportOptions, datetime

% Do not modify unless the input Excel format changes


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

