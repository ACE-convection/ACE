! Compiled against a test-only module with component access exposed.
program components
use ace_module
implicit none
type(ace_t) :: m
character(1024) :: input
character(16) :: physics
integer :: nc,nz,nb,np,intervals,i,k,h,v,u
real :: dt
real, allocatable :: tendency(:,:,:)
logical :: slab,precip
call get_command_argument(1,input)
physics='none';dt=6.;intervals=1
call m%initialize(.true.,trim(input),'./',2,physics,dt,intervals,.true., &
                  nc,nz,nb,np,slab,precip,turn_off_DHv_input=.false.,turn_off_DHh_input=.false.)
allocate(tendency(nc,nz,np))
! Nonzero MF of both signs exercises both momentum operators and boundaries.
do i=1,nc
  do k=1,nz
    m%X(i,k,1)=0.05*sin(real(k)/13.)*cos(real(i)/7.)
  enddo
enddo
m%X(:,1,1)=0.;m%X(:,nz-10:nz,1)=0.
open(newunit=u,file='components.bin',access='stream',form='unformatted',status='new')
write(u) nc,nz,nb
write(u) m%X(1:nc,:,:),m%Ref,m%A(1:nc),m%B(1:nc),m%Tv0
do h=0,1
  do v=0,1
    m%response%turn_off_DHh=h==0;m%response%turn_off_DHv=v==0
    call ace_tendency_context(m%response,m%thermal,nc,nz,2,np,dt,m%A(1:nc),m%B(1:nc), &
                             m%X,m%Ref,tendency,1)
    write(u) tendency,m%response%dwdt
  enddo
enddo
close(u)
end program
