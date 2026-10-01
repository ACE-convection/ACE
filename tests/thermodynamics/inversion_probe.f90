program inversion_probe
use ace_module, only: inv_theta_e
implicit none
integer :: n,u,v,i,branch,n1,n2,status,initial_failure
real, allocatable :: input(:,:),output(:,:)
real :: T,q,ql,qi
character(1000) :: input_file,output_file
call get_command_argument(1,input_file)
call get_command_argument(2,output_file)
open(newunit=u,file=trim(input_file),access='stream',form='unformatted',status='old')
read(u) n
allocate(input(n,3),output(n,13))
read(u) input
close(u)
do i=1,n
 call inv_theta_e(input(i,1),input(i,2),input(i,3),T,q,ql,qi,branch,n1,n2,status,initial_failure)
 output(i,1:4)=[T,q,ql,qi]
 output(i,5:8)=0.
 output(i,9:13)=real([branch,n1,n2,status,initial_failure])
enddo
open(newunit=v,file=trim(output_file),access='stream',form='unformatted',status='replace')
write(v) output
close(v)
end program
