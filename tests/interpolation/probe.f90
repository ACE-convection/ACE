program interpolation_probe
use ace_interpolation, only: interp1
use iso_fortran_env, only: real64, int32
implicit none
integer(int32) :: n,nq
integer :: u
real(real64), allocatable :: xd(:),yd(:),xqd(:),result(:)
real, allocatable :: x(:),y(:),xq(:),yq(:)
character(1024) :: input,output
character(32) :: method,policy
call get_command_argument(1,input)
call get_command_argument(2,output)
call get_command_argument(3,method)
call get_command_argument(4,policy)
open(newunit=u,file=trim(input),access='stream',form='unformatted',status='old')
read(u) n,nq
allocate(xd(n),yd(n),xqd(nq),result(nq),x(n),y(n),xq(nq),yq(nq))
read(u) xd,yd,xqd
close(u)
x=real(xd,kind(x)); y=real(yd,kind(y)); xq=real(xqd,kind(xq))
select case(trim(policy))
case('default')
  call interp1(n,x,y,nq,xq,yq,trim(method))
case('extrap','endpoint')
  call interp1(n,x,y,nq,xq,yq,trim(method),extrap=trim(policy)=='extrap')
case default
  error stop 'Invalid test endpoint policy'
end select
result=real(yq,real64)
open(newunit=u,file=trim(output),access='stream',form='unformatted',status='replace')
write(u) result
close(u)
end program
