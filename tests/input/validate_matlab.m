function validate_matlab(legacy_data, reports)
% Compare the actual driver before/after the shared-input change.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
settings.legacy_data=legacy_data; % ace is a script and assigns legacy_data.
previous=pwd;
variables={'ACE_INPUT_MODE','ACE_INPUT_FILE','ACE_LEGACY_DATA','ACE_VALIDATE_INPUT'};
values=cellfun(@getenv,variables,'UniformOutput',false);
cleanup=onCleanup(@() restore(previous,variables,values));
cd(fullfile(root,'matlab/active'));
setenv('ACE_INPUT_FILE',fullfile(root,'data/input/manus208.nc'));
setenv('ACE_INPUT_MODE','shared');
setenv('ACE_VALIDATE_INPUT',fullfile(reports,'matlab_shared_init.mat'));
ace;
setenv('ACE_INPUT_MODE','legacy');
setenv('ACE_LEGACY_DATA',settings.legacy_data);
setenv('ACE_VALIDATE_INPUT',fullfile(reports,'matlab_legacy_init.mat'));
ace;
a=load(fullfile(reports,'matlab_shared_init.mat'));
b=load(fullfile(reports,'matlab_legacy_init.mat'));
names=fieldnames(a);
for i=1:numel(names)
    assert(isequal(a.(names{i}),b.(names{i})), 'Initialization differs: %s',names{i});
end
% Reader rejects a swapped forcing/response dimension even though both have length 8.
bad=[tempname(reports) '.nc'];
original=fullfile(root,'data/input/manus208.nc');
info=ncinfo(original);
for i=1:numel(info.Variables)
    v=info.Variables(i); dims={};
    for j=1:numel(v.Dimensions)
        name=v.Dimensions(j).Name;
        if strcmp(v.Name,'PMB')
            if strcmp(name,'forcing_ace'), name='response_ace';
            elseif strcmp(name,'response_ace'), name='forcing_ace'; end
        end
        dims=[dims,{name,v.Dimensions(j).Length}];
    end
    if isempty(dims), nccreate(bad,v.Name,'Datatype','double','Format','netcdf4');
    else, nccreate(bad,v.Name,'Dimensions',dims,'Datatype','double','Format','netcdf4'); end
    ncwrite(bad,v.Name,ncread(original,v.Name));
    ncwriteatt(bad,v.Name,'units',ncreadatt(original,v.Name,'units'));
end
ncwriteatt(bad,'/','ace_input_schema','ACE-case-input-1');
rejected=false;
try
    read_shared_input(bad);
catch error
    rejected=contains(error.message,'PMB order mismatch');
end
assert(rejected, 'Reader accepted a malformed PMB order');
report=struct('initialization_fields',numel(names),'all_exact_equal',true,'wrong_PMB_order_rejected',true,'matlab_version',version);
fid=fopen(fullfile(reports,'shared_input_matlab_validation.json'),'w');
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true)); fclose(fid);
disp(report);
end

function restore(directory,names,values)
cd(directory);
for i=1:numel(names), setenv(names{i},values{i}); end
end
