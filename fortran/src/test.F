program test
use ace_module
use ace_input, only: read_case_metadata, read_case_profile, read_case_geometry
use iso_fortran_env, only: real64
implicit none

integer, parameter :: n_weno=2, n_prog=11
! P3 prognostics: MF, th, qv, qc, nc, qr, nr, qi, ni, qrim, brim.
! Shared theta_e/qt profiles are input metadata, converted once before integration.
real, parameter :: Rd=287.04, Cp=1005.7, g=9.80665, p0=1.e5
integer :: i,k,n,t,ncols,nz,ncoarse,ndt,argument,parse_status,record_length,io_status
integer :: intervals
real :: dz,ts,te,dt,start,finish,dum1
real, allocatable :: X(:,:,:),Ref(:,:),forcing(:,:),Tr(:,:),q(:,:),ql(:,:),qi(:,:)
real, allocatable :: A(:),B(:),Tv0(:),z(:),zm(:),rho_e(:),rho_zm(:),the_e(:),q_e(:),p_z(:)
real, allocatable :: coarse_z(:),coarse_ze(:)
real(kind=4), allocatable :: Xout(:,:,:),rh4(:,:),b4(:,:)
real(real64), allocatable :: input_profile(:,:),diameters(:),input_area(:),input_perimeter(:)
real(real64), allocatable :: input_coarse_z(:),input_coarse_ze(:),tmp(:)
real(real64) :: input_lx,input_ly,input_dz
logical :: shared_input
character(1024) :: input_file,output_file,validation_file,arg,p3_directory
character(64) :: geometry

shared_input=.true.
input_file='../data/input/goamazon314_s20.nc'
output_file='./data/output_multiACE_p3.dat'
validation_file=''
p3_directory='./input_data/'
intervals=60*24*100 ! historical run length; select explicitly with --intervals
argument=1
do while (argument<=command_argument_count())
  call get_command_argument(argument,arg)
  select case(trim(arg))
  case('--legacy-input')
    shared_input=.false.
  case('--input','--output','--validate-input','--p3-lookup-directory','--intervals')
    block
      character(1024) :: option,value
      option=arg
      argument=argument+1
      if (argument>command_argument_count()) error stop 'Missing command argument value'
      call get_command_argument(argument,value)
      if (len_trim(value)==0) error stop 'Empty command argument value'
      select case(trim(option))
      case('--input'); input_file=value
      case('--output'); output_file=value
      case('--validate-input'); validation_file=value
      case('--p3-lookup-directory'); p3_directory=value
      case('--intervals')
        read(value,*,iostat=parse_status) intervals
        if (parse_status/=0) error stop 'Invalid --intervals value'
        if (intervals<1) error stop 'Intervals must be positive'
      end select
    end block
  case default
    error stop 'Unknown command argument'
  end select
  argument=argument+1
enddo

if (shared_input) then
  call read_case_metadata(trim(input_file),nz,ncols,ncoarse,geometry)
else
  nz=801; ncols=8; ncoarse=200; geometry='annular'
endif
allocate(input_profile(nz,12),diameters(7),input_area(ncols),input_perimeter(ncols))
allocate(input_coarse_z(ncoarse),input_coarse_ze(ncoarse+1),tmp(nz))
if (shared_input) then
  call read_case_profile(trim(input_file),input_profile,diameters,input_lx,input_ly,input_dz, &
                         input_coarse_z,input_coarse_ze)
  call read_case_geometry(trim(input_file),input_area,input_perimeter)
else
  input_profile=0.
  inquire(iolength=record_length) tmp
  open(20,file='./input_data/ini_manus_208.dat',access='direct',recl=record_length,status='old',iostat=io_status)
  if (io_status/=0) error stop 'Cannot open legacy initial profile'
  do k=5,12
    read(20,rec=k,iostat=io_status) input_profile(:,k)
    if (io_status/=0) error stop 'Cannot read legacy initial profile'
  enddo
  close(20)
  input_dz=50.; input_lx=64000.; input_ly=64000.
  diameters=[5000.d0,10000.d0,15000.d0,25000.d0,35000.d0,45000.d0,55000.d0]
  input_area(1:7)=diameters
  input_perimeter(1:7)=4*atan(1.d0)*diameters
  input_perimeter(8)=2*(input_lx+input_ly)
  input_area(8)=input_lx*input_ly-atan(1.d0)*diameters(7)**2
  do i=7,2,-1
    input_area(i)=atan(1.d0)*(diameters(i)**2-diameters(i-1)**2)
  enddo
  input_area(1)=atan(1.d0)*diameters(1)**2
  do k=1,ncoarse
    input_coarse_z(k)=input_profile((k-1)*4+1,6)
    input_coarse_ze(k)=input_coarse_z(k)
  enddo
  input_coarse_ze(ncoarse+1)=40000.
endif

allocate(X(ncols+1,nz,n_prog),Ref(nz,8),forcing(ncols,nz),Xout(ncols+1,nz,n_prog))
allocate(Tr(ncols,nz),q(ncols,nz),ql(ncols,nz),qi(ncols,nz),rh4(ncols,nz),b4(ncols,nz))
allocate(A(ncols+1),B(ncols+1),Tv0(nz),z(nz),zm(nz),rho_e(nz),rho_zm(nz),the_e(nz),q_e(nz),p_z(nz))
allocate(coarse_z(ncoarse),coarse_ze(ncoarse+1))
A(1:ncols)=real(input_area,kind(A)); B(1:ncols)=real(input_perimeter,kind(B))
A(ncols+1)=A(ncols); B(ncols+1)=B(ncols)
dz=real(input_dz,kind(dz))
rho_zm=real(input_profile(:,5),kind(rho_zm)); zm=real(input_profile(:,6),kind(zm))
the_e=real(input_profile(:,7),kind(the_e)); q_e=real(input_profile(:,8),kind(q_e))
p_z=real(input_profile(:,10),kind(p_z)); rho_e=real(input_profile(:,11),kind(rho_e))
z=real(input_profile(:,12),kind(z))
coarse_z=real(input_coarse_z,kind(coarse_z)); coarse_ze=real(input_coarse_ze,kind(coarse_ze))
forcing=0.
X=0.
! Convert shared theta_e/qt input once; the P3 state stores th and qv.
do k=1,nz
  Ref(k,1)=rho_e(k); Ref(k,2)=rho_zm(k)
  Ref(k,3)=z(k); Ref(k,4)=zm(k)
  Ref(k,5)=dz; Ref(k,6)=dz; Ref(k,7)=p_z(k)
  Ref(k,8)=(p_z(k)/p0)**(Rd/Cp)
  call inv_theta_e(the_e(k),q_e(k),Ref(k,7),Tr(1,k),q(1,k),ql(1,k),qi(1,k))
  Tv0(k)=real(input_profile(k,9),kind(Tv0)) ! fixed input Tv_zc, as in v0.18/MATLAB
  X(:,k,2)=Tr(1,k)/Ref(k,8)
  X(:,k,3)=q(1,k)
enddo
! Retain historical inner-ACE MF pulse; this is not the MATLAB S20 bubble.
do k=1,nz
  if (zm(k)<=1000.) X(1,k,1)=0.3*sin(4.*atan(1.)*zm(k)/1000.)
enddo
call set_p3_lookup_directory(trim(p3_directory))
if (shared_input) then
  call ace_initialization(ncols,nz,ncoarse,coarse_z,coarse_ze,trim(input_file),Tv0,netcdf_input=.true.)
else
  call ace_initialization(ncols,nz,ncoarse,coarse_z,coarse_ze,'./input_data/PMB.dat',Tv0)
endif

if (len_trim(validation_file)>0) then
  open(30,file=trim(validation_file),access='stream',form='unformatted',status='replace')
  write(30) ncols,nz,n_prog,ncoarse
  write(30) real(X,real64),real(Ref,real64),real(A,real64),real(B,real64),real(Tv0,real64), &
            input_coarse_z,input_coarse_ze
  close(30)
  stop
endif

ts=0.; dt=2.; ndt=int(60./dt); te=ts+dt*real(ndt)
call cpu_time(start)
! Retain the historical nine-field real32 output, using compiler-independent record sizing.
inquire(iolength=record_length) Xout(1:ncols,:,1:3),Xout(1:ncols,:,4),Xout(1:ncols,:,6), &
                              Xout(1:ncols,:,8),Xout(1:ncols,:,10),rh4,b4
open(10,file=trim(output_file),access='direct',form='unformatted',recl=record_length,iostat=io_status)
if (io_status/=0) error stop 'Cannot open model output; provide an existing output directory'
n=1
do t=1,intervals
  call write_state()
  call ace_driver(ncols,nz,n_weno,n_prog,X,Ref,A,B,ts,te,dt,forcing)
  ts=te; te=ts+dt*real(ndt)
enddo
call write_state()
close(10)
call cpu_time(finish)
write(*,*) 'time cost =',finish-start

contains
subroutine write_state()
Xout=X
do k=1,nz
  do i=1,ncols
    Tr(i,k)=X(i,k,2)*Ref(k,8)
    q(i,k)=X(i,k,3)
    ql(i,k)=X(i,k,4)+X(i,k,6)
    qi(i,k)=X(i,k,8)
    rh4(i,k)=q(i,k)/eval_qs(Tr(i,k),Ref(k,7),ql(i,k)+qi(i,k),merge(1,0,Tr(i,k)<273.15))
    dum1=Tr(i,k)*(1.+0.607789855072462*q(i,k)-ql(i,k)-qi(i,k))
    b4(i,k)=g*(dum1-Tv0(k))/Tv0(k)
  enddo
enddo
write(10,rec=n) Xout(1:ncols,:,1:3),Xout(1:ncols,:,4),Xout(1:ncols,:,6), &
                 Xout(1:ncols,:,8),Xout(1:ncols,:,10),rh4,b4
n=n+1
end subroutine
end program test
