program test
use netcdf
use ace_module
implicit none

real,parameter :: pi=4.*atan(1.),Rd=287.04,Cp=1005.7,g=9.80665,p0=1.e5
integer :: i,j,k,m,n,o,t
integer :: ierr,ncid1,varid1
integer :: ice
real :: dum1,dum2,dum3,dum4,dum5,dum6,dum7
real :: dz,dp,ts,t_end,dt, dt_out
real :: start, finish
real*4, dimension(:,:,:), allocatable :: Xout
real, dimension(:,:), allocatable :: Tr,q,ql,qi
real, dimension(:), allocatable :: Tv0
real*4, dimension(:,:), allocatable :: T4,q4,ql4,qi4,rh4,b4 
real, dimension(:), allocatable :: A,B
real, dimension(:), allocatable :: z,T_e,q_e,Tv_e,the_e,rho_e,p_z
real, dimension(:), allocatable :: zm,T_zm,q_zm,Tv_zm,the_zm,rho_zm,p_zm,th_zm,thes_zm,rh_zm
real*8, dimension(:), allocatable :: tmp
character(300) :: path,fname

type(ace_t) :: ace


call ace%initialize("./namelist.input")


allocate(z(ace%nz),T_e(ace%nz),q_e(ace%nz),Tv_e(ace%nz),the_e(ace%nz),rho_e(ace%nz),p_z(ace%nz))
allocate(zm(ace%nzm),T_zm(ace%nzm),q_zm(ace%nzm),Tv_zm(ace%nzm),the_zm(ace%nzm),rho_zm(ace%nzm) &
        ,p_zm(ace%nzm),th_zm(ace%nzm),thes_zm(ace%nzm),rh_zm(ace%nzm),tmp(ace%nzm))
allocate(T4(ace%ncols,ace%nz),q4(ace%ncols,ace%nz),ql4(ace%ncols,ace%nz),qi4(ace%ncols,ace%nz),rh4(ace%ncols,ace%nz),b4(ace%ncols,ace%nz),Tv0(ace%nz))
allocate(Xout(ace%ncols+1,ace%nz,ace%n_prog))

fname="./input_data/ini_manus_208.dat"
open(20,file=trim(fname),access="direct",recl=ace%nz*2)
read(20,rec=5) tmp
rho_zm = tmp
read(20,rec=6) tmp
zm = tmp
read(20,rec=7) tmp
the_e = tmp
read(20,rec=8) tmp
q_e = tmp
read(20,rec=9) tmp
Tv_e = tmp
read(20,rec=10) tmp
p_z = tmp
read(20,rec=11) tmp
rho_e = tmp
read(20,rec=12) tmp
z = tmp
close(20)


dz=50
do k=1,ace%nz
  ace%X(:,k,1)=0.
  ace%X(:,k,2)=the_e(k)
  ace%X(:,k,3)=q_e(k)
  ace%Ref(k,1)=rho_e(k)
  ace%Ref(k,2)=rho_zm(k)
  ace%Ref(k,3)=z(k)
  ace%Ref(k,4)=zm(k)
  ace%Ref(k,5)=dz
  ace%Ref(k,6)=dz
  ace%Ref(k,7)=p_z(k)
  ace%Ref(k,8)=(p_z(k)/p0)**(Rd/Cp)
  call inv_theta_e(ace%X(1,k,2),ace%X(1,k,3),ace%Ref(k,7),ace%Ta(1,k),ace%q(1,k),ace%ql(1,k),ace%qi(1,k))
  Tv0(k)=ace%Ta(1,k)*(1.+0.607789855072462*ace%q(1,k)-ace%ql(1,k)-ace%qi(1,k))
  
  if (ace%n_prog==11) then  ! for P3
    ace%X(:,k,1)=0.
    ace%X(:,k,2)=ace%Ta(1,k) / ace%Ref(k,8)
    ace%X(:,k,3)=ace%q(1,k)
    ace%X(:,k,4)=0.
    ace%X(:,k,5)=0.
    ace%X(:,k,6)=0.
    ace%X(:,k,7)=0.
    ace%X(:,k,8)=0.
    ace%X(:,k,9)=0.
    ace%X(:,k,10)=0.
    ace%X(:,k,11)=0.
  endif
enddo

! initialize MF
dum1=0.
dum2=1000.
do k=1,ace%nz
  if (ace%Ref(k,4)<=dum2) then
    ace%X(1,k,1) = 0.03 & !0.03 & 
         * sin(pi*(ace%Ref(k,4)-dum1)/(dum2-dum1))
    !X(ncols,k,1) = -0.03 & 
    !     * sin(pi*(zm(k)-dum1)/(dum2-dum1))*A(1)/A(ncols)
  endif 
enddo

call cpu_time(start)


n=1
dt_out=60. ! output frequency

! call ace diagnostic and output
call ace%diagnose()
call ace%output() 


t_end=ace%t_now+dt_out
do t=1,60*24 !24*10 ! 60 is mins, and 24 is hours
  !write(*,*) ace%t_now,t_end,t

  ! call ace driver to integrate from t_now to t_end with dt
  call ace%integrate(t_end)
  
  ! call ace diagnostic and output
  call ace%diagnose()
  call ace%output() 

  t_end=ace%t_now+dt_out
enddo

call cpu_time(finish)

write(*,*) "time cost =",finish-start

end program test
