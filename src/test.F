program test
use netcdf
use ace_module
implicit none

integer, parameter :: np=37, n_weno=2
real,parameter :: pi=4.*atan(1.),Rd=287.04,Cp=1005.7,g=9.80665,p0=1.e5
integer :: i,j,k,m,n,o,t
integer :: ierr,ncid1,varid1
integer :: nprof, ncols, ice, n_prog,ndt
real :: dum1,dum2,dum3,dum4,dum5,dum6,dum7
real :: dz,dp,ts,te,dt
real :: start, finish
real, dimension(:,:,:), allocatable :: X
real*4, dimension(:,:,:), allocatable :: Xout
real, dimension(:,:), allocatable :: Ref, forcing, Tr,q,ql,qi
real, dimension(:), allocatable :: Tv0
real*4, dimension(:,:), allocatable :: T4,q4,ql4,qi4,rh4,b4 
real, dimension(:), allocatable :: A,B
real, dimension(43832,np) :: tap,husp
real, dimension(np) :: plev
real, dimension(43832) :: prp
real, dimension(np,5211) :: ta,hus
real, dimension(5211) :: pr
integer, parameter :: np5=181
real, dimension(np5) :: p5,tap5,husp5,zp5,rhop5
integer, parameter :: nz=801, nzm=801
real, dimension(nz) :: z,T_e,q_e,Tv_e,the_e,rho_e,p_z
real, dimension(nzm) :: zm,T_zm,q_zm,Tv_zm,the_zm,rho_zm,p_zm,th_zm,thes_zm,rh_zm
real*8, dimension(nzm) :: tmp
real, dimension(200) :: coarse_z
real, dimension(201) :: coarse_ze
character(300) :: path,fname

path="./data/soundings/"
fname=trim(path)//"manus_3hr_ARMBEsonde_profiles.nc"

nprof=208

goto 838 ! directly read profile from binary file.

!ierr = nf90_open(trim(fname),NF90_NOWRITE,ncid1)
!IF (ierr/=nf90_noerr) WRITE(*,*) "open fail"
!ierr = nf90_inq_varid(ncid1,"pressure",varid1)
!IF (ierr/=nf90_noerr) WRITE(*,*) "var_inq fail"
!ierr = nf90_get_var(ncid1,varid1,plev,start=(/ 1,1,1,1 /),count=(/ np,1,1,1 /))
!IF (ierr/=nf90_noerr) WRITE(*,*) "read fail"
!ierr = nf90_inq_varid(ncid1,"pr",varid1)
!IF (ierr/=nf90_noerr) WRITE(*,*) "var_inq fail"
!ierr = nf90_get_var(ncid1,varid1,prp,start=(/ 1,1,1,1 /),count=(/ 43832,1,1,1 /))
!IF (ierr/=nf90_noerr) WRITE(*,*) "read fail"
!ierr = nf90_inq_varid(ncid1,"ta",varid1)
!IF (ierr/=nf90_noerr) WRITE(*,*) "var_inq fail"
!ierr = nf90_get_var(ncid1,varid1,tap,start=(/ 1,1,1,1 /),count=(/ 43832,np,1,1 /))
!IF (ierr/=nf90_noerr) WRITE(*,*) "read fail ta"
!ierr = nf90_inq_varid(ncid1,"hus",varid1)
!IF (ierr/=nf90_noerr) WRITE(*,*) "var_inq fail"
!ierr = nf90_get_var(ncid1,varid1,husp,start=(/ 1,1,1,1 /),count=(/ 43832,np,1,1 /))
!IF (ierr/=nf90_noerr) WRITE(*,*) "read fail hus"
!ierr = nf90_close(ncid1)
!IF (ierr/=nf90_noerr) WRITE(*,*) "close fail" 
!
!n=1
!do i=1,43832 
!  if (prp(i)/=prp(i)) goto 999
!  do k=1,np
!    if (tap(i,k)/=tap(i,k) .or. husp(i,k)/=husp(i,k)) goto 999
!  enddo
!  ta(:,n)=tap(i,:) 
!  hus(:,n)=husp(i,:)
!  pr(n)=prp(i) 
!  n=n+1
!  999 continue
!enddo
!
!!write(*,*) ta(:,nprof)
!!write(*,*) hus(:,nprof)
!
!dp=5.
!p5(1)=1000.
!do k=2,np5
!  p5(k)=p5(k-1)-dp
!enddo
!p5=p5*100.
!
!call pchip(np,plev(np:1:-1),ta(np:1:-1,nprof),np5,p5(np5:1:-1),tap5(np5:1:-1),.False.)
!call pchip(np,plev(np:1:-1),hus(np:1:-1,nprof),np5,p5(np5:1:-1),husp5(np5:1:-1),.False.)
!
!zp5(1)=0.
!do k=1,np5
!  if (husp5(k)<0.) husp5(k)=0.
!  dum1=tap5(k)*(1.+0.607789855072462*husp5(k))
!  rhop5(k)=p5(k)/dum1/Rd
!  if (k>1) then
!    dum2=0.5*(dum1+tap5(k-1)*(1.+0.607789855072462*husp5(k-1)))
!    zp5(k)=zp5(k-1)+Rd/g*5.e2*dum2/p5(k)
!  endif
!enddo
!
!dz=50.
!z(1)=25.
!zm(1)=0.
!do k=2,nz
!  z(k)=z(k-1)+dz
!  zm(k)=zm(k-1)+dz
!enddo
!
!call pchip(np5,zp5,tap5,nz,z,T_e,.False.)
!call pchip(np5,zp5,husp5,nz,z,q_e,.False.)
!call pchip(np5,zp5,p5,nz,z,p_z,.False.)
!
!do k=1,nz
!  if (q_e(k)<0.) q_e(k)=0.
!  Tv_e(k)=T_e(k)*(1.+0.607789855072462*q_e(k))
!  if (z(k)>zp5(np5)) then
!    p_z(k)=p_z(k-1)*(1.-g*dz/2./Rd/Tv_e(k-1))/(1.+g*dz/2./Rd/Tv_e(k-1))
!  endif
!  rho_e(k)=p_z(k)/Tv_e(k)/Rd
!  the_e(k)=theta_e(T_e(k),q_e(k),0.,0.,p_z(k))
!enddo
!
!call pchip(nz,z,T_e,nzm,zm,T_zm,.False.)
!call pchip(nz,z,q_e,nzm,zm,q_zm,.False.)
!call pchip(nz,z,p_z,nzm,zm,p_zm,.False.)
!
!do k=1,nzm
!  if (q_zm(k)<0.) q_zm(k)=0.
!  Tv_zm(k)=T_zm(k)*(1.+0.607789855072462*q_zm(k))
!  if (z(k)>zp5(np5)) then
!    p_zm(k)=p_zm(k-1)*(1.-g*dz/2./Rd/Tv_zm(k-1))/(1.+g*dz/2./Rd/Tv_zm(k-1))
!  endif
!  rho_zm(k)=p_zm(k)/Tv_zm(k)/Rd
!  the_zm(k)=theta_e(T_zm(k),q_zm(k),0.,0.,p_zm(k))
!enddo

838 continue


!n_prog=3 ! MF, the, qt
n_prog=11 ! for P3

dz=50.
ncols=8
ts=0.
dt=2.
ndt=int(60./dt)
te=ts+dt*real(ndt)

allocate(X(ncols+1,nz,n_prog),A(ncols+1),B(ncols+1),forcing(ncols,nz), &
         Xout(ncols+1,nz,n_prog),Ref(nz,8) &
        ,Tr(ncols,nz),q(ncols,nz),ql(ncols,nz),qi(ncols,nz))
allocate(T4(ncols,nz),q4(ncols,nz),ql4(ncols,nz),qi4(ncols,nz),rh4(ncols,nz),b4(ncols,nz),Tv0(nz))

A=(/ 5., 10., 15., 25., 35., 45., 55., 0., 0./)
A=A*1.e3
B=pi*A
B(ncols:ncols+1)=(64.e3+64.e3)*2.

A(ncols)=64.e3*64.e3-0.25*pi*A(ncols-1)**2.
A(ncols+1)=A(ncols)
do k=ncols-1,2,-1
  A(k)=0.25*pi*(A(k)**2.-A(k-1)**2.)
enddo
A(1)=0.25*pi*A(1)**2.


fname="./input_data/ini_manus_208.dat"
open(20,file=trim(fname),access="direct",recl=nz*2)
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


do k=1,nz
  X(:,k,1)=0.
  X(:,k,2)=the_e(k)
  X(:,k,3)=q_e(k)
  Ref(k,1)=rho_e(k)
  Ref(k,2)=rho_zm(k)
  Ref(k,3)=z(k)
  Ref(k,4)=zm(k)
  Ref(k,5)=dz
  Ref(k,6)=dz
  Ref(k,7)=p_z(k)
  Ref(k,8)=(p_z(k)/p0)**(Rd/Cp)
  call inv_theta_e(X(1,k,2),X(1,k,3),Ref(k,7),Tr(1,k),q(1,k),ql(1,k),qi(1,k))
  Tv0(k)=Tr(1,k)*(1.+0.607789855072462*q(1,k)-ql(1,k)-qi(1,k))
  
  ! for P3
  X(:,k,1)=0.
  X(:,k,2)=Tr(1,k) / Ref(k,8)
  X(:,k,3)=q(1,k)
  X(:,k,4)=0.
  X(:,k,5)=0.
  X(:,k,6)=0.
  X(:,k,7)=0.
  X(:,k,8)=0.
  X(:,k,9)=0.
  X(:,k,10)=0.
  X(:,k,11)=0.
enddo

! initialize MF
dum1=0.
dum2=1000.
do k=1,nz
  if (zm(k)<=dum2) then
    X(1,k,1) = 0.3 & !0.03 & 
         * sin(pi*(zm(k)-dum1)/(dum2-dum1))
    !X(ncols,k,1) = -0.03 & 
    !     * sin(pi*(zm(k)-dum1)/(dum2-dum1))*A(1)/A(ncols)
  endif 
enddo


! precomputed file
fname="./input_data/PMB.dat"
do k=1,200
  coarse_z(k) = zm((k-1)*4+1)
  coarse_ze(k) = zm((k-1)*4+1)
enddo
coarse_ze(201) = 40000.

call ace_initialization(ncols,nz,200,coarse_z,coarse_ze,trim(fname))



call cpu_time(start)

!open(10,file="./data/output_singleACE_manus208.dat",access="direct",recl=ncols*nz*8)
!open(10,file="./data/output_multiACE_manus208.dat",access="direct",recl=ncols*nz*9)
!open(10,file="./data/output_multiACE_manus208_swap.dat",access="direct",recl=ncols*nz*9)
open(10,file="./data/output_multiACE_manus208_p3.dat",access="direct",recl=ncols*nz*9)
!open(10,file="./data/output_singleACE_manus208_p3.dat",access="direct",recl=ncols*nz*9)

n=1

do t=1,60*24*100 ! 60 is mins, and 48 is hours
  write(*,*) ts,te,t

  ! output diagnostic
  Xout = X
  do k=1,nz
  do i=1,ncols
  !  call inv_theta_e(X(i,k,2),X(i,k,3),Ref(k,7),Tr(i,k),q(i,k),ql(i,k),qi(i,k))
    Tr(i,k)=X(i,k,2)*Ref(k,8)
    q(i,k) =X(i,k,3)
    ql(i,k)=X(i,k,4)+X(i,k,6)
    qi(i,k)=X(i,k,8)
    ice=0
    if (Tr(i,k)<273.15) ice=1
    rh4(i,k)=q(i,k)/eval_qs(Tr(i,k),Ref(k,7),ql(i,k)+qi(i,k),ice)
    dum1=Tr(i,k)*(1.+0.607789855072462*q(i,k)-ql(i,k)-qi(i,k))
    b4(i,k)=g*(dum1-Tv0(k))/Tv0(k)
  enddo
  enddo
  !T4=Tr; q4=q; ql4=ql; qi4=qi;
  !write(10,rec=n) Xout(1:ncols,:,1:3),T4(1:ncols,:),q4(1:ncols,:),ql4(1:ncols,:),qi4(1:ncols,:),rh4(1:ncols,:),b4(1:ncols,:)
  write(10,rec=n) Xout(1:ncols,:,1:3),Xout(1:ncols,:,4),Xout(1:ncols,:,6),Xout(1:ncols,:,8),Xout(1:ncols,:,10),rh4(1:ncols,:),b4(1:ncols,:)
  n=n+1

  ! call ace driver to integrate from ts to te with dt
  call ace_driver(ncols,nz,n_weno,n_prog,X,Ref,A,B,ts,te,dt,forcing)

  ts=te
  te=ts+dt*real(ndt)
enddo

! output diagnostic
Xout = X
do k=1,nz
do i=1,ncols
  !call inv_theta_e(X(i,k,2),X(i,k,3),Ref(k,7),Tr(i,k),q(i,k),ql(i,k),qi(i,k))
  Tr(i,k)=X(i,k,2)*Ref(k,8)
  ql(i,k)=X(i,k,4)+X(i,k,6)
  qi(i,k)=X(i,k,8)
  ice=0
  if (Tr(i,k)<273.15) ice=1
  rh4(i,k)=q(i,k)/eval_qs(Tr(i,k),Ref(k,7),ql(i,k)+qi(i,k),ice)
  dum1=Tr(i,k)*(1.+0.607789855072462*q(i,k)-ql(i,k)-qi(i,k))
  b4(i,k)=g*(dum1-Tv0(k))/Tv0(k)
enddo
enddo
!T4=Tr; q4=q; ql4=ql; qi4=qi;
!write(10,rec=n) Xout(1:ncols,:,1:3),T4(1:ncols,:),q4(1:ncols,:),ql4(1:ncols,:),qi4(1:ncols,:),rh4(1:ncols,:),b4(1:ncols,:)
write(10,rec=n) Xout(1:ncols,:,1:3),Xout(1:ncols,:,4),Xout(1:ncols,:,6),Xout(1:ncols,:,8),Xout(1:ncols,:,10),rh4(1:ncols,:),b4(1:ncols,:)
close(10)

call cpu_time(finish)

write(*,*) "time cost =",finish-start


end program test
