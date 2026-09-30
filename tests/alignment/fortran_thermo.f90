program fortran_thermo
use ace_module, only: inv_theta_e, theta_e, set_alignment_thermo, precip_sinks
implicit none
real :: input(10,7),output(10,7),pressure(1,10),dtheta(1,10),dqt(1,10)
character(500) :: input_file,output_file
integer :: u,i
call get_command_argument(1,input_file)
call get_command_argument(2,output_file)
open(newunit=u,file=trim(input_file),access='stream',form='unformatted',status='old')
read(u) input
close(u)
do i=1,10
 call inv_theta_e(input(i,1),input(i,2),input(i,3),output(i,1),output(i,2),output(i,3),output(i,4))
 output(i,5)=theta_e(input(i,4),input(i,5),input(i,6),input(i,7),input(i,3))
enddo
call set_alignment_thermo(reshape(input(:,4),[1,10]),reshape(input(:,5),[1,10]), &
                         reshape(input(:,6),[1,10]),reshape(input(:,7),[1,10]))
pressure(1,:)=input(:,3)
call precip_sinks(1,10,pressure,dtheta,dqt)
output(:,6)=dtheta(1,:); output(:,7)=dqt(1,:)
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='replace')
write(u) output
close(u)
end program
