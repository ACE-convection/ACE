module ace_input
use netcdf
use iso_fortran_env, only: real64
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
implicit none
private
public :: read_case_profile, read_case_pmb, read_case_basis, read_case_metadata, read_case_geometry, basis_available
contains

subroutine check(status)
integer, intent(in) :: status
if (status /= nf90_noerr) then
  write(*,*) 'ACE input: ',trim(nf90_strerror(status))
  error stop 1
endif
end subroutine

integer function dim_length(ncid,name) result(length)
integer, intent(in) :: ncid
character(*), intent(in) :: name
integer :: id
call check(nf90_inq_dimid(ncid,name,id))
call check(nf90_inquire_dimension(ncid,id,len=length))
end function

subroutine dimension(ncid,name,expected)
integer, intent(in) :: ncid, expected
character(*), intent(in) :: name
if (dim_length(ncid,name)/=expected) error stop 'Unexpected ACE input dimension'
end subroutine

subroutine open_case(file,ncid,schema)
character(*), intent(in) :: file
integer, intent(out) :: ncid
character(*), intent(out) :: schema
integer :: nz,nc,nb
character(64) :: geometry
call check(nf90_open(file,nf90_nowrite,ncid))
call check(nf90_get_att(ncid,nf90_global,'ace_input_schema',schema))
select case(trim(schema))
case('ACE-case-input-1')
  call dimension(ncid,'mf_level',801)
  call dimension(ncid,'zc_level',801)
  call dimension(ncid,'basis_edge',201)
  call dimension(ncid,'coarse_level',200)
  call dimension(ncid,'forcing_ace',8)
  call dimension(ncid,'response_ace',8)
  call dimension(ncid,'radial_boundary',7)
  call dimension(ncid,'pressure_level',181)
  call dimension(ncid,'sounding_level',37)
case('ACE-case-input-2')
  nz=dim_length(ncid,'mf_level')
  nc=dim_length(ncid,'forcing_ace')
  nb=dim_length(ncid,'coarse_level')
  if (nz<12 .or. nc<2 .or. nb<1) error stop 'Invalid shared case dimensions'
  call dimension(ncid,'zc_level',nz)
  call dimension(ncid,'response_ace',nc)
  call dimension(ncid,'ace',nc)
  call dimension(ncid,'basis_edge',nb+1)
  if (mod(nz-1,nb)/=0) error stop 'Fine grid must partition into coarse layers'
  call check(nf90_get_att(ncid,nf90_global,'geometry',geometry))
  if (trim(geometry)/='slab') error stop 'Schema 2 currently requires slab geometry'
case default
  error stop 'Unsupported ACE input schema'
end select
end subroutine

subroutine read_case_metadata(file,nz,ncols,ncoarse,geometry)
character(*), intent(in) :: file
integer, intent(out) :: nz,ncols,ncoarse
character(*), intent(out) :: geometry
integer :: ncid
character(64) :: schema
call open_case(file,ncid,schema)
nz=dim_length(ncid,'mf_level')
ncols=dim_length(ncid,'response_ace')
ncoarse=dim_length(ncid,'coarse_level')
geometry='annular'
if (trim(schema)=='ACE-case-input-2') &
  call check(nf90_get_att(ncid,nf90_global,'geometry',geometry))
call check(nf90_close(ncid))
end subroutine

subroutine variable(ncid,name,unit,id)
integer, intent(in) :: ncid
character(*), intent(in) :: name, unit
integer, intent(out) :: id
integer :: xtype
character(64) :: actual
call check(nf90_inq_varid(ncid,name,id))
call check(nf90_inquire_variable(ncid,id,xtype=xtype))
if (xtype/=nf90_double) error stop 'ACE input must use double precision'
call check(nf90_get_att(ncid,id,'units',actual))
if (trim(actual)/=unit) error stop 'Unexpected ACE input units'
end subroutine

subroutine vector(ncid,name,unit,values)
integer, intent(in) :: ncid
character(*), intent(in) :: name,unit
real(real64), intent(out) :: values(:)
integer :: id, rank, dims(nf90_max_var_dims), length
character(64) :: dimname, expected
call variable(ncid,name,unit,id)
call check(nf90_inquire_variable(ncid,id,ndims=rank,dimids=dims))
if (rank/=1) error stop 'Expected a vector in ACE input'
call check(nf90_inquire_dimension(ncid,dims(1),len=length,name=dimname))
if (length/=size(values)) error stop 'Unexpected ACE vector length'
select case(name)
case('theta_e_mf','qt_mf','Tv_mf','p_mf','rho_mf','zm')
  expected='mf_level'
case('theta_e_zc','qt_zc','Tv_zc','p_zc','rho_zc','z')
  expected='zc_level'
case('diameter')
  expected='radial_boundary'
case('ace_width','ace_area','ace_perimeter')
  expected='ace'
case('coarse_z')
  expected='coarse_level'
case('basis_z','coarse_ze')
  expected='basis_edge'
case default
  error stop 'Unknown ACE input vector'
end select
if (trim(dimname)/=trim(expected)) error stop 'ACE vector dimension mismatch'
call check(nf90_get_var(ncid,id,values))
if (.not.all(ieee_is_finite(values))) error stop 'Nonfinite ACE input'
end subroutine

subroutine scalar(ncid,name,unit,value)
integer, intent(in) :: ncid
character(*), intent(in) :: name,unit
real(real64), intent(out) :: value
integer :: id,rank
call variable(ncid,name,unit,id)
call check(nf90_inquire_variable(ncid,id,ndims=rank))
if (rank/=0) error stop 'Expected a scalar in ACE input'
call check(nf90_get_var(ncid,id,value))
if (.not.ieee_is_finite(value)) error stop 'Nonfinite ACE input'
end subroutine

subroutine read_case_profile(file,profile,diameters,lx,ly,dz,coarse_z,coarse_ze)
character(*), intent(in) :: file
real(real64), intent(out) :: profile(:,:), diameters(:), lx, ly, dz
real(real64), intent(out) :: coarse_z(:),coarse_ze(:)
integer :: ncid,nz,nb
character(64) :: schema
real(real64), allocatable :: basis_z(:)
call open_case(file,ncid,schema)
nz=dim_length(ncid,'mf_level'); nb=dim_length(ncid,'coarse_level')
if (any(shape(profile)/=[nz,12]) .or. size(coarse_z)/=nb .or. size(coarse_ze)/=nb+1) &
  error stop 'Unexpected case profile allocation'
call vector(ncid,'theta_e_mf','K',profile(:,1))
call vector(ncid,'qt_mf','kg kg-1',profile(:,2))
call vector(ncid,'Tv_mf','K',profile(:,3))
call vector(ncid,'p_mf','Pa',profile(:,4))
call vector(ncid,'rho_mf','kg m-3',profile(:,5))
call vector(ncid,'zm','m',profile(:,6))
call vector(ncid,'theta_e_zc','K',profile(:,7))
call vector(ncid,'qt_zc','kg kg-1',profile(:,8))
call vector(ncid,'Tv_zc','K',profile(:,9))
call vector(ncid,'p_zc','Pa',profile(:,10))
call vector(ncid,'rho_zc','kg m-3',profile(:,11))
call vector(ncid,'z','m',profile(:,12))
diameters=0.
if (trim(schema)=='ACE-case-input-1') call vector(ncid,'diameter','m',diameters)
lx=0.; ly=0.
if (trim(schema)=='ACE-case-input-1') then
  call scalar(ncid,'Lx','m',lx)
  call scalar(ncid,'Ly','m',ly)
  if (lx<=0 .or. ly<=0) error stop 'Invalid annular domain dimensions'
endif
call scalar(ncid,'dz','m',dz)
call vector(ncid,'coarse_z','m',coarse_z)
call vector(ncid,'coarse_ze','m',coarse_ze)
if (dz<=0) error stop 'Invalid grid spacing'
if (any(profile(:,4)<=0) .or. any(profile(:,10)<=0) .or. &
    any(profile(:,5)<=0) .or. any(profile(:,11)<=0)) error stop 'Invalid reference pressure/density'
if (any(profile(:,2)<0) .or. any(profile(:,8)<0)) error stop 'Negative reference total water'
if (trim(schema)=='ACE-case-input-2') then
  allocate(basis_z(nb+1))
  call vector(ncid,'basis_z','m',basis_z)
  if (any(basis_z/=coarse_ze)) error stop 'Schema 2 requires unified basis edge coordinates'
  if (any(profile(2:,6)<=profile(:nz-1,6))) error stop 'Nonmonotone MF grid'
  if (any(coarse_ze(2:)<=coarse_ze(:nb))) error stop 'Nonmonotone basis grid'
  if (any(abs(profile(2:,6)-profile(:nz-1,6)-dz)>64*epsilon(dz)*maxval(abs(profile(:,6))))) &
    error stop 'Grid spacing disagrees with dz'
  if (any(abs(profile(:,12)-profile(:,6)-dz/2)>64*epsilon(dz)*maxval(abs(profile(:,12))))) &
    error stop 'Cell centers disagree with staggered grid'
  if (any(abs(coarse_ze-profile(1:nz:(nz-1)/nb,6))>64*epsilon(dz)*maxval(abs(coarse_ze)))) &
    error stop 'Basis coordinates disagree with coarse grid'
  if (any(coarse_z/=coarse_ze(:nb))) error stop 'Unexpected coarse-layer coordinates'
endif
call check(nf90_close(ncid))
end subroutine

subroutine read_case_geometry(file,area,perimeter)
character(*), intent(in) :: file
real(real64), intent(out) :: area(:),perimeter(:)
integer :: ncid,nc,i
character(64) :: schema
real(real64) :: lx,ly
real(real64), allocatable :: widths(:),diameters(:)
call open_case(file,ncid,schema)
nc=dim_length(ncid,'response_ace')
if (size(area)/=nc .or. size(perimeter)/=nc) error stop 'Unexpected geometry allocation'
if (trim(schema)=='ACE-case-input-2') then
  allocate(widths(nc))
  call vector(ncid,'ace_width','m',widths)
  call vector(ncid,'ace_area','m2',area)
  call vector(ncid,'ace_perimeter','m',perimeter)
  if (any(widths<=0) .or. any(area<=0) .or. any(perimeter<=0)) error stop 'Invalid slab geometry'
  if (any(abs(area/perimeter-widths)>64*epsilon(1.d0)*maxval(widths))) &
    error stop 'Slab area/perimeter disagrees with width'
else
  allocate(diameters(nc-1))
  call vector(ncid,'diameter','m',diameters)
  call scalar(ncid,'Lx','m',lx); call scalar(ncid,'Ly','m',ly)
  area(1:nc-1)=diameters
  perimeter(1:nc-1)=4*atan(1.d0)*diameters
  perimeter(nc)=2*(lx+ly)
  area(nc)=lx*ly-atan(1.d0)*diameters(nc-1)**2
  do i=nc-1,2,-1
    area(i)=atan(1.d0)*(diameters(i)**2-diameters(i-1)**2)
  enddo
  area(1)=atan(1.d0)*diameters(1)**2
endif
if (any(area<=0) .or. any(perimeter<=0)) error stop 'Invalid ACE area/perimeter'
call check(nf90_close(ncid))
end subroutine

subroutine read_case_basis(file,name,basis)
character(*), intent(in) :: file,name
real(real64), intent(out) :: basis(:,:,:,:)
integer :: ncid,id,i,j,k,rank,dims(nf90_max_var_dims),expected(4),nc,nb
character(64) :: schema,unit
real(real64), allocatable :: block(:,:)
call open_case(file,ncid,schema)
nc=dim_length(ncid,'response_ace'); nb=dim_length(ncid,'coarse_level')
if (any(shape(basis)/=[nc,nc,nb,nb+1])) error stop 'Unexpected internal basis shape'
if (name/='PMB' .and. name/='PMDv' .and. name/='PMD') error stop 'Unknown basis operator'
if (trim(schema)=='ACE-case-input-1' .and. name/='PMB') then
  call check(nf90_close(ncid))
  error stop 'Schema 1 does not contain momentum basis operators'
endif
unit='1'
if (name/='PMB') unit='native'
call variable(ncid,name,trim(unit),id)
call check(nf90_inquire_variable(ncid,id,ndims=rank,dimids=dims))
if (rank/=4) error stop 'Expected four basis dimensions'
call check(nf90_inq_dimid(ncid,'basis_edge',expected(1)))
call check(nf90_inq_dimid(ncid,'coarse_level',expected(2)))
call check(nf90_inq_dimid(ncid,'forcing_ace',expected(3)))
call check(nf90_inq_dimid(ncid,'response_ace',expected(4)))
if (any(dims(1:4)/=expected)) error stop 'Basis dimension order mismatch'
allocate(block(nb+1,nb))
do k=1,nc
  do j=1,nc
    call check(nf90_get_var(ncid,id,block,start=[1,1,j,k],count=[nb+1,nb,1,1]))
    if (.not.all(ieee_is_finite(block))) error stop 'Nonfinite basis operator'
    do i=1,nb
      basis(k,j,i,:)=block(:,i)
    enddo
  enddo
enddo
call check(nf90_close(ncid))
end subroutine

logical function basis_available(file,name)
character(*), intent(in) :: file,name
integer :: ncid,id,status
character(64) :: schema,source_status
call open_case(file,ncid,schema)
call check(nf90_inq_varid(ncid,name,id))
status=nf90_get_att(ncid,id,'source_status',source_status)
if (status==nf90_enotatt) then
  basis_available=.true. ! Existing supplied schema-2 operators have no marker.
else
  call check(status)
  basis_available=trim(source_status)/='disabled_zero_placeholder'
endif
call check(nf90_close(ncid))
end function

subroutine read_case_pmb(file,pmb)
character(*), intent(in) :: file
real(real64), intent(out) :: pmb(:,:,:,:)
call read_case_basis(file,'PMB',pmb)
end subroutine
end module
