program read_case
use iso_fortran_env, only: real64
use ace_input
implicit none
real(real64) :: profile(801,12),d(7),lx,ly,dz,zc(200),ze(201)
real(real64) :: pmb(8,8,200,201)
character(500) :: input,output
integer :: u,i,j,k
call get_command_argument(1,input)
call get_command_argument(2,output)
call read_case_profile(trim(input),profile,d,lx,ly,dz,zc,ze)
call read_case_pmb(trim(input),pmb)
open(newunit=u,file=trim(output),access='stream',form='unformatted',status='replace')
write(u) profile
do k=1,8
  do j=1,8
    do i=1,200
      write(u) pmb(k,j,i,:)
    enddo
  enddo
enddo
close(u)
end program
