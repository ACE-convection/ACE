function s=read_shared_input(file)
% Shared case schemas 1 (v0.18 annular) and 2 (S20 slab/three operators).
schema=ncreadatt(file,'/','ace_input_schema');
assert(ismember(schema,{'ACE-case-input-1','ACE-case-input-2'}), 'Unsupported ACE input schema');
info=ncinfo(file);
s=struct;
for i=1:numel(info.Variables)
    v=info.Variables(i);
    assert(strcmp(v.Datatype,'double'), 'Input must use double precision');
    value=ncread(file,v.Name);
    assert(all(isfinite(value(:))), 'Nonfinite shared input');
    s.(v.Name)=value;
end
s.schema=schema;
nz=dimension(info,'mf_level');
nc=dimension(info,'response_ace');
nb=dimension(info,'coarse_level');
assert(dimension(info,'zc_level')==nz && dimension(info,'forcing_ace')==nc, 'Case dimension mismatch');
assert(dimension(info,'basis_edge')==nb+1, 'Basis edge/layer mismatch');
if strcmp(schema,'ACE-case-input-1')
    expected={'mf_level',801;'zc_level',801;'basis_edge',201;'coarse_level',200;'forcing_ace',8;'response_ace',8;'radial_boundary',7;'pressure_level',181;'sounding_level',37};
    for i=1:size(expected,1)
        assert(dimension(info,expected{i,1})==expected{i,2}, 'Unexpected v0.18 dimension');
    end
    s.geometry='annular';
    operators={'PMB'};
else
    s.geometry=ncreadatt(file,'/','geometry');
    assert(strcmp(s.geometry,'slab'), 'Schema 2 currently requires slab geometry');
    assert(nz>=12 && nc>=2 && nb>=1 && mod(nz-1,nb)==0, 'Invalid fine/coarse/ACE dimensions');
    assert(dimension(info,'ace')==nc, 'ACE geometry dimension mismatch');
    operators={'PMB','PMDv','PMD'};
    for name={'ace_width','ace_perimeter'}
        validate_variable(file,name{1},{'ace'},'m');
        assert(numel(s.(name{1}))==nc && all(s.(name{1})>0), 'Invalid slab geometry');
    end
    validate_variable(file,'ace_area',{'ace'},'m2');
    assert(numel(s.ace_area)==nc && all(s.ace_area>0), 'Invalid ACE areas');
    assert(all(abs(s.ace_area./s.ace_perimeter-s.ace_width)<=64*eps*max(s.ace_width)), 'Slab geometry disagrees with width');
end
for i=1:numel(operators)
    name=operators{i}; unit='1';
    if ~strcmp(name,'PMB'), unit='native'; end
    validate_variable(file,name,{'basis_edge','coarse_level','forcing_ace','response_ace'},unit);
    assert(isequal(size(s.(name)),[nb+1,nb,nc,nc]), 'Basis shape mismatch');
    s.([name '_source_status'])='supplied';
    v=ncinfo(file,name);
    if any(strcmp({v.Attributes.Name},'source_status'))
        s.([name '_source_status'])=ncreadatt(file,name,'source_status');
    end
end
profiles={'theta_e_mf','qt_mf','Tv_mf','p_mf','rho_mf','zm','theta_e_zc','qt_zc','Tv_zc','p_zc','rho_zc','z'};
profile_units={'K','kg kg-1','K','Pa','kg m-3','m','K','kg kg-1','K','Pa','kg m-3','m'};
for i=1:12
    if i<=6, dim='mf_level'; else, dim='zc_level'; end
    validate_variable(file,profiles{i},{dim},profile_units{i});
    assert(numel(s.(profiles{i}))==nz, 'Profile length mismatch');
end
for name={'basis_z','coarse_ze'}
    validate_variable(file,name{1},{'basis_edge'},'m');
end
validate_variable(file,'coarse_z',{'coarse_level'},'m');
lengths={'dz'};
if strcmp(schema,'ACE-case-input-1'), lengths={'Lx','Ly','dz'}; end
for name=lengths
    validate_variable(file,name{1},{},'m');
    assert(isscalar(s.(name{1})) && s.(name{1})>0, 'Invalid length scale');
end
if strcmp(schema,'ACE-case-input-1')
    validate_variable(file,'diameter',{'radial_boundary'},'m');
else
    assert(isequal(s.basis_z,s.coarse_ze), 'Schema 2 requires unified basis edges');
    assert(all(diff(s.zm)>0) && all(diff(s.basis_z)>0), 'Nonmonotone grid');
    assert(all(abs(diff(s.zm)-s.dz)<=64*eps*max(abs(s.zm))), 'Grid spacing disagrees with dz');
    assert(all(abs(s.z-s.zm-s.dz/2)<=64*eps*max(abs(s.z))), 'Cell-center grid mismatch');
    ratio=(nz-1)/nb;
    assert(all(abs(s.coarse_ze-s.zm(1:ratio:end))<=64*eps*max(abs(s.coarse_ze))), 'Basis/coarse grid mismatch');
    assert(isequal(s.coarse_z,s.coarse_ze(1:end-1)), 'Coarse-layer grid mismatch');
end
assert(all(s.p_mf>0) && all(s.p_zc>0) && all(s.rho_mf>0) && all(s.rho_zc>0), 'Invalid reference pressure/density');
assert(all(s.qt_mf>=0) && all(s.qt_zc>=0), 'Negative reference total water');
for name={'p','plev'}
    assert(strcmp(ncreadatt(file,name{1},'units'),'Pa'), 'Expected pressure in Pa');
end
s.arm=double(ncreadatt(file,'/','arm'));
s.profile_index=double(ncreadatt(file,'/','profile_index'));
s.case_name=ncreadatt(file,'/','case_name');
assert(ismember(s.arm,1:3) && s.profile_index>=1 && s.profile_index==fix(s.profile_index), ...
    'Invalid sounding selection metadata');
end

function length=dimension(info,name)
idx=find(strcmp({info.Dimensions.Name},name));
assert(numel(idx)==1, 'Missing or ambiguous input dimension');
length=info.Dimensions(idx).Length;
end

function validate_variable(file,name,dims,unit)
v=ncinfo(file,name);
actual_dims={};
if ~isempty(v.Dimensions), actual_dims={v.Dimensions.Name}; end
assert(isequal(actual_dims,dims), 'Input variable dimension order mismatch: %s',name);
assert(strcmp(ncreadatt(file,name,'units'),unit), 'Input variable units mismatch: %s',name);
end
