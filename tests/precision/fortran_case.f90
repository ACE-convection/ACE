program precision_case
use ace_module, only: ace_initialization, ace_driver, set_probe_single
use ace_input, only: read_case_profile
use iso_fortran_env, only: real64
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
implicit none
integer, parameter :: nz=801
real :: x(9,nz,10),a(9),b(9),tv0(nz),cz(200),ce(201),forcing(8,nz),now,finish
real(real64) :: profile(nz,12),diameters(7),lx,ly,dz,cz64(200),ce64(201),seed(8,nz,3)
character(500) :: initial_file,input_file,output_file,seed_file,arg,mode
integer :: u,step,duration
call get_command_argument(1,initial_file)
call get_command_argument(2,input_file)
call get_command_argument(3,output_file)
call get_command_argument(4,seed_file)
call get_command_argument(5,arg)
read(arg,*) duration
mode='single'
if (command_argument_count()>=6) call get_command_argument(6,mode)
if (trim(mode)/='single' .and. trim(mode)/='multi') error stop 'Unknown ACE mode'
open(newunit=u,file=trim(initial_file),access='stream',form='unformatted',status='old')
read(u) x,a,b,tv0,cz,ce
close(u)
call read_case_profile(trim(input_file),profile,diameters,lx,ly,dz,cz64,ce64)
tv0=real(profile(:,9)); cz=real(cz64); ce=real(ce64)
call ace_initialization(8,nz,200,cz,ce,trim(input_file),tv0,netcdf_input=.true.)
call set_probe_single(trim(mode)=='single')
open(newunit=u,file=trim(seed_file),access='stream',form='unformatted',status='old')
read(u) seed
close(u)
x(1:8,:,1:3)=real(seed)
forcing=0.; now=0.
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='new')
write(u) x(1:8,:,1:3)
do step=1,duration/4
 finish=now+4.
 call ace_driver(8,nz,2,x,a(1:8),b(1:8),now,finish,4.,forcing)
 if (.not.all(ieee_is_finite(x))) error stop 'Nonfinite state'
 if (any(x(1:8,:,2)<0.)) error stop 'Negative total water'
 if (mod(step,15)==0) write(u) x(1:8,:,1:3)
 if (mod(step,150)==0) then
  print *, 'Completed seconds:',step*4
  flush(6)
 endif
enddo
close(u)
print *, 'Completed',now,'real bits',storage_size(now)
end program
