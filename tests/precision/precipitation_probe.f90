program precipitation_probe
use ace_module, only: precip_sinks, set_probe_thermo, theta_e
implicit none
integer, parameter :: n=8
integer :: k
real :: t(1,n),q(1,n),ql(1,n),qi(1,n),p(1,n),dt(1,n),dq(1,n)
real :: qc,f,h,fd
t(1,:)=[290.,290.,290.,290.,250.,250.,273.1636783445389,290.]
q(1,:)=[.01,.01,.01,.01,.001,.001,.004,.01]
ql(1,:)=[0.,1.e-5,5.e-4,.003,0.,0.,.001,.02]
qi(1,:)=[0.,0.,0.,0.,5.e-4,.003,.001,0.]
p(1,:)=[1.e5,1.e5,1.e5,1.e5,5.e4,5.e4,8.e4,1.e5]
call set_probe_thermo(t,q,ql,qi)
call precip_sinks(1,n,p,dt,dq)
print *, storage_size(1.)
do k=1,n
 qc=ql(1,k)+qi(1,k)
 fd=0.
 if (qc>0.) then
  f=qi(1,k)/qc
  h=1.e-6
  ! Independent centered perturbation at fixed T, q, pressure and phase ratio.
  fd=(theta_e(t(1,k),q(1,k),ql(1,k)+h*(1.-f),qi(1,k)+h*f,p(1,k)) &
     -theta_e(t(1,k),q(1,k),ql(1,k)-h*(1.-f),qi(1,k)-h*f,p(1,k)))/(2.*h)
 endif
 print *, k,dt(1,k),dq(1,k),fd
enddo
end program
