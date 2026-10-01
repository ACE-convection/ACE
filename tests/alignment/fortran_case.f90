program fortran_case
use ace_module, only: ace_initialization, ace_driver, ace_tendency, set_alignment_single, inv_theta_e, weno_vec, weno_up3
use ace_input
implicit none
integer, parameter :: ncols=8,nz=801
real :: X(9,nz,10),A(9),B(9),Tv0(nz),cz(200),ce(201),forcing(8,nz)
real :: tendency(8,nz,3),temperature(8,nz),vapor(8,nz),liquid(8,nz),ice(8,nz)
real :: buoyancy(8,nz),weno(8,nz,2),upwind(8,nz),now,finish,dt,pi
real :: profile(nz,12),diameters(7),lx,ly,dz
character(500) :: initial_file,input_file,output_file,mode,override_file
integer :: u,k,i,n,step,pulse
call get_command_argument(1,initial_file)
call get_command_argument(2,input_file)
call get_command_argument(3,output_file)
call get_command_argument(4,mode)
open(newunit=u,file=trim(initial_file),access='stream',form='unformatted',status='old')
read(u) X,A,B,Tv0,cz,ce
close(u)
! Read the reference directly even when reusing a historical initialization dump.
call read_case_profile(trim(input_file),profile,diameters,lx,ly,dz,cz,ce)
Tv0=profile(:,9)
call ace_initialization(8,801,200,cz,ce,trim(input_file),Tv0,netcdf_input=.true.)
call set_alignment_single(trim(mode)=='single')
pulse=8
if (trim(mode)=='single') pulse=1
pi=4.*atan(1.)
X(:,:,3)=0.
do k=1,nz
 if (X(pulse,k,7)<=1000.) X(pulse,k,3)=0.03*sin(pi*X(pulse,k,7)/1000.)
enddo
if (command_argument_count()>=5) then
 call get_command_argument(5,override_file)
 open(newunit=u,file=trim(override_file),access='stream',form='unformatted',status='old')
 read(u) X(1:8,:,1:3)
 close(u)
endif
forcing=0.
now=0.; dt=4.
call ace_tendency(8,801,2,A(1:8),B(1:8),X,tendency,1)
do i=1,8
 do k=1,nz
  call inv_theta_e(X(i,k,1),X(i,k,2),X(i,k,10),temperature(i,k),vapor(i,k),liquid(i,k),ice(i,k))
  buoyancy(i,k)=9.80665*(temperature(i,k)*(1.+0.607789855072462*vapor(i,k)-liquid(i,k)-ice(i,k))-Tv0(k))/Tv0(k)
 enddo
 do n=1,2
  call weno_vec(2,801,X(i,:,n),X(i,:,3),weno(i,:,n))
 enddo
 call weno_up3(801,X(i,:,3),upwind(i,:))
enddo
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='replace')
write(u) X(1:8,:,1:3),tendency,temperature,vapor,liquid,ice,buoyancy,weno,upwind,Tv0,A(1:8),B(1:8)
do step=1,30
 finish=now+dt
 call ace_driver(8,801,2,X,A(1:8),B(1:8),now,finish,dt,forcing)
 write(u) X(1:8,:,1:3)
enddo
close(u)
end program
