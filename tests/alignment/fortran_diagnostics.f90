program fortran_diagnostics
use ace_module, only: inv_theta_e
implicit none
real :: history(8,801,3,31),skip(8,801,3),temp(8,801),weno(8,801,2),tv(801),area(8),perimeter(8)
real :: diagnostic(8,801,5,4),profile(801,12),diameters(7),lx,ly,dz,cz(200),ce(201)
real :: full_x(9,801,10),a9(9),b9(9)
character(500) :: history_file,initial_file,output_file
integer :: u,t,index,k,a,step,snapshots(4)
call get_command_argument(1,history_file)
call get_command_argument(2,initial_file)
call get_command_argument(3,output_file)
open(newunit=u,file=trim(initial_file),access='stream',form='unformatted',status='old')
read(u) full_x,a9,b9,tv,cz,ce
close(u)
open(newunit=u,file=trim(history_file),access='stream',form='unformatted',status='old')
read(u) history(:,:,:,1),skip,temp,temp,temp,temp,temp,weno,temp,tv,area,perimeter
do step=2,31
 read(u) history(:,:,:,step)
enddo
close(u)
snapshots=[1,2,16,31]
do t=1,4
 index=snapshots(t)
 do k=1,801
  do a=1,8
   call inv_theta_e(history(a,k,1,index),history(a,k,2,index),full_x(a,k,10), &
                    diagnostic(a,k,1,t),diagnostic(a,k,2,t),diagnostic(a,k,3,t),diagnostic(a,k,4,t))
   diagnostic(a,k,5,t)=9.80665*(diagnostic(a,k,1,t)*(1.+0.607789855072462*diagnostic(a,k,2,t) &
                             -diagnostic(a,k,3,t)-diagnostic(a,k,4,t))-tv(k))/tv(k)
  enddo
 enddo
enddo
open(newunit=u,file=trim(output_file),access='stream',form='unformatted',status='replace')
write(u) diagnostic
close(u)
end program
