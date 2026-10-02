module ace_input
use netcdf
use iso_fortran_env, only: real64
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
implicit none
private
public :: read_case_profile, read_case_pmb
contains

subroutine check(status)
integer, intent(in) :: status
if (status /= nf90_noerr) then
  write(*,*) 'ACE input: ',trim(nf90_strerror(status))
  error stop 1
endif
end subroutine

subroutine open_case(file,ncid)
character(*), intent(in) :: file
integer, intent(out) :: ncid
character(64) :: schema
call check(nf90_open(file,nf90_nowrite,ncid))
call check(nf90_get_att(ncid,nf90_global,'ace_input_schema',schema))
if (trim(schema)/='ACE-case-input-1') error stop 'Unsupported ACE input schema'
call dimension(ncid,'mf_level',801)
call dimension(ncid,'zc_level',801)
call dimension(ncid,'basis_edge',201)
call dimension(ncid,'coarse_level',200)
call dimension(ncid,'forcing_ace',8)
call dimension(ncid,'response_ace',8)
call dimension(ncid,'radial_boundary',7)
end subroutine

subroutine dimension(ncid,name,expected)
integer, intent(in) :: ncid, expected
character(*), intent(in) :: name
integer :: id, length
call check(nf90_inq_dimid(ncid,name,id))
call check(nf90_inquire_dimension(ncid,id,len=length))
if (length/=expected) error stop 'Unexpected ACE input dimension'
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
case('coarse_z')
  expected='coarse_level'
case('coarse_ze')
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
integer :: id
call variable(ncid,name,unit,id)
call check(nf90_get_var(ncid,id,value))
if (.not.ieee_is_finite(value)) error stop 'Nonfinite ACE input'
end subroutine

subroutine read_case_profile(file,profile,diameters,lx,ly,dz,coarse_z,coarse_ze)
character(*), intent(in) :: file
real(real64), intent(out) :: profile(801,12), diameters(7), lx, ly, dz
real(real64), intent(out) :: coarse_z(200),coarse_ze(201)
integer :: ncid
call open_case(file,ncid)
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
call vector(ncid,'diameter','m',diameters)
call scalar(ncid,'Lx','m',lx)
call scalar(ncid,'Ly','m',ly)
call scalar(ncid,'dz','m',dz)
call vector(ncid,'coarse_z','m',coarse_z)
call vector(ncid,'coarse_ze','m',coarse_ze)
call check(nf90_close(ncid))
end subroutine

subroutine read_case_pmb(file,pmb)
character(*), intent(in) :: file
real(real64), intent(out) :: pmb(:,:,:,:)
integer :: ncid,id,i,j,k,rank,dims(nf90_max_var_dims),expected(4)
real(real64) :: block(201,200)
if (any(shape(pmb)/=[8,8,200,201])) error stop 'Unexpected internal PMB shape'
call open_case(file,ncid)
call variable(ncid,'PMB','1',id)
call check(nf90_inquire_variable(ncid,id,ndims=rank,dimids=dims))
if (rank/=4) error stop 'Expected four PMB dimensions'
call check(nf90_inq_dimid(ncid,'basis_edge',expected(1)))
call check(nf90_inq_dimid(ncid,'coarse_level',expected(2)))
call check(nf90_inq_dimid(ncid,'forcing_ace',expected(3)))
call check(nf90_inq_dimid(ncid,'response_ace',expected(4)))
if (any(dims(1:4)/=expected)) error stop 'PMB dimension order mismatch'
do k=1,8
  do j=1,8
    call check(nf90_get_var(ncid,id,block,start=[1,1,j,k],count=[201,200,1,1]))
    if (.not.all(ieee_is_finite(block))) error stop 'Nonfinite PMB'
    do i=1,200
      pmb(k,j,i,:)=block(:,i)
    enddo
  enddo
enddo
call check(nf90_close(ncid))
end subroutine
end module
