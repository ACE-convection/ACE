! Export the real coarse forcing from the initial KHN26 singleACE state.
program capture
use ace_input
use ace_module, only: ace_initialization,ace_tendency,coarse_F
use iso_fortran_env, only: real64
implicit none
integer :: nc,nz,nb,u,header(3),k
character(1024) :: input_file,state_file,output_file
character(64) :: geometry
real(real64),allocatable :: profile(:,:),diam(:),cz(:),ce(:),area(:),perim(:),tv(:),x(:,:,:),ref(:,:),dx(:,:,:)
real(real64) :: lx,ly,dz
call get_command_argument(1,input_file)
call get_command_argument(2,state_file)
call get_command_argument(3,output_file)
call read_case_metadata(trim(input_file),nz,nc,nb,geometry)
allocate(profile(nz,12),diam(7),cz(nb),ce(nb+1),area(nc),perim(nc),tv(nz),x(nc+1,nz,3),ref(nz,8),dx(nc,nz,3))
call read_case_profile(trim(input_file),profile,diam,lx,ly,dz,cz,ce)
call read_case_geometry(trim(input_file),area,perim)
open(newunit=u,file=trim(state_file),access='stream',form='unformatted',status='old')
read(u) header
if (any(header/=[nc,nz,3])) error stop 'State header mismatch'
read(u) x,tv
close(u)
ref(:,1)=profile(:,11);ref(:,2)=profile(:,5)
ref(:,3)=profile(:,12);ref(:,4)=profile(:,6)
ref(:,5:6)=dz;ref(:,7)=profile(:,10)
ref(:,8)=(ref(:,7)/1.e5_real64)**(287.04_real64/1005.7_real64)
call ace_initialization(nc,nz,nb,cz,ce,trim(input_file),tv,netcdf_input=.true.)
call ace_tendency(nc,nz,2,3,4._real64,area,perim,x,ref,dx,1)
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='new')
write(u) nc,nb
write(u) coarse_F
close(u)
end program
