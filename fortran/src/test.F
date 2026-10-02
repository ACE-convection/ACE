program test
use netcdf
use ace_module
use ace_input, only: read_case_profile
implicit none

integer, parameter :: np=37, n_weno=2
real,parameter :: pi=4.*atan(1.),Rd=287.04,Cp=1005.7,g=9.80665
integer :: i,j,k,m,n,o,t
integer :: ierr,ncid1,varid1
integer :: nprof, ncols, ice
real :: dum1,dum2,dum3,dum4,dum5,dum6,dum7
real :: dz,dp,ts,te,dt
real :: start, finish
real, dimension(:,:,:), allocatable :: X
real*4, dimension(:,:,:), allocatable :: Xout
real, dimension(:,:), allocatable :: forcing, Tr,q,ql,qi
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
character(300) :: path,fname,input_file,arg,validation_file,output_file
logical :: shared_input
integer :: argument, record_length, intervals, parse_status
real*8 :: input_profile(801,12),diameters(7),input_lx,input_ly,input_dz
real*8 :: input_coarse_z(200),input_coarse_ze(201)

shared_input=.true.
input_file='../data/input/manus208.nc'
validation_file=''
output_file='./data/output_multiACE_manus208.dat'
intervals=60*48
argument=1
do while (argument<=command_argument_count())
  call get_command_argument(argument,arg)
  select case(trim(arg))
  case('--legacy-input')
    shared_input=.false.
  case('--input')
    argument=argument+1
    call get_command_argument(argument,input_file)
    if (len_trim(input_file)==0) error stop 'Missing --input path'
  case('--output')
    argument=argument+1
    call get_command_argument(argument,output_file)
    if (len_trim(output_file)==0) error stop 'Missing --output path'
  case('--intervals')
    argument=argument+1
    call get_command_argument(argument,arg)
    read(arg,*,iostat=parse_status) intervals
    if (parse_status/=0) error stop 'Invalid --intervals value'
    if (intervals<1) error stop 'Intervals must be positive'
  case('--validate-input')
    argument=argument+1
    call get_command_argument(argument,validation_file)
    if (len_trim(validation_file)==0) error stop 'Missing validation output path'
  case default
    error stop 'Unknown command argument'
  end select
  argument=argument+1
enddo

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

dz=50.
ncols=8
ts=0.
dt=4.
te=ts+dt*15.
!te=4.

allocate(X(ncols+1,nz,10),A(ncols+1),B(ncols+1),forcing(ncols,nz),Xout(ncols+1,nz,3) &
        ,Tr(ncols,nz),q(ncols,nz),ql(ncols,nz),qi(ncols,nz))
allocate(T4(ncols,nz),q4(ncols,nz),ql4(ncols,nz),qi4(ncols,nz),rh4(ncols,nz),b4(ncols,nz),Tv0(nz))

if (shared_input) then
  call read_case_profile(trim(input_file),input_profile,diameters,input_lx,input_ly,input_dz, &
                         input_coarse_z,input_coarse_ze)
  if (input_dz/=50.d0 .or. input_lx/=64000.d0 .or. input_ly/=64000.d0) &
    error stop 'Shared case disagrees with v0.18 geometry/grid'
  A(1:7)=diameters/1.d3
  A(8:9)=0.
else
A=(/ 5., 10., 15., 25., 35., 45., 55., 0., 0./)
endif
A=A*1.e3
B=pi*A
B(ncols:ncols+1)=(64.e3+64.e3)*2.

A(ncols)=64.e3*64.e3-0.25*pi*A(ncols-1)**2.
A(ncols+1)=A(ncols)
do k=ncols-1,2,-1
  A(k)=0.25*pi*(A(k)**2.-A(k-1)**2.)
enddo
A(1)=0.25*pi*A(1)**2.


if (shared_input) then
  rho_zm=input_profile(:,5); zm=input_profile(:,6)
  the_e=input_profile(:,7); q_e=input_profile(:,8); Tv_e=input_profile(:,9)
  p_z=input_profile(:,10); rho_e=input_profile(:,11); z=input_profile(:,12)
  if (any(z/=(/(25.d0+50.d0*(k-1),k=1,nz)/)) .or. &
      any(zm/=(/(50.d0*(k-1),k=1,nz)/))) error stop 'Unexpected shared vertical grid'
else
fname="./input_data/ini_manus_208.dat"
inquire(iolength=record_length) tmp
open(20,file=trim(fname),access="direct",recl=record_length)
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
endif


do k=1,nz
  X(:,k,1)=the_e(k)
  X(:,k,2)=q_e(k)
  X(:,k,3)=0.
  X(:,k,4)=rho_e(k)
  X(:,k,5)=rho_zm(k)
  X(:,k,6)=z(k)
  X(:,k,7)=zm(k)
  X(:,k,8)=dz
  X(:,k,9)=dz
  X(:,k,10)=p_z(k)
  call inv_theta_e(X(1,k,1),X(1,k,2),X(1,k,10),Tr(1,k),q(1,k),ql(1,k),qi(1,k))
  Tv0(k)=Tv_e(k)
enddo


! initialize MF
dum1=0.
dum2=1000.
do k=1,nz
  if (zm(k)<=dum2) then
    X(ncols,k,3) = 0.03 & 
         * sin(pi*(zm(k)-dum1)/(dum2-dum1))
    !X(ncols,k,3) = -0.03 & 
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

if (shared_input) then
  fname=input_file
  coarse_z=input_coarse_z
  coarse_ze=input_coarse_ze
endif
call ace_initialization(ncols,nz,200,coarse_z,coarse_ze,trim(fname),Tv0,netcdf_input=shared_input)

if (len_trim(validation_file)>0) then
  open(30,file=trim(validation_file),access='stream',form='unformatted',status='replace')
  write(30) X,A,B,Tv0,coarse_z,coarse_ze
  close(30)
  stop
endif



call cpu_time(start)

!open(10,file="./data/output_singleACE_manus208.dat",access="direct",recl=ncols*nz*8)
inquire(iolength=record_length) Xout(1:ncols,:,1:3),T4,q4,ql4,qi4,rh4,b4
open(10,file=trim(output_file),access="direct",recl=record_length)
n=1

do t=1,intervals ! Each interval advances 15 steps / 60 seconds; default 48 hours
  write(*,*) ts,te

  ! output diagnostic
  Xout = X(:,:,1:3)
  do k=1,nz
  do i=1,ncols
    call inv_theta_e(X(i,k,1),X(i,k,2),X(i,k,10),Tr(i,k),q(i,k),ql(i,k),qi(i,k))
    ice=0
    if (Tr(i,k)<273.15) ice=1
    rh4(i,k)=q(i,k)/eval_qs(Tr(i,k),X(i,k,10),ql(i,k)+qi(i,k),ice)
    dum1=Tr(i,k)*(1.+0.607789855072462*q(i,k)-ql(i,k)-qi(i,k))
    b4(i,k)=g*(dum1-Tv0(k))/Tv0(k)
  enddo
  enddo
  T4=Tr;  q4=q; ql4=ql; qi4=qi;
  write(10,rec=n) Xout(1:ncols,:,1:3),T4(1:ncols,:),q4(1:ncols,:),ql4(1:ncols,:),qi4(1:ncols,:),rh4(1:ncols,:),b4(1:ncols,:)
  n=n+1

  ! call ace driver to integrate from ts to te with dt
  call ace_driver(ncols,nz,n_weno,X,A,B,ts,te,dt,forcing)

  ts=te
  te=ts+dt*15.
enddo

! output diagnostic
Xout = X(:,:,1:3)
do k=1,nz
do i=1,ncols
  call inv_theta_e(X(i,k,1),X(i,k,2),X(i,k,10),Tr(i,k),q(i,k),ql(i,k),qi(i,k))
  ice=0
  if (Tr(i,k)<273.15) ice=1
  rh4(i,k)=q(i,k)/eval_qs(Tr(i,k),X(i,k,10),ql(i,k)+qi(i,k),ice)
  dum1=Tr(i,k)*(1.+0.607789855072462*q(i,k)-ql(i,k)-qi(i,k))
  b4(i,k)=g*(dum1-Tv0(k))/Tv0(k)
enddo
enddo
T4=Tr;  q4=q; ql4=ql; qi4=qi;
write(10,rec=n) Xout(1:ncols,:,1:3),T4(1:ncols,:),q4(1:ncols,:),ql4(1:ncols,:),qi4(1:ncols,:),rh4(1:ncols,:),b4(1:ncols,:)
close(10)

call cpu_time(finish)

write(*,*) finish-start


end program test
