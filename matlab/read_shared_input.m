function s=read_shared_input(file)
% Read the reviewed single-case schema. MATLAB sees PMB(edge,coarse,forcing,response).
assert(strcmp(ncreadatt(file,'/','ace_input_schema'),'ACE-case-input-1'), 'Unsupported ACE input schema');
info=ncinfo(file);
expected={'mf_level',801;'zc_level',801;'basis_edge',201;'coarse_level',200;'forcing_ace',8;'response_ace',8;'radial_boundary',7;'pressure_level',181;'sounding_level',37};
for i=1:size(expected,1)
    idx=find(strcmp({info.Dimensions.Name},expected{i,1}));
    assert(numel(idx)==1 && info.Dimensions(idx).Length==expected{i,2}, 'Unexpected input dimension');
end
s=struct;
for i=1:numel(info.Variables)
    v=info.Variables(i);
    assert(strcmp(v.Datatype,'double'), 'Input must use double precision');
    value=ncread(file,v.Name);
    assert(all(isfinite(value(:))), 'Nonfinite shared input');
    s.(v.Name)=value;
end
assert(isequal(size(s.PMB),[201,200,8,8]), 'PMB shape mismatch');
pmbinfo=ncinfo(file,'PMB');
assert(isequal({pmbinfo.Dimensions.Name},{'basis_edge','coarse_level','forcing_ace','response_ace'}), 'PMB order mismatch');
profiles={'theta_e_mf','qt_mf','Tv_mf','p_mf','rho_mf','zm','theta_e_zc','qt_zc','Tv_zc','p_zc','rho_zc','z'};
profile_units={'K','kg kg-1','K','Pa','kg m-3','m','K','kg kg-1','K','Pa','kg m-3','m'};
for i=1:12
    v=ncinfo(file,profiles{i});
    if i<=6, dimension='mf_level'; else, dimension='zc_level'; end
    assert(isequal({v.Dimensions.Name},{dimension}), 'Profile dimension mismatch');
    assert(strcmp(ncreadatt(file,profiles{i},'units'),profile_units{i}), 'Profile units mismatch');
end
for name={'basis_z','coarse_z','coarse_ze','diameter','Lx','Ly','dz'}
    assert(strcmp(ncreadatt(file,name{1},'units'),'m'), 'Expected metre units');
end
assert(strcmp(ncreadatt(file,'PMB','units'),'1'), 'PMB units mismatch');
for name={'p','plev'}
    assert(strcmp(ncreadatt(file,name{1},'units'),'Pa'), 'Expected pressure in Pa');
end
s.arm=double(ncreadatt(file,'/','arm'));
s.profile_index=double(ncreadatt(file,'/','profile_index'));
s.case_name=ncreadatt(file,'/','case_name');
end
