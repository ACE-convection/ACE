function create_shared_input(binary_dir, basis_file, sounding_file, output_file, profile, arm, provenance)
% Convert a reviewed legacy case without changing its numerical values.
% provenance is a struct containing SHA-256 strings/source identifiers.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
required={'source_commit','initial_sha256','pmb_sha256','basis_sha256','sounding_sha256'};
assert(all(isfield(provenance,required)), 'Missing provenance attributes');
addpath(fullfile(root,'matlab/util_thermodynamics'));
driver=fullfile(root,'matlab/ace.m');
source=fileread(driver);
first=strfind(source,'function [T_env, q_env, Tv_env, theta_e_env');
last=strfind(source,'function [theta_e_plu, qt_plu, T_plu');
assert(numel(first)==1 && numel(last)==1, 'Cannot locate historical preprocessing functions');
temporary=tempname; mkdir(temporary);
cleanup=onCleanup(@() remove_helper(temporary));
helper=fullfile(temporary,'prepare_profile.m');
fid=fopen(helper,'w'); assert(fid>=0);
fprintf(fid,'%s\n%s',fileread(fullfile(root,'tools/input/prepare_profile.txt')),source(first:last-1)); fclose(fid);
addpath(temporary);
s=prepare_profile(driver,sounding_file,profile,arm);
basis=load(basis_file,'PMB','Z','DCASES','Lx','Ly');
names={'theta_e_mf','qt_mf','Tv_mf','p_mf','rho_mf','zm','theta_e_zc','qt_zc','Tv_zc','p_zc','rho_zc','z'};
reference=[s.theta_e_zm,s.q_zm,s.Tv_zm,s.p_zm,s.rho_zm,s.zm,s.theta_e_env,s.q_env,s.Tv_env,s.p_z,s.rho_env,s.z];
if arm==1, case_name='manus'; elseif arm==3, case_name='goamazon'; else, error('Only reviewed Manus/GOAmazon cases are supported'); end
initial_file=fullfile(binary_dir,sprintf('ini_%s_%d.dat',case_name,profile));
fid=fopen(initial_file,'r','ieee-le'); assert(fid>=0);
initial=fread(fid,[801,12],'double=>double'); extra=fread(fid,1,'uint8'); fclose(fid);
assert(isempty(extra) && isequal(initial,reference), 'Initialization differs from MATLAB; conversion stopped');
fid=fopen(fullfile(binary_dir,'PMB.dat'),'r','ieee-le'); assert(fid>=0);
pmb=fread(fid,inf,'double=>double'); fclose(fid);
assert(numel(pmb)==numel(basis.PMB) && isequal(reshape(pmb,size(basis.PMB)),basis.PMB), 'PMB differs from MATLAB');
assert(~isfile(output_file), 'Output already exists; use a fresh path');
for i=1:12
    if i<=6, dim='mf_level'; else, dim='zc_level'; end
    write_variable(output_file,names{i},initial(:,i),{dim,801},units(names{i}));
end
write_variable(output_file,'PMB',basis.PMB,{'basis_edge',201,'coarse_level',200,'forcing_ace',8,'response_ace',8},'1');
write_variable(output_file,'basis_z',basis.Z(:),{'basis_edge',201},'m');
write_variable(output_file,'coarse_z',(0:200:39800)',{'coarse_level',200},'m');
write_variable(output_file,'coarse_ze',(0:200:40000)',{'basis_edge',201},'m');
write_variable(output_file,'diameter',basis.DCASES(:)*1000,{'radial_boundary',7},'m');
write_variable(output_file,'Lx',basis.Lx*1000,{},'m');
write_variable(output_file,'Ly',basis.Ly*1000,{},'m');
write_variable(output_file,'dz',50,{},'m');
ancillary={'p','plev','ta','hus','pr','prw','date','hh','T_p','q_p','rho_p','z_p','T_env','T_zm','theta_zm','theta_es_zm','rh_zm'};
for i=1:numel(ancillary)
    name=ancillary{i}; value=s.(name);
    if isscalar(value), dims={};
    elseif numel(value)==181, dims={'pressure_level',181};
    elseif numel(value)==37, dims={'sounding_level',37};
    elseif strcmp(name,'T_env'), dims={'zc_level',801};
    else, dims={'mf_level',801}; end
    write_variable(output_file,name,value,dims,units(name));
end
ncwriteatt(output_file,'/','ace_input_schema','ACE-case-input-1');
ncwriteatt(output_file,'/','case_name',case_name);
ncwriteatt(output_file,'/','profile_index',int32(profile));
ncwriteatt(output_file,'/','arm',int32(arm));
ncwriteatt(output_file,'/','matlab_version',version);
ncwriteatt(output_file,'/','PMB_order_on_disk','response_ace,forcing_ace,coarse_level,basis_edge');
ncwriteatt(output_file,'/','coordinate_policy','basis_z preserves MATLAB; coarse_z/coarse_ze preserve legacy Fortran');
fields=fieldnames(provenance);
for i=1:numel(fields), ncwriteatt(output_file,'/',fields{i},provenance.(fields{i})); end
% Verify every stored variable immediately, including the full PMB.
info=ncinfo(output_file);
for i=1:numel(info.Variables)
    name=info.Variables(i).Name;
    assert(strcmp(info.Variables(i).Datatype,'double'), 'Precision changed');
end
assert(isequal(ncread(output_file,'PMB'),basis.PMB), 'PMB round trip failed');
for i=1:12, assert(isequal(ncread(output_file,names{i}),initial(:,i)), 'Profile round trip failed'); end
fprintf('Created and verified %s\n',output_file);
end

function write_variable(file,name,value,dims,unit)
assert(all(isfinite(value(:))), 'Nonfinite input');
if isempty(dims)
    nccreate(file,name,'Datatype','double','Format','netcdf4');
else
    nccreate(file,name,'Dimensions',dims,'Datatype','double','Format','netcdf4','DeflateLevel',1);
end
ncwrite(file,name,value);
ncwriteatt(file,name,'units',unit);
assert(isequal(ncread(file,name),value), 'Variable round trip failed: %s',name);
end

function unit=units(name)
if startsWith(name,'theta') || startsWith(name,'Tv') || startsWith(name,'T_') || strcmp(name,'ta'), unit='K';
elseif startsWith(name,'rho'), unit='kg m-3';
elseif startsWith(name,'qt') || startsWith(name,'q_') || strcmp(name,'hus'), unit='kg kg-1';
elseif startsWith(name,'p_') || ismember(name,{'p','plev'}), unit='Pa';
elseif ismember(name,{'z','zm','z_p'}), unit='m';
elseif strcmp(name,'pr'), unit='mm h-1';
elseif strcmp(name,'prw'), unit='mm';
elseif strcmp(name,'date'), unit='MATLAB datenum days';
elseif strcmp(name,'hh'), unit='hour';
else, unit='1'; end
end

function remove_helper(directory)
rmpath(directory);
clear prepare_profile;
delete(fullfile(directory,'prepare_profile.m'));
rmdir(directory);
end
