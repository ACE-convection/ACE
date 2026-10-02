program fortran_sounding_case
use ace_module, only: ace_initialization, ace_driver, set_alignment_single
use ace_input
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
implicit none
integer, parameter :: nz=801
real :: X(9,nz,10),A(9),B(9),Tv0(nz),cz(200),ce(201),forcing(8,nz)
real :: profile(nz,12),diameters(7),lx,ly,dz,now,finish,dt,pi
character(500) :: initial_file,input_file,output_file,arg,override_file,mode
integer :: u,k,step,duration,output_step,pulse
call get_command_argument(1,initial_file)
call get_command_argument(2,input_file)
call get_command_argument(3,output_file)
call get_command_argument(4,arg)
read(arg,*) duration
call get_command_argument(5,arg)
read(arg,*) output_step
open(newunit=u,file=trim(initial_file),access='stream',form='unformatted',status='old')
read(u) X,A,B,Tv0,cz,ce
close(u)
call read_case_profile(trim(input_file),profile,diameters,lx,ly,dz,cz,ce)
Tv0=profile(:,9)
call ace_initialization(8,nz,200,cz,ce,trim(input_file),Tv0,netcdf_input=.true.)
mode='single'
if (command_argument_count()>=7) call get_command_argument(7,mode)
if (trim(mode)/='single' .and. trim(mode)/='multi') error stop 'Unknown ACE mode'
call set_alignment_single(trim(mode)=='single')
pulse=1
if (trim(mode)=='multi') pulse=8
pi=4.*atan(1.)
X(:,:,3)=0.
do k=1,nz
 if (X(pulse,k,7)<=1000.) X(pulse,k,3)=0.03*sin(pi*X(pulse,k,7)/1000.)
enddo
if (command_argument_count()>=6) then
 call get_command_argument(6,override_file)
 open(newunit=u,file=trim(override_file),access='stream',form='unformatted',status='old')
 read(u) X(1:8,:,1:3)
 close(u)
endif
forcing=0.; now=0.; dt=4.
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='new')
write(u) X(1:8,:,1:3)
do step=1,duration/4
 finish=now+dt
 call ace_driver(8,nz,2,X,A(1:8),B(1:8),now,finish,dt,forcing)
 if (.not.all(ieee_is_finite(X(1:8,:,1:3)))) error stop 'Nonfinite trajectory'
 if (mod(step*4,output_step)==0) write(u) X(1:8,:,1:3)
 if (mod(step*4,600)==0) then
  print *, 'Completed seconds:',step*4
  flush(6)
 endif
enddo
close(u)
end program
