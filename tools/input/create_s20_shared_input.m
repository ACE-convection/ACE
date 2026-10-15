function create_s20_shared_input(basis_file,sounding_file,output_file,profile,arm,provenance,dz)
% Convert the selected S20 reference inputs to schema 2 without resampling operators.
% This tool is prepared for use after the developer supplies the final basis.
if nargin<7, dz=100; end
assert(isfinite(dz) && dz>0 && mod(40000,dz)==0, 'dz must divide the 40 km model depth');
assert(ismember(arm,1:3) && profile>=1 && profile==fix(profile), 'Invalid sounding selection');
required={'source_commit','basis_sha256','sounding_sha256'};
assert(all(isfield(provenance,required)), 'Missing source provenance');
fields=fieldnames(provenance);
assert(~any(ismember(fields,{'ace_input_schema','geometry','arm','profile_index','case_name', ...
    'basis_order_on_disk','PMB_order_on_disk','coordinate_policy','momentum_basis_units_policy','matlab_version'})), ...
    'Provenance must not override schema attributes');
assert(~isfile(output_file), 'Output already exists; use a fresh path');
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab/util_thermodynamics'));
basis=load(basis_file,'D','Z','PMB','PMDv','PMD');
assert(all(isfield(basis,{'D','Z','PMB','PMDv','PMD'})), 'Final S20 basis lacks required variables');
widths=double(basis.D(:))*1000; % S20 D is in km.
nc=numel(widths); nb=size(basis.PMB,2); nz=40000/dz+1;
assert(nc>=2 && all(isfinite(widths)) && all(widths>0), 'Invalid S20 widths');
assert(nb>=1 && mod(nz-1,nb)==0, 'Basis/fine-grid partition mismatch');
for name={'PMB','PMDv','PMD'}
    value=basis.(name{1});
    assert(isa(value,'double') && isequal(size(value),[nb+1,nb,nc,nc]), 'Operator shape/type mismatch');
    assert(all(isfinite(value(:))), 'Nonfinite basis');
end
basis_z=double(basis.Z(:));
zm=(0:dz:40000)'; z=zm+dz/2; ratio=(nz-1)/nb;
assert(numel(basis_z)==nb+1 && all(isfinite(basis_z)) && all(diff(basis_z)>0), 'Invalid basis coordinates');
assert(all(abs(basis_z-zm(1:ratio:end))<=64*eps*max(abs(basis_z))), 'Basis grid differs from fine-grid partition');
% Preserve the supplied basis edge values for both implementations.
coarse_ze=basis_z; coarse_z=basis_z(1:end-1);
source=fileread(fullfile(root,'matlab/ace.m'));
first=strfind(source,'function [T_env, q_env, Tv_env, theta_e_env');
assert(numel(first)==1, 'Cannot locate S20 preprocessing functions');
temporary=tempname; mkdir(temporary);
helper_cleanup=onCleanup(@() remove_helper(temporary));
fid=fopen(fullfile(temporary,'prepare_s20_profile.m'),'w'); assert(fid>=0);
header=[ ...
    'function s=prepare_s20_profile(sounding,profile,arm,dz)' newline ...
    'zm=(0:dz:40000)''; z=zm+dz/2; p=(1000:-5:100)''*100;' newline ...
    '[plev,pr,ta,hus,prw,date,hh]=LOAD_SOUNDINGS(sounding,arm);' newline ...
    'assert(profile<=size(ta,2), "Profile outside filtered collection");' newline ...
    'date=date(profile); hh=hh(profile); pr=pr(profile); prw=prw(profile);' newline ...
    'ta=ta(:,profile); hus=hus(:,profile);' newline ...
    '[T_p,q_p,rho_p,z_p]=INTERP_P_GRID(plev,ta,hus,p);' newline ...
    'q_p=TWEAK_THETA_E(T_p,q_p,p);' newline ...
    '[T_env,q_env,Tv_env,theta_e_env,rho_env,p_z,T_zm,q_zm,Tv_zm,theta_e_zm,rho_zm,p_zm,theta_zm,theta_es_zm,rh_zm]=INTERP_Z_GRID(T_p,q_p,z_p,p,zm,z,dz);' newline ...
    'names={"p","z","zm","plev","pr","prw","date","hh","ta","hus","T_p","q_p","rho_p","z_p","T_env","q_env","Tv_env","theta_e_env","rho_env","p_z","T_zm","q_zm","Tv_zm","theta_e_zm","rho_zm","p_zm","theta_zm","theta_es_zm","rh_zm"};' newline ...
    's=struct; for i=1:numel(names), s.(names{i})=eval(names{i}); end' newline ...
    'end' newline];
fprintf(fid,'%s%s',header,source(first:end)); fclose(fid);
addpath(temporary);
s=prepare_s20_profile(sounding_file,profile,arm,dz);
names={'theta_e_mf','qt_mf','Tv_mf','p_mf','rho_mf','zm','theta_e_zc','qt_zc','Tv_zc','p_zc','rho_zc','z'};
values={s.theta_e_zm,s.q_zm,s.Tv_zm,s.p_zm,s.rho_zm,s.zm,s.theta_e_env,s.q_env,s.Tv_env,s.p_z,s.rho_env,s.z};
profile_units={'K','kg kg-1','K','Pa','kg m-3','m','K','kg kg-1','K','Pa','kg m-3','m'};
for i=1:12
    dim='mf_level'; if i>6, dim='zc_level'; end
    write_variable(output_file,names{i},values{i},{dim,nz},profile_units{i});
end
for name={'PMB','PMDv','PMD'}
    unit='1'; if ~strcmp(name{1},'PMB'), unit='native'; end
    write_variable(output_file,name{1},basis.(name{1}), ...
        {'basis_edge',nb+1,'coarse_level',nb,'forcing_ace',nc,'response_ace',nc},unit);
    ncwriteatt(output_file,name{1},'source_status','supplied');
end
write_variable(output_file,'basis_z',basis_z,{'basis_edge',nb+1},'m');
write_variable(output_file,'coarse_ze',coarse_ze,{'basis_edge',nb+1},'m');
write_variable(output_file,'coarse_z',coarse_z,{'coarse_level',nb},'m');
write_variable(output_file,'ace_width',widths,{'ace',nc},'m');
% The historical S20 convention Ai=D km^2, Bi=1 km corresponds to a 1 km span.
write_variable(output_file,'ace_area',widths*1000,{'ace',nc},'m2');
write_variable(output_file,'ace_perimeter',ones(nc,1)*1000,{'ace',nc},'m');
write_variable(output_file,'dz',double(dz),{},'m');
ancillary={'p','plev','ta','hus','pr','prw','date','hh','T_p','q_p','rho_p','z_p','T_env','T_zm','theta_zm','theta_es_zm','rh_zm'};
for i=1:numel(ancillary)
    name=ancillary{i}; value=s.(name);
    if isscalar(value), dims={};
    elseif ismember(name,{'p','T_p','q_p','rho_p','z_p'}), dims={'pressure_level',numel(s.p)};
    elseif ismember(name,{'plev','ta','hus'}), dims={'sounding_level',numel(s.plev)};
    elseif strcmp(name,'T_env'), dims={'zc_level',nz};
    else, dims={'mf_level',nz}; end
    write_variable(output_file,name,value,dims,units(name));
end
cases={'manus','nauru','goamazon'};
ncwriteatt(output_file,'/','ace_input_schema','ACE-case-input-2');
ncwriteatt(output_file,'/','geometry','slab');
ncwriteatt(output_file,'/','case_name',cases{arm});
ncwriteatt(output_file,'/','arm',int32(arm));
ncwriteatt(output_file,'/','profile_index',int32(profile));
ncwriteatt(output_file,'/','PMB_order_on_disk','response_ace,forcing_ace,coarse_level,basis_edge');
ncwriteatt(output_file,'/','basis_order_on_disk','response_ace,forcing_ace,coarse_level,basis_edge');
ncwriteatt(output_file,'/','coordinate_policy','basis_z and coarse_ze preserve supplied S20 basis coordinates');
ncwriteatt(output_file,'/','momentum_basis_units_policy','Native source values retained; physical units require review before enabling momentum terms');
ncwriteatt(output_file,'/','matlab_version',version);
for i=1:numel(fields), ncwriteatt(output_file,'/',fields{i},provenance.(fields{i})); end
fprintf('Created S20 shared input %s; runtime validation remains a separate step.\n',output_file);
end

function write_variable(file,name,value,dims,unit)
% Single-precision ancillary sounding values embed exactly in binary64.
value=double(value);
assert(all(isfinite(value(:))), 'Expected finite binary64 input');
if isempty(dims)
    nccreate(file,name,'Datatype','double','Format','netcdf4');
else
    options={};
    if ismember(name,{'PMB','PMDv','PMD'})
        % Both readers consume complete vertical blocks for one ACE pair.
        options={'ChunkSize',[dims{2},dims{4},1,1]};
    end
    nccreate(file,name,'Dimensions',dims,'Datatype','double','Format','netcdf4','DeflateLevel',1,options{:});
end
ncwrite(file,name,value);
ncwriteatt(file,name,'units',unit);
end

function unit=units(name)
if startsWith(name,'theta') || startsWith(name,'T_') || strcmp(name,'ta'), unit='K';
elseif startsWith(name,'rho'), unit='kg m-3';
elseif strcmp(name,'q_p') || strcmp(name,'hus'), unit='kg kg-1';
elseif ismember(name,{'p','plev'}), unit='Pa';
elseif strcmp(name,'z_p'), unit='m';
elseif strcmp(name,'pr'), unit='mm h-1';
elseif strcmp(name,'prw'), unit='mm';
elseif strcmp(name,'date'), unit='MATLAB datenum days';
elseif strcmp(name,'hh'), unit='hour';
else, unit='1'; end
end

function remove_helper(directory)
rmpath(directory);
clear prepare_s20_profile;
delete(fullfile(directory,'prepare_s20_profile.m'));
rmdir(directory);
end
