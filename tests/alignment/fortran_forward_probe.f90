program fortran_forward_probe
use ace_module, only: theta_e, forward_trace, set_alignment_thermo, precip_sinks, set_forward_exp_override
implicit none
integer, parameter :: count=1200
real :: input(count,5),output(count,54),temperature(1,count),vapor(1,count)
real :: liquid(1,count),ice(1,count),pressure(1,count),sink(1,count,2)
real :: qc,dql,dqi,value
integer :: u,i
character(500) :: input_file,output_file,exp_file
call get_command_argument(1,input_file)
call get_command_argument(2,output_file)
if (command_argument_count()>=3) then
 call get_command_argument(3,exp_file)
 call set_forward_exp_override(trim(exp_file))
endif
open(newunit=u,file=trim(input_file),access='stream',form='unformatted',status='old')
read(u) input
close(u)
do i=1,count
 value=theta_e(input(i,1),input(i,2),input(i,3),input(i,4),input(i,5))
 output(i,1:26)=forward_trace
 qc=input(i,3)+input(i,4); dql=0.; dqi=0.
 if (qc>0.) then
  dql=1.e-8*input(i,3)/qc; dqi=1.e-8*input(i,4)/qc
 endif
 value=theta_e(input(i,1),input(i,2),input(i,3)+dql,input(i,4)+dqi,input(i,5))
 output(i,27:52)=forward_trace
enddo
temperature(1,:)=input(:,1); vapor(1,:)=input(:,2)
liquid(1,:)=input(:,3); ice(1,:)=input(:,4); pressure(1,:)=input(:,5)
call set_alignment_thermo(temperature,vapor,liquid,ice)
call precip_sinks(1,count,pressure,sink(:,:,1),sink(:,:,2))
output(:,53)=sink(1,:,1); output(:,54)=sink(1,:,2)
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='replace')
write(u) output
close(u)
end program
