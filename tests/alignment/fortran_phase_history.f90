program fortran_phase_history
use ace_module, only: inv_theta_e
use iso_fortran_env, only: int32
implicit none
integer(int32) :: n
integer :: u,i
real, allocatable :: input(:,:),output(:,:)
character(500) :: input_file,output_file
call get_command_argument(1,input_file)
call get_command_argument(2,output_file)
open(newunit=u,file=trim(input_file),access='stream',form='unformatted',status='old')
read(u) n
allocate(input(n,3),output(n,4))
read(u) input
close(u)
do i=1,n
 call inv_theta_e(input(i,1),input(i,2),input(i,3), &
                  output(i,1),output(i,2),output(i,3),output(i,4))
enddo
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='replace')
write(u) output
close(u)
end program
