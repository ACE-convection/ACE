module ace_module
implicit none

private
public :: ace_t
public :: weno, weno_vec, inv_theta_e, pchip, theta_e, ace_driver, ace_initialization, eval_qs

! model setup by ace_t
type ace_t
  ! model setup
  integer :: n_prog,n_weno,ncols,nz,nzm
  real, dimension(:), allocatable :: radius, A, B
  real, dimension(:,:), allocatable :: Ref
  real, dimension(:,:,:), allocatable :: X, forcing
  character(300) :: case_name
  character(300) :: PMB_PMD_file
  logical :: nc_init
  logical :: single_ace,do_microphy,do_ImDiff,do_ImDamp
  logical :: do_DHv,do_DHh
  real :: dt
  real :: t_now

  ! parameters for ImPamp
  real :: nju,SLD,SLTau

  ! array for ImDiff
  real, dimension(:,:), allocatable :: eddiffu 
  integer, dimension(:,:), allocatable :: eddiwin
  
  ! constants for simple micrphysics scheme
  real qc_ramp,dqc,tau_pr
    
  ! options for P3 microphysics scheme
  integer :: ncat
  logical :: log_predictNc,trplMomI,liqfrac

 ! arrays for PMB and PMD
  integer :: coarse_nz
  real, dimension(:), allocatable :: coarse_z, coarse_ze
  real, dimension(:,:), allocatable :: coarse_F, coarse_DHh
  real, dimension(:,:), allocatable :: dwdt
  real, dimension(:,:,:,:), allocatable :: PMB, PMD

  ! array for calculating buoyancy and RH
  real, dimension(:,:), allocatable :: Ta, q, ql, qi
  real, dimension(:,:), allocatable :: the, th, qt
  real, dimension(:,:), allocatable :: buoc, rh

  ! array for env.
  real, dimension(:), allocatable :: Tv0, T0, q0, ql0, qi0

  contains
    procedure :: initialize=>ace_initialization
    procedure :: integrate=>ace_driver
    procedure :: diagnose=>ace_diagnostic
    procedure :: output=>ace_output_nc 
end type ace_t


! constants
real, parameter :: pi = 4.*atan(1.)
real, parameter :: g = 9.80665 ! gravity constant 
real, parameter :: eps = 222.044604925031e-018 ! a small real number

contains

subroutine ace_driver(self,te)
implicit none

class(ace_t), intent(inout) :: self

! input variables
real, intent(in) :: te ! integrate ACE to te

! local variables
real, dimension(self%ncols,self%nz,self%n_prog) :: K1,K2,tmp
real, dimension(self%ncols+1,self%nz,self%n_prog) :: yi
real :: dum1
integer(4) :: start, finish
integer :: i,k

yi = self%X

do while ( self%t_now < te)
  !write(*,*) self%t_now, te
  call system_clock(count=start)
  ! update ace tendency
  call ace_tendency(self,self%X,K1,1)
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + K1 * self%dt / 6.

  call ace_tendency(self,yi,K2,2)
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 + K2 ) * self%dt / 6.

  call ace_tendency(self,yi,tmp,3)
  K2 = K2 + tmp
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 + K2 ) * self%dt / 6.

  call ace_tendency(self,yi,tmp,4)
  K2 = K2 + tmp
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 + K2 ) * self%dt / 6.

  call ace_tendency(self,yi,tmp,5)
  K2 = K2 + tmp
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 + K2 ) * self%dt / 6.

  call ace_tendency(self,yi,tmp,6)
  K2 = ( K2 + tmp ) / 15.
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 / 6. + K2 ) * self%dt 

  call ace_tendency(self,yi,tmp,7)
  K1 = K1 + tmp 
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 / 6. + K2 ) * self%dt 

  call ace_tendency(self,yi,tmp,8)
  K1 = K1 + tmp 
  yi(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 / 6. + K2 ) * self%dt 

  call ace_tendency(self,yi,tmp,9)
  K1 = K1 + tmp

  yi = self%X
  self%X(1:self%ncols,:,:) = self%X(1:self%ncols,:,:) + ( K1 / 6. + K2 ) * self%dt
  call system_clock(count=finish)
  !write(*,*) "dynamic", real(finish-start)/10000.  

  ! call physics here
  call system_clock(count=start)
  if (self%do_microphy) then
    if (self%n_prog==3) then
      call precip_sinks(self,K1(:,:,1:2)) ! simplified precipitation
      self%X(1:self%ncols,:,2:self%n_prog) = self%X(1:self%ncols,:,2:self%n_prog) +  K1(:,:,1:2) * self%dt
      
      ! NaN check
      do k=1,self%nz
      do i=1,self%ncols
        if (self%X(i,k,1)/=self%X(i,k,1)) then
          write(*,*) "NaN is found at col=", i,", level=",k
          stop
        endif
      enddo
      enddo

    elseif (self%n_prog==11) then
      call p3_wrapper_ace(self,yi)
    else
      write(*,*) "No suitable microphysics scheme"
      stop
    endif
  endif 
  call system_clock(count=finish)
  !write(*,*) "micro", real(finish-start)/10000.  


  ! implicit diffusion of mass flux and racers
  call system_clock(count=start)
  if (self%do_ImDiff) call ImDiff(self)
  call system_clock(count=finish)
  !write(*,*) "ImDiff", real(finish-start)/10000.  

  ! implicit damping 
  call system_clock(count=start)
  if (self%do_ImDamp) call ImDamp(self)
  call system_clock(count=finish)
  !write(*,*) "ImDamp", real(finish-start)/10000.  


  self%t_now = self%t_now + self%dt
  write(*,*) self%t_now
enddo


endsubroutine ace_driver


subroutine ace_initialization(self,fname)
use netcdf
implicit none

! ace type
class(ace_t), intent(inout) :: self

! input variable
character(*), intent(in) :: fname

! local variables
integer :: i,j,k,n, ii,kk
integer :: ierr,ncid1,varid1,dimid1

integer :: n_prog=3,n_weno=2,ncols=8,nz=801
character(300) :: PMB_PMD_file="./input_data/precomputed_mf_basis.nc"
character(300) :: case_name="ACE_default_simulation"
logical :: nc_init=.False.
logical :: single_ace=.True.,do_microphy=.True.,do_ImDiff=.True.,do_ImDamp=.False.
logical :: do_DHv=.True.,do_DHh=.True.
real :: t_now = 0.
real :: dt = 4.
real :: nju = 0.09 ! Morrison (2017)
namelist /config/ PMB_PMD_file,nc_init,case_name &
                 ,n_prog,n_weno,ncols,nz &
                 ,single_ace,do_microphy,do_ImDiff,do_ImDamp &
                 ,do_DHv,do_DHh &
                 ,t_now,dt,nju

! parameters for ImDamp
! Sponge layer with Newtonian damping at domain top ztop
real :: SLD = 6e3  ! e-folding depth in m
real :: SLTau = 180 ! SL relaxation timescale in s
namelist /sponge/ SLD,SLTau

! coefficients for precipitation sinks (simple microphysics scheme)
real :: qc_ramp = 0.5e-3 ! kg/kg; ramping for precip when qc>qc_ramp
real :: dqc = 20 ! kg/kg; transition for a smooth onset of precip ramp function
real :: tau_pr = 5*60 ! sec; relaxation timescale for precip
namelist /microphy_simple_scheme/ qc_ramp,dqc,tau_pr

! options for P3 microphysics scheme
integer :: ncat = 1 
logical :: log_predictNc = .True.
logical :: trplMomI = .False.
logical :: liqfrac = .False.
namelist /microphy_p3_scheme/ ncat,log_predictNc,trplMomI,liqfrac


! open and read the namelist
open(10,file=trim(fname),form="formatted")

! ACE configuration
read(10,config)
self%PMB_PMD_file=PMB_PMD_file
self%case_name=case_name
self%nc_init=nc_init
self%n_prog=n_prog
self%n_weno=n_weno
self%ncols=ncols
self%nz=nz
self%nzm=nz
self%single_ace=single_ace
self%do_microphy=do_microphy
self%do_ImDiff=do_ImDiff
self%do_ImDamp=do_ImDamp
self%do_DHv=do_DHv
self%do_DHh=do_DHh
self%t_now=t_now
self%dt=dt
self%nju=nju

! read constant for ImDamp
if (self%do_ImDamp) then
  read(10,sponge)
  self%SLD=SLD
  self%SLTau=SLTau 
endif 

! read options and constants for microphysics scheme
if (self%do_microphy) then
  if (self%n_prog==3) then ! simple microphysics
    read(10,microphy_simple_scheme)
    self%qc_ramp=qc_ramp
    self%dqc=dqc
    self%tau_pr=tau_pr
  elseif (self%n_prog==11) then ! P3 microphysics
    read(10,microphy_p3_scheme)
    self%ncat=ncat
    self%log_predictNc=log_predictNc
    self%trplMomI=trplMomI
    self%liqfrac=liqfrac
  endif
endif

close(10)

! allocate array according to namelist
allocate(self%X(self%ncols+1,self%nz,self%n_prog),&
         self%forcing(self%ncols+1,self%nz,self%n_prog),&
         self%Ref(self%nz,8),&
         self%Ta(self%ncols,self%nz),&
         self%q(self%ncols,self%nz),&
         self%ql(self%ncols,self%nz),&
         self%qi(self%ncols,self%nz),&
         self%the(self%ncols,self%nz),&
         self%th(self%ncols,self%nz),&
         self%qt(self%ncols,self%nz),&
         self%rh(self%ncols,self%nz),&
         self%buoc(self%ncols,self%nz),&
         self%Tv0(self%nz),&
         self%T0(self%nz),&
         self%q0(self%nz),&
         self%ql0(self%nz),&
         self%qi0(self%nz),&
         self%eddiffu(self%ncols,self%nz),&
         self%eddiwin(self%ncols,self%nz) )


! read initial condition from nc file if nc_init is false.
if (nc_init) then
  ierr=nf90_open("./input_data/"//trim(self%case_name)//"_IC.nc",nf90_nowrite,ncid1)
  if (ierr/=nf90_noerr) stop "can't open IC nc file"
  
  ierr=nf90_inq_dimid(ncid1,'ncols',dimid1)
  if (ierr/=nf90_noerr) stop "can't inq ncols"
  ierr=nf90_inquire_dimension(ncid1,dimid1,len=n)
  if (ierr/=nf90_noerr) stop "can't read ncols"

  if (n/=self%ncols) stop "ncols are inconsistent in IC file and namelist"

  ierr=nf90_inq_dimid(ncid1,'nzc',dimid1)
  if (ierr/=nf90_noerr) stop "can't inq nzc"
  ierr=nf90_inquire_dimension(ncid1,dimid1,len=n)
  if (ierr/=nf90_noerr) stop "can't read nzc"

  if (n/=self%nz) stop "nz are inconsistent in IC file and namelist"
 
  ierr=nf90_inq_dimid(ncid1,'n_prog',dimid1)
  if (ierr/=nf90_noerr) stop "can't inq n_prog"
  ierr=nf90_inquire_dimension(ncid1,dimid1,len=n)
  if (ierr/=nf90_noerr) stop "can't read n_prog"

  if (n/=self%n_prog) stop "n_prog are inconsistent in IC file and namelist"

  ! read the reference varaibles
  ierr=nf90_inq_varid(ncid1,"rho_c",varid1)
  if (ierr/=nf90_noerr) stop "can't inq rho_c"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,1))
  if (ierr/=nf90_noerr) stop "can't read rho_c"

  ierr=nf90_inq_varid(ncid1,"rho_i",varid1)
  if (ierr/=nf90_noerr) stop "can't inq rho_i"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,2))
  if (ierr/=nf90_noerr) stop "can't read rho_i"

  ierr=nf90_inq_varid(ncid1,"zc",varid1)
  if (ierr/=nf90_noerr) stop "can't inq zc"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,3))
  if (ierr/=nf90_noerr) stop "can't read zc"

  ierr=nf90_inq_varid(ncid1,"zi",varid1)
  if (ierr/=nf90_noerr) stop "can't inq zi"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,4))
  if (ierr/=nf90_noerr) stop "can't read zi"

  ierr=nf90_inq_varid(ncid1,"dzc",varid1)
  if (ierr/=nf90_noerr) stop "can't inq dzc"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,5))
  if (ierr/=nf90_noerr) stop "can't read dzc"

  ierr=nf90_inq_varid(ncid1,"dzi",varid1)
  if (ierr/=nf90_noerr) stop "can't inq dzi"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,6))
  if (ierr/=nf90_noerr) stop "can't read dzi"

  ierr=nf90_inq_varid(ncid1,"p_c",varid1)
  if (ierr/=nf90_noerr) stop "can't inq p_c"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,7))
  if (ierr/=nf90_noerr) stop "can't read p_c"

  ierr=nf90_inq_varid(ncid1,"pi_c",varid1)
  if (ierr/=nf90_noerr) stop "can't inq pi_c"
  ierr=nf90_get_var(ncid1,varid1,self%Ref(:,8))
  if (ierr/=nf90_noerr) stop "can't read pi_c"
 
  ! read IC
  ierr=nf90_inq_varid(ncid1,"X",varid1)
  if (ierr/=nf90_noerr) stop "can't inq X"
  ierr=nf90_get_var(ncid1,varid1,self%X)
  if (ierr/=nf90_noerr) stop "can't read X"

  ierr=nf90_close(ncid1)
  if (ierr/=nf90_noerr) stop "can't close IC file"
  
  write(*,*) "Successfully reading IC from file: ./input_data/"//trim(self%case_name)//"_IC.nc" 
else
  write(*,*) "Setup initial condition before calling integrate()" 
endif

! read precomputed massflux basis
ierr=nf90_open(trim(self%PMB_PMD_file),nf90_nowrite,ncid1)
if (ierr/=nf90_noerr) stop "can't open PMB&PMD file"

ierr=nf90_inq_dimid(ncid1,'nzc',dimid1)
if (ierr/=nf90_noerr) stop "can't inq nzc"
ierr=nf90_inquire_dimension(ncid1,dimid1,len=self%coarse_nz)
if (ierr/=nf90_noerr) stop "can't read nzc"
ierr=nf90_inq_dimid(ncid1,'ncols-response',dimid1)
if (ierr/=nf90_noerr) stop "can't inq ncols"
ierr=nf90_inquire_dimension(ncid1,dimid1,len=n)
if (ierr/=nf90_noerr) stop "can't read ncols"

if (n/=self%ncols) stop "ncols are inconsistent in PMB&PMD file and namelist"

! allocate arrays according to PMB&PMD file
allocate(self%radius(self%ncols+1),&
         self%A(self%ncols+1),&
         self%B(self%ncols+1),&
         self%coarse_z(self%coarse_nz),&
         self%coarse_ze(self%coarse_nz+1),&
         self%coarse_F(self%ncols,self%coarse_nz),&
         self%coarse_DHh(self%ncols,self%coarse_nz),&
         self%PMB(self%ncols,self%ncols,self%coarse_nz,self%coarse_nz+1),&
         self%PMD(self%ncols,self%ncols,self%coarse_nz,self%coarse_nz+1),&
         self%dwdt(self%ncols,self%coarse_nz+1) )

ierr=nf90_inq_varid(ncid1,"R",varid1)
if (ierr/=nf90_noerr) stop "can't inq R"
ierr=nf90_get_var(ncid1,varid1,self%radius(1:self%ncols))
if (ierr/=nf90_noerr) stop "can't read R"

self%radius(self%ncols+1)=self%radius(self%ncols)

ierr=nf90_inq_varid(ncid1,"A",varid1)
if (ierr/=nf90_noerr) stop "can't inq A"
ierr=nf90_get_var(ncid1,varid1,self%A(1:self%ncols))
if (ierr/=nf90_noerr) stop "can't read A"

self%A(self%ncols+1)=self%A(self%ncols)

ierr=nf90_inq_varid(ncid1,"B",varid1)
if (ierr/=nf90_noerr) stop "can't inq B"
ierr=nf90_get_var(ncid1,varid1,self%B(1:self%ncols))
if (ierr/=nf90_noerr) stop "can't read B"

self%B(self%ncols+1)=self%B(self%ncols)

ierr=nf90_inq_varid(ncid1,"PMB",varid1)
if (ierr/=nf90_noerr) stop "can't inq PMB"
ierr=nf90_get_var(ncid1,varid1,self%PMB)
if (ierr/=nf90_noerr) stop "can't read PMB"

if (self%do_DHh) then
  ierr=nf90_inq_varid(ncid1,"PMD",varid1)
  if (ierr/=nf90_noerr) stop "can't inq PMD"
  ierr=nf90_get_var(ncid1,varid1,self%PMD)
  if (ierr/=nf90_noerr) stop "can't read PMD"
endif

ierr=nf90_inq_varid(ncid1,"Zc",varid1)
if (ierr/=nf90_noerr) stop "can't inq Zc"
ierr=nf90_get_var(ncid1,varid1,self%coarse_z)
if (ierr/=nf90_noerr) stop "can't read Zc"

ierr=nf90_inq_varid(ncid1,"Zi",varid1)
if (ierr/=nf90_noerr) stop "can't inq Zi"
ierr=nf90_get_var(ncid1,varid1,self%coarse_ze)
if (ierr/=nf90_noerr) stop "can't read Zi"

ierr=nf90_close(ncid1)
if (ierr/=nf90_noerr) stop "can't close PMB file"

end subroutine ace_initialization


subroutine ace_diagnostic(self)
implicit none

class(ace_t) :: self

! local variables
real :: dum1
integer :: i,k,ice

do k=1,self%nz
  ! calculate env. Tv
  if (self%n_prog==3) then
    call inv_theta_e(self%X(self%ncols+1,k,2),self%X(self%ncols+1,k,3),self%Ref(k,7),self%T0(k),self%q0(k),self%ql0(k),self%qi0(k))
  elseif (self%n_prog==11) then
    self%T0(k)=self%X(self%ncols+1,k,2)*self%Ref(k,8)
    self%q0(k) =self%X(self%ncols+1,k,3)
    self%ql0(k)=self%X(self%ncols+1,k,4)+self%X(self%ncols+1,k,6)
    self%qi0(k)=self%X(self%ncols+1,k,8)
  endif
  self%Tv0(k) = self%T0(k) * ( 1. + 0.607789855072462 * self%q0(k) - self%ql0(k) - self%qi0(k) )

  do i=1,self%ncols
    if (self%n_prog==3) then
      self%the(i,k)=self%X(i,k,2)
      self%qt(i,k)=self%X(i,k,3)
      call inv_theta_e(self%X(i,k,2),self%X(i,k,3),self%Ref(k,7),self%Ta(i,k),self%q(i,k),self%ql(i,k),self%qi(i,k))
      self%th(i,k)=self%Ta(i,k)/self%Ref(k,8)
    elseif (self%n_prog==11) then
      self%th(i,k)=self%X(i,k,2)
      self%Ta(i,k)=self%X(i,k,2)*self%Ref(k,8)
      self%q(i,k) =self%X(i,k,3)
      self%ql(i,k)=self%X(i,k,4)+self%X(i,k,6)
      self%qi(i,k)=self%X(i,k,8)
      self%qt(i,k)=self%q(i,k)+self%ql(i,k)+self%qi(i,k)
      self%the(i,k)=theta_e(self%Ta(i,k),self%q(i,k),self%ql(i,k),self%qi(i,k),self%Ref(k,7)) 
    endif
    ice=0
    if (self%Ta(i,k)<273.15) ice=1
    self%rh(i,k)=self%q(i,k)/eval_qs(self%Ta(i,k),self%Ref(k,7),self%ql(i,k)+self%qi(i,k),ice) *100.
    dum1=self%Ta(i,k)*(1.+0.607789855072462*self%q(i,k)-self%ql(i,k)-self%qi(i,k))
    self%buoc(i,k)=g*(dum1-self%Tv0(k))/self%Tv0(k)
  enddo
enddo

end subroutine ace_diagnostic


subroutine ace_output_nc(self)
use netcdf
implicit none

class(ace_t) :: self

! local variables
integer :: ierr,ncid1,varid1,dimid1,dimid2,dimid3
integer :: step
integer :: access,system
real, dimension(:), allocatable :: time
real, dimension(:,:), allocatable :: Xout
character(300) :: fname
logical :: first=.True.

if (first) then
  fname="./output"
  ierr=access(trim(fname),' ')
  if (ierr/=0) then
    ierr=system("mkdir "//trim(fname))
    if (ierr==0) then
      write(*,*) "create folder ./output"
    else 
      write(*,*) "cannot create folder ./output"
    endif
  endif
  
  fname="./output/"//trim(self%case_name)//"_output.nc"

  ierr=access(trim(fname),' ')
  if (ierr==0) write(*,*) "A new run but nc file exists. Model will override the nc file."
   
  ierr=nf90_create(trim(fname),nf90_netcdf4,ncid1)
  if (ierr/=nf90_noerr) stop "cannot create ncfile"

  ierr=nf90_def_dim(ncid1, "ncols",     self%ncols, dimid1)
  if (ierr/=nf90_noerr) stop "cannot define ncols"
  ierr=nf90_def_dim(ncid1,    "zc",        self%nz, dimid2)
  if (ierr/=nf90_noerr) stop "cannot define zc"
  ierr=nf90_def_dim(ncid1,  "time", nf90_unlimited, dimid3)
  if (ierr/=nf90_noerr) stop "cannot define time"

  ierr=nf90_def_var(ncid1, "radius", nf90_double, (/dimid1/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define radius"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Radius of ACE columns')
  if (ierr/=nf90_noerr) stop "cannot define radius longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'm')
  if (ierr/=nf90_noerr) stop "cannot define radius units"

  ierr=nf90_def_var(ncid1, "height", nf90_double, (/dimid2/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define height"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Height')
  if (ierr/=nf90_noerr) stop "cannot define height longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'm')
  if (ierr/=nf90_noerr) stop "cannot define height units"

  ierr=nf90_def_var(ncid1, "time", nf90_double, (/dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define time"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'time of simulation')
  if (ierr/=nf90_noerr) stop "cannot define time longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 's')
  if (ierr/=nf90_noerr) stop "cannot define time units"

  ierr=nf90_def_var(ncid1, "mf", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define mf"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Vertical mass flux')
  if (ierr/=nf90_noerr) stop "cannot define mf longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'kg m^2 s^-1')
  if (ierr/=nf90_noerr) stop "cannot define mf units"

  ierr=nf90_def_var(ncid1, "the", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define the"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Equivalent potential temperature')
  if (ierr/=nf90_noerr) stop "cannot define the longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'K')
  if (ierr/=nf90_noerr) stop "cannot define the units"

  ierr=nf90_def_var(ncid1, "th", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define th"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Potential temperature')
  if (ierr/=nf90_noerr) stop "cannot define th longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'K')
  if (ierr/=nf90_noerr) stop "cannot define th units"

  ierr=nf90_def_var(ncid1, "qt", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define qt"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Mixing ratio of total water')
  if (ierr/=nf90_noerr) stop "cannot define qt longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'kg kg^-1')
  if (ierr/=nf90_noerr) stop "cannot define qt units"

  ierr=nf90_def_var(ncid1, "qv", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define qv"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Mixing ratio of water vapor')
  if (ierr/=nf90_noerr) stop "cannot define qv longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'kg kg^-1')
  if (ierr/=nf90_noerr) stop "cannot define qv units"

  ierr=nf90_def_var(ncid1, "ql", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define ql"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Mixing ratio of liquid water')
  if (ierr/=nf90_noerr) stop "cannot define ql longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'kg kg^-1')
  if (ierr/=nf90_noerr) stop "cannot define ql units"

  ierr=nf90_def_var(ncid1, "qi", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define qi"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Mixing ratio of ice')
  if (ierr/=nf90_noerr) stop "cannot define qi longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'kg kg^-1')
  if (ierr/=nf90_noerr) stop "cannot define qi units"

  ierr=nf90_def_var(ncid1, "rh", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define rh"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Relatvie humidity')
  if (ierr/=nf90_noerr) stop "cannot define rh longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', '%')
  if (ierr/=nf90_noerr) stop "cannot define rh units"

  ierr=nf90_def_var(ncid1, "B", nf90_double, (/dimid1,dimid2,dimid3/), varid1)
  if (ierr/=nf90_noerr) stop "cannot define B"
  ierr=nf90_put_att(ncid1, varid1, 'long_name', 'Buoyancy')
  if (ierr/=nf90_noerr) stop "cannot define B longname"
  ierr=nf90_put_att(ncid1, varid1, 'units', 'm s^-2')
  if (ierr/=nf90_noerr) stop "cannot define B units"

  ierr=nf90_enddef(ncid1)
  if (ierr/=nf90_noerr) stop "cannot leave define mode"

  ! output coordinates
  ierr=nf90_inq_varid(ncid1,"radius",varid1)
  if (ierr/=nf90_noerr) stop "cannot inq radius"
  ierr=nf90_put_var(ncid1,varid1,self%radius(1:self%ncols))
  if (ierr/=nf90_noerr) stop "cannot output radius"

  ierr=nf90_inq_varid(ncid1,"height",varid1)
  if (ierr/=nf90_noerr) stop "cannot inq height"
  ierr=nf90_put_var(ncid1,varid1,self%Ref(1:self%nz,3))
  if (ierr/=nf90_noerr) stop "cannot output height"

  ierr=nf90_close(ncid1)
  if (ierr/=nf90_noerr) stop "cannot close nc file"
  
  write(*,*) "ACE results will be outputed to a new file:"//trim(fname)
 
  first=.False.
endif

fname="./output/"//trim(self%case_name)//"_output.nc"
ierr=access(trim(fname),' ')
if (ierr/=0) stop "file does not exist. Please check!!!"

ierr=nf90_open(trim(fname),nf90_write,ncid1)
if (ierr/=nf90_noerr) stop "cannot open nc file"

! inquire step
ierr=nf90_inq_dimid(ncid1,'time',dimid1)
if (ierr/=nf90_noerr) stop "can't inq time step"
ierr=nf90_inquire_dimension(ncid1,dimid1,len=step)
if (ierr/=nf90_noerr) stop "can't read time step"

! output at step+1
ierr=nf90_inq_varid(ncid1,"time",varid1)
if (ierr/=nf90_noerr) stop "cannot inq time"
ierr=nf90_put_var(ncid1,varid1,self%t_now,start=(/step+1/))
if (ierr/=nf90_noerr) stop "cannot output time"

ierr=nf90_inq_varid(ncid1,"mf",varid1)
if (ierr/=nf90_noerr) stop "cannot inq the"
ierr=nf90_put_var(ncid1,varid1,self%X(1:self%ncols,1:self%nz,1),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output the"

ierr=nf90_inq_varid(ncid1,"the",varid1)
if (ierr/=nf90_noerr) stop "cannot inq the"
ierr=nf90_put_var(ncid1,varid1,self%the(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output the"

ierr=nf90_inq_varid(ncid1,"th",varid1)
if (ierr/=nf90_noerr) stop "cannot inq th"
ierr=nf90_put_var(ncid1,varid1,self%th(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output th"

ierr=nf90_inq_varid(ncid1,"qt",varid1)
if (ierr/=nf90_noerr) stop "cannot inq qt"
ierr=nf90_put_var(ncid1,varid1,self%qt(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output qt"

ierr=nf90_inq_varid(ncid1,"qv",varid1)
if (ierr/=nf90_noerr) stop "cannot inq qv"
ierr=nf90_put_var(ncid1,varid1,self%q(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output qv"

ierr=nf90_inq_varid(ncid1,"ql",varid1)
if (ierr/=nf90_noerr) stop "cannot inq ql"
ierr=nf90_put_var(ncid1,varid1,self%ql(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output ql"

ierr=nf90_inq_varid(ncid1,"qi",varid1)
if (ierr/=nf90_noerr) stop "cannot inq qi"
ierr=nf90_put_var(ncid1,varid1,self%qi(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output qi"

ierr=nf90_inq_varid(ncid1,"rh",varid1)
if (ierr/=nf90_noerr) stop "cannot inq rh"
ierr=nf90_put_var(ncid1,varid1,self%rh(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output trh"

ierr=nf90_inq_varid(ncid1,"B",varid1)
if (ierr/=nf90_noerr) stop "cannot inq B"
ierr=nf90_put_var(ncid1,varid1,self%buoc(1:self%ncols,1:self%nz),start=(/1,1,step+1/))
if (ierr/=nf90_noerr) stop "cannot output B"

ierr=nf90_close(ncid1)
if (ierr/=nf90_noerr) stop "cannot close nc file"

write(*,'(A,F14.1,A,A)') "ACE results at t=",self%t_now," are outputed to "//trim(fname)

end subroutine ace_output_nc


subroutine ace_tendency(ace,X,dXdt,rkstage)
use omp_lib
implicit none

! input/output variables
type(ace_t), intent(inout) :: ace
integer, intent(in) :: rkstage
real, dimension(ace%ncols+1,ace%nz,ace%n_prog), intent(in) :: X
real, dimension(ace%ncols,ace%nz,ace%n_prog), intent(out) :: dXdt 

! local variables
integer :: i,n,k,ks,ke
real :: dum1,dum2
integer(4) :: start,finish
real, dimension(ace%ncols,ace%nz,2) :: eps_tur
real, dimension(ace%nz) :: rho0B, Tv
real, dimension(ace%ncols,ace%nz,3) :: dXdz
real, dimension(ace%ncols,ace%nz,2:ace%n_prog) :: Ci, rho0wC
real, dimension(ace%ncols+1,ace%nz) :: mfc, Wc
real, dimension(ace%ncols,ace%nz) ::Wi, Admfdz, ioflow, F, FH, FHi, DHh


! initialization
call system_clock(count=start)
do k=1,ace%nz
  eps_tur(:          ,k,1) = ace%nju*ace%B/ace%A
  eps_tur(2:ace%ncols,k,2) = ace%nju*ace%B(1:ace%ncols-1)/ace%A(2:ace%ncols)
  if (ace%n_prog==3) then
    call inv_theta_e(ace%X(ace%ncols+1,k,2),ace%X(ace%ncols+1,k,3),ace%Ref(k,7),ace%T0(k),ace%q0(k),ace%ql0(k),ace%qi0(k))
  elseif (ace%n_prog==11) then
    ace%T0(k)=ace%X(ace%ncols+1,k,2)*ace%Ref(k,8)
    ace%q0(k) =ace%X(ace%ncols+1,k,3)
    ace%ql0(k)=ace%X(ace%ncols+1,k,4)+ace%X(ace%ncols+1,k,6)
    ace%qi0(k)=ace%X(ace%ncols+1,k,8)
  endif
  ace%Tv0(k) = ace%T0(k) * ( 1. + 0.607789855072462 * ace%q0(k) - ace%ql0(k) - ace%qi0(k) )
enddo

! fill with zeros
dXdt = 0.
mfc = 0.
Wc = 0.
F = 0.
FH = 0.
FHi = 0.
DHh = 0.

call system_clock(count=finish)
!write(*,*) "initial", real(finish-start)/10000.  

! Compute tracer values Ci(zi) at interface points from C(zc=zi+dz/2)
call system_clock(count=start)
do i=1,ace%ncols
  do n=2,ace%n_prog
    call weno_vec(ace%n_weno,ace%nz,X(i,:,n),X(i,:,1),rho0wC(i,:,n))
    rho0wC(i,:,n) = X(i,:,1) * rho0wC(i,:,n)
    rho0wC(i,1,n) = 0. ! set surface fluxes to zero
  enddo

  ! Vertical velocity w(zi) (mass flux already at zi)
  Wi(i,:) = X(i,:,1) / ace%Ref(:,2)

  ! Vertical mass flux & velocity at zc=zi+dz/2
  call weno_up3(ace%nz,X(i,:,1),mfc(i,:))
  Wc(i,:) = mfc(i,:) / ace%Ref(:,1)

  ! Admfdz = (ACE area)*dmfdz for dynamic inflow/outflow at zc=zi+dz/2
  Admfdz(i,ace%nz) = 0.
  Admfdz(i,1:ace%nz-1) = ace%A(i) * ( X(i,2:ace%nz,1) - X(i,1:ace%nz-1,1) ) / ace%Ref(2:ace%nz,6)

  ! ioflow = -Bi*rho_0*u_n (minus h. mass flux * lateral boundary length)
  ioflow(i,:) = sum(Admfdz(1:i,:),1)
enddo
call system_clock(count=finish)
!write(*,*) "inflow", real(finish-start)/10000.  

!call omp_set_dynamic(.false.)
!call omp_set_num_threads(ace%ncols/4)
!!!!$omp parallel do private(i)
call system_clock(count=start)
do i=1,ace%ncols
  do n=2,ace%n_prog
    dXdt(i,1:ace%nz-1,n) = - ( rho0wC(i,2:ace%nz,n) - rho0wC(i,1:ace%nz-1,n) ) / ace%Ref(1:ace%nz-1,5) / ace%Ref(1:ace%nz-1,1)  ! vertical flux convergence

    dXdt(i,1:ace%nz-1,n) = dXdt(i,1:ace%nz-1,n) - eps_tur(i,1:ace%nz-1,1) * ( X(i,1:ace%nz-1,n) - X(i+1,1:ace%nz-1,n) )  ! interact outer
    if (i>1) &
    dXdt(i,1:ace%nz-1,n) = dXdt(i,1:ace%nz-1,n) - eps_tur(i,1:ace%nz-1,2) * ( X(i,1:ace%nz-1,n) - X(i-1,1:ace%nz-1,n) )  ! interact inner

    dXdt(i,1:ace%nz-1,n) = dXdt(i,1:ace%nz-1,n) + 0.5 * &
                       ( ( ioflow(i  ,1:ace%nz-1) + abs(ioflow(i  ,1:ace%nz-1)) ) * X(i+1,1:ace%nz-1,n) &
                       + ( ioflow(i  ,1:ace%nz-1) - abs(ioflow(i  ,1:ace%nz-1)) ) * X(i  ,1:ace%nz-1,n) ) &
                        / ace%A(i) / ace%Ref(1:ace%nz-1,1)  ! inflow from outer
    if (i>1) &
    dXdt(i,1:ace%nz-1,n) = dXdt(i,1:ace%nz-1,n) - 0.5 * &
                       ( ( ioflow(i-1,1:ace%nz-1) + abs(ioflow(i-1,1:ace%nz-1)) ) * X(i  ,1:ace%nz-1,n) &
                       + ( ioflow(i-1,1:ace%nz-1) - abs(ioflow(i-1,1:ace%nz-1)) ) * X(i-1,1:ace%nz-1,n) ) &
                        / ace%A(i) / ace%Ref(1:ace%nz-1,1)  ! inflow from inner
  enddo

  FH(i,1:ace%nz-1) = - eps_tur(i,1,1) * ( mfc(i,1:ace%nz-1) - mfc(i+1,1:ace%nz-1) )  ! interact outer
  if (i>1) &
  FH(i,1:ace%nz-1) = FH(i,1:ace%nz-1) - eps_tur(i,1,2) * ( mfc(i,1:ace%nz-1) - mfc(i-1,1:ace%nz-1) )  ! interact inner
  FH(i,1:ace%nz-1) = FH(i,1:ace%nz-1) + 0.5 * &
                     ( ( ioflow(i  ,1:ace%nz-1) + abs(ioflow(i  ,1:ace%nz-1)) ) * Wc(i+1,1:ace%nz-1) &
                     + ( ioflow(i  ,1:ace%nz-1) - abs(ioflow(i  ,1:ace%nz-1)) ) * Wc(i  ,1:ace%nz-1) ) / ace%A(i)  ! inflow from outer
  if (i>1) &
  FH(i,1:ace%nz-1) = FH(i,1:ace%nz-1) - 0.5 * &
                     ( ( ioflow(i-1,1:ace%nz-1) + abs(ioflow(i-1,1:ace%nz-1)) ) * Wc(i  ,1:ace%nz-1) &
                     + ( ioflow(i-1,1:ace%nz-1) - abs(ioflow(i-1,1:ace%nz-1)) ) * Wc(i-1,1:ace%nz-1) ) / ace%A(i)  ! inflow from inner

  F(i,1:ace%nz-1) =  FH(i,1:ace%nz-1) - ( X(i,2:ace%nz,1) * Wi(i,2:ace%nz) &
                                        - X(i,1:ace%nz-1,1) * Wi(i,1:ace%nz-1) ) / ace%Ref(1:ace%nz-1,5)  ! vertical flux convergence

  if (ace%do_DHv) then 
    F(i,1:ace%nz-1) = F(i,1:ace%nz-1) + FH(i,1:ace%nz-1)
    FHi(i,2:ace%nz-1) = 0.5 * ( FH(i,1:ace%nz-2) + FH(i,2:ace%nz-1) )
  endif

  if (ace%do_DHh) then
    if (i==1) then
      DHh(i,:) = ioflow(i,:) ** 2.
    else 
      DHh(i,:) = ioflow(i,:) ** 2. - ioflow(i-1,:) ** 2. 
    endif
    DHh(i,:) = DHh(i,:) / ace%Ref(:,1) / ace%A(i)
  endif

  if (rkstage==1) then
    do k=1,ace%nz
      if (ace%n_prog==3) then
        call inv_theta_e(X(i,k,2),X(i,k,3),ace%Ref(k,7),ace%Ta(i,k),ace%q(i,k),ace%ql(i,k),ace%qi(i,k))
      elseif (ace%n_prog==11) then
        ace%Ta(i,:) = X(i,:,2) * ace%Ref(:,8)
        ace%q(i,:)  = X(i,:,3)
        ace%ql(i,:) = X(i,:,4) + X(i,:,6)
        ace%qi(i,:) = X(i,:,8)
      endif
    enddo 
  endif

  Tv(1:ace%nz) = ace%Ta(i,1:ace%nz) * ( 1. + 0.607789855072462 * ace%q(i,1:ace%nz) - ace%ql(i,1:ace%nz) - ace%qi(i,1:ace%nz) )
  rho0B(1:ace%nz) = g * ace%Ref(1:ace%nz,1) * ( Tv(1:ace%nz) - ace%Tv0(1:ace%nz) ) / ace%Tv0(1:ace%nz)

  F(i,1:ace%nz) = F(i,1:ace%nz) + rho0B(1:ace%nz)

  ace%coarse_F(i,:) = sum(reshape(F(i,1:ace%nz),(/2,ace%nz/2/)),1)/2.
  ace%coarse_DHh(i,:) = sum(reshape(DHh(i,1:ace%nz),(/2,ace%nz/2/)),1)/2.
enddo
call system_clock(count=finish)
!write(*,*) "advec", real(finish-start)/10000.  
!!!$omp end parallel do

call system_clock(count=start)
!$omp parallel do collapse(2) schedule(guided,20)
do i=1,ace%ncols
  do k=1,ace%coarse_nz+1
    if (ace%do_DHh) then
      ace%dwdt(i,k) = sum( sum( ace%PMB(i,:,:,k) * ace%coarse_F(:,:) &
                              + ace%PMD(i,:,:,k) * ace%coarse_DHh(:,:), 2 ), 1 )  
    else
      ace%dwdt(i,k) = sum( sum( ace%PMB(i,:,:,k) * ace%coarse_F(:,:), 2 ), 1 )
    endif
  enddo
enddo
!$omp end parallel do
call system_clock(count=finish)
write(*,*) "basis", real(finish-start)/10000.  

call system_clock(count=start)
do i=1,ace%ncols
  call pchip(ace%coarse_nz+1,ace%coarse_ze,ace%dwdt(i,1:ace%coarse_nz+1),ace%nz,ace%Ref(1:ace%nz,4),dXdt(i,1:ace%nz,1),.True.)
  dXdt(i,1:ace%nz,1) = dXdt(i,1:ace%nz,1) - Fhi(i,1:ace%nz)
enddo  
call system_clock(count=finish)
!write(*,*) "interp", real(finish-start)/10000.  

! single ACE
if (ace%single_ace) dXdt(2:ace%ncols,:,:)=0.

! model top 
dXdt(:,ace%nz-10:ace%nz,:)=0.


end subroutine ace_tendency

subroutine ImDiff(ace)
implicit none

! input/output variables
type(ace_t), intent(inout) :: ace

! local variable
logical, save :: first = .True.
integer :: i, k, ks, ke, info
real :: dum1
real, dimension(ace%ncols,ace%nz) :: wi, drho0wdz, mu_i, mu_c
real, dimension(ace%nz) :: tmp, mu
real, dimension(ace%nz,3) :: coeff

if (first) then
  do k=1,ace%nz
    ace%eddiffu(:,k) = 5.e3 / ( 4. * pi ) / ace%Ref(k,5)
    ace%eddiwin(:,k) = ceiling( 5.e3 / ( 2. * ace%Ref(k,5) ) ) 
  enddo
  first = .False.
endif

do k=1,ace%nz-1
  wi(:,k) = ace%X(1:ace%ncols,k,1) / ace%Ref(k,2)
  drho0wdz(:,k) = ( ace%X(1:ace%ncols,k+1,1) - ace%X(1:ace%ncols,k,1) ) / ace%Ref(k,5)
enddo
drho0wdz(:,ace%nz) = 0.

do k=1,ace%nz
  mu_i(:,k) = abs(drho0wdz(:,k)) * ( ace%eddiffu(:,k) * ( maxval(wi,2) - minval(wi,2) ) ) &
               / (maxval(abs(drho0wdz)+eps,2))
enddo

do k=1,ace%nz-1
  mu_c(:,k) = 0.5 * ( mu_i(:,k) + mu_i(:,k+1) )
enddo

do i=1,ace%ncols 

  ! moving max
  do k=1,ace%nz
    ks = max(k-ace%eddiwin(i,k),1)
    ke = min(k+ace%eddiwin(i,k),ace%nz)
    tmp(k) = maxval(mu_i(i,ks:ke),1)
  enddo
 
  ! convolution
  do k=1,ace%nz
    ks = max(k-ace%eddiwin(i,k),1)
    ke = min(k+ace%eddiwin(i,k),ace%nz)
    
    mu(k) = sum(tmp(ks:ke)*(1./(2.*ace%eddiwin(i,k)*ace%Ref(ks:ke,5)/ace%dt+1.)),1)
  enddo
 
  mu = mu * ace%dt / ace%Ref(:,5)
  ! solve tridiagonal system
  coeff = 0.
  do k=1,ace%nz-1
    coeff(k,1) = - mu(k)
    coeff(k,3) = - mu(k+1)
    coeff(k,2) = 1. -  coeff(k,1) - coeff(k,3)
  enddo
 
  tmp(:) = ace%X(i,:,1) 
  call dgtsv(ace%nz-1,1,coeff(2:ace%nz-1,1),coeff(1:ace%nz-1,2),coeff(1:ace%nz-2,3),tmp(2:ace%nz),ace%nz-1,info)
  if (info/=0) write(*,*) "ACE ImDiff: matrix cannot be solved", info

  ace%X(i,2:ace%nz,1) = tmp(2:ace%nz)
enddo

! MF at the model top and surface
ace%X(:,1,1) = 0.
ace%X(:,ace%nz-10:ace%nz,1) = 0.

end subroutine ImDiff

 
subroutine ImDamp(ace)
implicit none

! input/output variables
type(ace_t), intent(inout) :: ace 

! local variable
integer :: i,k,n
real, dimension(:), allocatable, save :: damp
logical, save :: first = .True.

if (first) then
  allocate(damp(ace%nz))
  do k=1,ace%nz
    damp(k) = ace%dt * exp( ( ace%Ref(k,3) - ace%Ref(ace%nz,3) ) / ace%SLD ) / ace%SLTau
  enddo
  first = .False.
endif

do k=1,ace%nz
  do i=1,ace%ncols
    ace%X(i,k,1) = ace%X(i,k,1) / ( 1. + damp(k) / ace%Ref(k,2) )
    do n=2,ace%n_prog
      ace%X(i,k,n) = ( ace%X(i,k,n) + damp(k) * ace%X(ace%ncols+1,k,n) / ace%Ref(k,1) ) / ( 1. + damp(k) / ace%Ref(k,1) )
    enddo
  enddo
enddo

end subroutine ImDamp

subroutine precip_sinks(ace,dXdt)
implicit none

! input/output variables
type(ace_t) :: ace
real, dimension(ace%ncols,ace%nz,ace%n_prog-1), intent(out) :: dXdt

! local variables
integer :: i,k
real :: qc, dql, dqi


do k=1,ace%nz
do i=1,ace%ncols
  qc = ace%ql(i,k) + ace%qi(i,k)
  dXdt(i,k,2) = - ( ace%qc_ramp / ace%dqc / ace%tau_pr ) * max( ace%dqc / ace%qc_ramp * ( qc - ace%qc_ramp ) , 0. ) 
  dql = 1.e-8 * ace%ql(i,k) / qc
  dqi = 1.e-8 * ace%qi(i,k) / qc
  dXdt(i,k,1) = dXdt(i,k,2) * ( theta_e(ace%Ta(i,k),ace%q(i,k),ace%ql(i,k)+dql,ace%qi(i,k)+dqi,ace%Ref(k,7)) &
                              - theta_e(ace%Ta(i,k),ace%q(i,k),ace%ql(i,k),ace%qi(i,k),ace%Ref(k,7)) ) / 1.e-8
  if ( qc <= 0. ) then
    dXdt(i,k,:) = 0.
  endif 
enddo
enddo

end subroutine precip_sinks


subroutine p3_wrapper_ace(ace,X_old)
use microphy_p3
implicit none

! input/output variables
type(ace_t), intent(inout) :: ace
real, dimension(ace%ncols+1,ace%nz,ace%n_prog), intent(in) :: X_old 

! local variables
integer, save :: itt = 1
logical, save :: first = .True.
integer, parameter :: n_diag_2d = 1 ,&           ! size of 2d diagnostic array
                      n_diag_3d = 1              ! size of 3d diagnostic array
logical, parameter :: typeDiags_ON  = .False. ,& ! diagnose ice types or not
                      debug_on      = .False. ,& ! debug mode
                      scpf_on       = .False. ,& ! cloud fraction version not used
                      abort_on_err  = .False.  ,& ! program aborts when encountering error
                      dowr          = .True.     ! print message or not
real, parameter :: scpf_pfrac    = 0. ,&   ! dummy variable (not used), set to 0
                   scpf_resfact  = 0. ,&   ! dummy variable (not used), set to 0
                   clbfact_dep   = 1. ,&   ! calibration for deposition
                   clbfact_sub   = 1.      ! calibration for sublimation
character(3), parameter :: model = "ACE"
integer :: i,j,k,stat
real, dimension(ace%ncols,ace%nz) :: qc,nc,qr,nr,th_old,th,qv_old,qv, &
                                     qitot,qirim,qiliq,ni,birim,zi,ssat,w,p,dz, &
                                     diag_ze,diag_effc,diag_effi,diag_vmi,diag_di,diag_rhoi,cldfrac
real, dimension(ace%ncols,n_diag_2d) :: diag_2d
real, dimension(ace%ncols,ace%nz,n_diag_3d) :: diag_3d
real, dimension(ace%ncols) :: precip_liq,precip_sol

if (first) then
  call p3_init('./input_data/',ace%ncat,ace%trplMomI,ace%liqfrac,trim(model),stat,abort_on_err,dowr)
  if (stat/=0) stop "Failure of p3 initialization"
  first = .False.
endif

th_old = X_old(1:ace%ncols,:,2)
qv_old = X_old(1:ace%ncols,:,3)

th    = ace%X(1:ace%ncols,:,2)
qv    = ace%X(1:ace%ncols,:,3)
qc    = ace%X(1:ace%ncols,:,4)
nc    = ace%X(1:ace%ncols,:,5)
qr    = ace%X(1:ace%ncols,:,6)
nr    = ace%X(1:ace%ncols,:,7)
qitot = ace%X(1:ace%ncols,:,8)
ni    = ace%X(1:ace%ncols,:,9)
qirim = ace%X(1:ace%ncols,:,10)
birim = ace%X(1:ace%ncols,:,11)

do k=1,ace%nz
  dz(:,k)   = ace%Ref(k,5)
  p(:,k)    = ace%Ref(k,7)
enddo

zi    = 0.
ssat  = 0.
w     = 0.
qiliq = 0.

call p3_main(qc,nc,qr,nr,th_old,th,qv_old,qv,ace%dt, &
             qitot,qirim,qiliq,ni,birim,zi,ssat,w, &
             p,dz,itt,precip_liq,precip_sol, &
             1,ace%ncols,1,ace%nz,ace%nCat, &
             diag_ze,diag_effc,diag_effi,diag_vmi,diag_di,diag_rhoi, &
             n_diag_2d,diag_2d,n_diag_3d,diag_3d,ace%log_predictNc,trim(model), &
             clbfact_dep,clbfact_sub, &
             debug_on,scpf_on,scpf_pfrac,scpf_resfact,cldfrac,     &
             ace%trplMomI,ace%liqfrac)


if (global_status == -1) stop "p3 stop"

ace%X(1:ace%ncols,:,2)  = th
ace%X(1:ace%ncols,:,3)  = qv
ace%X(1:ace%ncols,:,4)  = qc
ace%X(1:ace%ncols,:,5)  = nc
ace%X(1:ace%ncols,:,6)  = qr
ace%X(1:ace%ncols,:,7)  = nr
ace%X(1:ace%ncols,:,8)  = qitot
ace%X(1:ace%ncols,:,9)  = ni
ace%X(1:ace%ncols,:,10) = qirim
ace%X(1:ace%ncols,:,11) = birim

itt = itt + 1

end subroutine p3_wrapper_ace


function theta_e(T,q,ql,qi,p)
implicit none

real, parameter :: Rd=287.04, Rv=461.5, Cpd=1005.7, Cl=4190., Cvd=719. &
                  ,Cvv=1410., Cpv=1870., Cpvmcl=Cl-Cpv, EPS=Rd/Rv
real, parameter :: Lv0=2.501e6, Ls=2.834e6, Lf=0.3337e6, T0=273.1636783445389, P0=1.e5
real, intent(in) :: T,q,ql,qi,p
integer :: ice
real :: theta_e, qt, Re, e, es, chi, gamma, gammi, R, Cpl

qt = q + ql + qi
e = p*q/(q+EPS*(1-qt))
ice = 0
if (T<T0) ice = 1
!es = polysvp1(T,ice)
es = eval_es(T,ice)

Re = (1-qt)*Rd;
R = Re + q*Rv;

Cpl = Cpd + qt*(Cl-Cpd);

chi = Re/Cpl;
gamma = Rv*q / Cpl;
gammi = (Cl-Ci(T0)) * qi /Cpl;

theta_e = T * (P0*R/p/Re)**chi * (es/e)**gamma * (T0/T)**gammi * exp( (q*Lv(T)/T - Lf*qi/T0)/Cpl )

end function theta_e

 
subroutine inv_theta_e(theta_e,qt,p,T,q,ql,qi)
implicit none

! parameters
real, parameter :: Rd=287.04, Rv=461.5, Cpd=1005.7, Cl=4190., Cvd=719. &
                  ,Cvv=1410., Cpv=1870., Cpvmcl=Cl-Cpv, EPS=Rd/Rv
real, parameter :: Lv0=2.501e6, Ls=2.834e6, Lf=0.3337e6, T0=273.1636783445389, P0=1.e5 &
                  ,qT0=611.3902114165171, LvoT=9155.566660243245
real, parameter :: tol=1e-3

! input/output variables 
real, intent(in) :: theta_e,qt,p
real, intent(out) :: T,q,ql,qi

! local variables
integer :: ice
real :: Cpl,Re,chi,F0,FT0,F,dFdT,R,e,gamma,dT,qc
real :: G0,qsat,qsi,qs,dC,HT0,GT0,tmp,G,H,es,esi,dTqs,dTqsi,dGdT,dHdT

Cpl = Cpd + (Cl-CPd)*qt
Re = Rd*(1-qt)
chi = Re/Cpl

! Step 1: solve assuming no condensate & check consistency
R = Re + Rv*qt
gamma = Rv*qt / Cpl
e = p*qt / (EPS+ (1-EPS)*qt)

F0 = theta_e * (p*Re/R/P0)**chi * e**gamma
!FT0 = T0 * polysvp1(T0,0)**gamma * exp(qt*Lv(T0)/Cpl/T0)
FT0 = T0 * qT0**gamma * exp(qt/Cpl*LvoT)

T = T0
if (F0>=FT0) T = 400.

dT = 9999.
do while (abs(dT)>tol)
  ice = 0
  if (F0<FT0) ice = 1 ! ice exist
  !F = T * polysvp1(T,ice)**gamma * exp(qt*Lv(T)/Cpl/T)
  F = T * eval_es(T,ice) **gamma * exp(qt*Lv(T)/Cpl/T)
  if (ice==0) then
    dFdT = ( 1. - CPVMCL*qt/CPL)/T
  else
    dFdT = ( 1. + 300708.*qt/CPL/T )/T
  endif
  dFdT = dFdT*F
  dT = -(F-F0)/dFdT
  T = T + dT
enddo
q = qt
ql = 0.
qi = 0.


ice = 0
if (T<T0) ice = 1
!qsat = qv_sat(T,p,ice)*(1.-qt)
qsat = eval_qs(T,p,qt,ice)

if (q>qsat) then
  ! Step 2: determine condensate type(s) by comparing G(T0) & H(T0) to G0
  G0 = theta_e * (p*Re/P0)**chi
  dC = 2083.900148084866
  !qsi = qv_sat(T0,p,1) * ( 1. - qt )
  qsi = eval_qs(T0,p,qt,1)
  HT0 = T0 * (RE+RV*qsi)**chi * exp( (qsi*Lv(T0)-Lf*(qt-qsi))/Cpl/T0 )
  !qs = qv_sat(T0,p,0) * ( 1. - qt )
  qs = eval_qs(T0,p,qt,0)
  GT0 =  T0 * (RE+RV*qs)**chi * exp(qs*Lv(T0)/CPL/T0)

  ! 3 cases: liquid-only, ice-only, co-existing
  if (G0>GT0 .and. G0>HT0) then ! liquid-only
    ! estimate initial T
    tmp = log(qt*p) - log(610.78*EPS)
    T = 237.3*tmp/(17.27-tmp) + T0

    dT = 9999.
    do while (abs(dT)>tol)
      !qs = qv_sat(T,p,0)*(1.-qt)
      qs = eval_qs(T,p,qt,0)
      R = Re + Rv*qs
      G = T * R**chi *exp(qs*Lv(T)/Cpl/T)
      !es = polysvp1(T,0)
      es = eval_es(T,0)
      dTqs = (1.-qt)* EPS/Rv * p * Lv(T) * es / ( ( p-es )*T )**2.
      dGdT = 1./T + ( (Rv*Re/R+Lv(T)/T)*dTqs - (Lv0-Cpvmcl*273.15)*qs/T**2. )/Cpl
      dGdT = dGdT*G
      dT = -(G-G0)/dGdT
      T = T + dT
    enddo
    !q = qv_sat(T,p,0)*(1.-qt)
    q = eval_qs(T,p,qt,0)
    ql = qt-q
    qi = 0.
    if (ql<0.) then
      q = qt
      ql = 0.
    endif

  elseif (G0<GT0 .and. G0<HT0) then ! ice-only
    ! estimate initial T
    tmp = log(qt*p) - log(610.78*EPS)
    T = 265.5*tmp/(21.875-tmp) + T0   

    dT = 9999.
    do while (abs(dT)>tol)
      !qsi = qv_sat(T,p,1)*(1.-qt)
      qsi = eval_qs(T,p,qt,1)
      R = Re + Rv*qsi
      qi = qt-qsi
      H = T * R**chi * (T0/T)**(dC*qi/Cpl) * exp((qsi*Lv(T)/T - Lf/T0*qi)/Cpl)
      !esi = polysvp1(T,1)
      esi = eval_es(T,1)
      dTqsi = (1.-qt)* EPS*LS/RV * p * esi / ( ( p-esi )*T )**2.
      dHdT = 1./T + ( ( Rv*Re/R + Lv(T)/T + dC*log(T/T0) + Lf/T0 )*dTqsi &
                     - ( ((Lv0-Cpvmcl*273.15)/T-dC)*qsi + dC*qt )/T )/Cpl
      dHdT = dHdT*H
      dT = -(H-G0)/dHdT
      T = T + dT
    enddo
    !q = qv_sat(T,p,1)*(1.-qt)
    q = eval_qs(T,p,qt,1)
    ql = 0.
    qi = qt-q;
    if (qi<0.) then
      q = qt
      qi = 0.
    endif

  else ! co_existing
    T=T0
    !q = 0.5 * ( qv_sat(T,p,0) + qv_sat(T,p,1) ) *(1.-qt)
    q = 0.5 * ( eval_qs(T,p,qt,0) + eval_qs(T,p,qt,1) )
    R = RE + RV*q
    tmp = (p*Re/R/P0)**chi
    qc = qt-q;
    qi = ( Lv(T0)*q - T0*Cpl*log(theta_e*tmp/T0) )/Lf
    ql = qc-qi
    if (qc<0.) then
      q = qt;
      ql = 0;
      qi = 0;
    elseif (ql<0.) then
      ql = 0;
      qi = qc;
    elseif (qi<0.) then
      qi = 0;
      ql = qc;
    endif

  endif   

endif

endsubroutine inv_theta_e

function eval_es(T,ice)
implicit none

integer, intent(in) :: ice
real, intent(in) :: T
real eval_es


if (ice==0) eval_es = 1.e2 * exp( 53.67957 - 6743.769 / T - 4.8451 * log( T ) )
if (ice==1) eval_es = 1.e2 * exp( 23.33086 - 6111.72784/ T + 0.15215 * log( T ) )

end function eval_es

function eval_qs(T,p,qt,ice)
implicit none

integer, intent(in) :: ice
real, intent(in) :: T, p, qt
real eval_qs, e

e = eval_es(T,ice) 
eval_qs = 0.621971830985916 * e * ( 1 - qt ) / ( p - e )

end function eval_qs

function Lv(T)
implicit none

real, parameter :: Lv0=2.501e6,Cl=4190.,Cpv=1870.,Cpvmcl=Cl-Cpv,T0=273.15
real, intent(in) :: T
real :: Lv

Lv = Lv0 - Cpvmcl*(T - T0)

end function

function Ci(T)
implicit none

real, parameter :: T0=273.1636783445389
real, intent(in) :: T
real :: Ci

Ci = 2106 + 7.3*(T - T0)

end function


! interpolation scheme
subroutine pchip(n,x,y,n_i,x_i,y_i,extrap)
implicit none

! input/output variables
integer, intent(in) :: n, n_i
real, dimension(n), intent(in) :: x, y  ! input should be monotonic increase.
real, dimension(n_i), intent(in) :: x_i
real, dimension(n_i), intent(out) :: y_i
logical, intent(in) :: extrap

! local variables
integer :: i, j
real :: dxs,w1,w2,dmax,dmin
real :: a,b,c,h
real, dimension(n) :: d, m, dx

! calculate slope
d = 0.
do i=1,n-1
  dx(i) = x(i+1) - x(i)
  d(i) = ( y(i+1) - y(i) ) / dx(i)
enddo

! calculate for interior points
m=0.
do i=2,n-1
  if ( d(i-1)*d(i) > 0. ) then
    dxs = dx(i-1) + dx(i)
    w1 = ( dx(i-1) + dxs ) / ( 3. * dxs )
    w2 = ( dxs + dx(i) ) / ( 3. * dxs )
    dmax = max(abs(d(i-1)),abs(d(i)))
    dmin = min(abs(d(i-1)),abs(d(i)))
    m(i) = dmin / ( w1 * d(i-1) / dmax + w2 * d(i) / dmax )
  endif
enddo

! calculate for end points
m(1) = (( 2. * dx(1) + dx(2) ) * d(1) - dx(1) * d(2) ) / ( dx(1) + dx(2) )
if ( m(1)*d(1) <= 0. ) m(1) = 0.
if ( d(1)*d(2) <= 0. .and. abs(m(1)) > abs(3.*d(1)) ) m(1) = 3. * d(1)

m(n) = (( 2. * dx(n-1) + dx(n-2) ) * d(n-1) - dx(n-1) * d(n-2) ) / ( dx(n-1) + dx(n-2) )
if ( m(n)*d(n-1) <= 0. ) m(n) = 0.
if ( d(n-1)*d(n-2) <= 0. .and. abs(m(n)) > abs(3.*d(n-1)) ) m(n) = 3. * d(n-1)

! piecewise cubic Hermite interpolation
do i=1,n_i
  if ( x_i(i)<x(1) ) then
    if (extrap) then
      j=1
      h = x(j+1) - x(j)
      a = ( ( m(j+1) - d(j) ) / h - ( d(j) - m(j) ) / h ) / h
      b = 2. * ( d(j) - m(j) ) / h - ( m(j+1) - d(j) ) / h
      c = m(j)

      h = x_i(i) - x(j)
      y_i(i) = a * h**3. + b * h**2. + c * h + y(j)
    else
      y_i(i) = y(1)
    endif
    goto 987
  endif

  if ( x_i(i)>=x(n) ) then
    if (extrap) then
      j=n-1
      h = x(j+1) - x(j)
      a = ( ( m(j+1) - d(j) ) / h - ( d(j) - m(j) ) / h ) / h
      b = 2. * ( d(j) - m(j) ) / h - ( m(j+1) - d(j) ) / h
      c = m(j)

      h = x_i(i) - x(j)
      y_i(i) = a * h**3. + b * h**2. + c * h + y(j)
    else
      y_i(i) = y(n)
    endif
    goto 987
  endif

  do j=1,n-1
    if ( x(j)<=x_i(i) .and. x_i(i)<x(j+1) ) then
      h = x(j+1) - x(j)
      a = ( ( m(j+1) - d(j) ) / h - ( d(j) - m(j) ) / h ) / h
      b = 2. * ( d(j) - m(j) ) / h - ( m(j+1) - d(j) ) / h 
      c = m(j)

      h = x_i(i) - x(j)
      y_i(i) = a * h**3. + b * h**2. + c * h + y(j)
      goto 987
    endif
  enddo  
  987 continue
enddo

end subroutine pchip


! WENO vec scheme
subroutine weno_vec(k,n,v,c,v_weno) 
implicit none

! input/output variables
integer, intent(in) :: k                   ! scheme order
integer, intent(in) :: n                   ! n of array
real, dimension(n), intent(in) :: v        ! tracer concentration is to be interpolated
real, dimension(n), intent(in) :: c        ! velocity at interpolation points
real, dimension(n), intent(out) :: v_weno  ! estimated values

! local variables
integer, parameter :: p=2
real, parameter :: eps=1.e-10
integer :: i 
real, dimension(k+1,n) :: beta, alpha, w
real, dimension(k+1) :: d

if (k==2) then

d = (/ 0., 2./3., 1./3. /)

do i=k+1,n-k+1
  beta(:,i) = (/ v(i+1)-v(i), v(i)-v(i-1), v(i-1)-v(i-2) /) ** 2.
  alpha(:,i) = 0.5 * ( ( d(1:k+1) + sign(1.,c(i)) * d(1:k+1) ) &
                     + ( d(k+1:1:-1) - sign(1.,c(i)) * d(k+1:1:-1) ) ) &
                    / (eps + beta(:,i)) ** p
  w(:,i) = alpha(:,i) / sum(alpha(:,i),1)

  v_weno(i) = w(1,i) * ( 1.5*v(i  )-0.5*v(i+1)) &
             +w(2,i) * ( 0.5*v(i-1)+0.5*v(i  )) &
             +w(3,i) * (-0.5*v(i-2)+1.5*v(i-1))
enddo

! surface BC modification (reduced order)
i=k
if (c(i)>=0.) then
  v_weno(i) = v(i-1) 
else
  beta(1:k,i) = (/ v(i+1)-v(i), v(i)-v(i-1) /) ** 2.
  alpha(1:k,i) = d(k+1:2:-1) / (eps + beta(1:k,i)) ** p
  w(1:k,i) = alpha(1:k,i) / sum(alpha(1:k,i),1)
  v_weno(i) = w(1,i) * ( 1.5*v(i  )-0.5*v(i+1)) &
             +w(2,i) * ( 0.5*v(i-1)+0.5*v(i  )) 
endif

elseif (k==3) then

d = (/ 0., 0.3, 0.6, 0.1 /)

do i=k+1,n-k+1
  beta(:,i) = (/ 1.083333333333333*(     v(i+2)-2.0*v(i+1)+    v(i  ))**2.0 &
                            + 0.25*(     v(i+2)-4.0*v(i+1)+3.0*v(i  ))**2.0, &
                 1.083333333333333*(     v(i-1)-2.0*v(i  )+    v(i+1))**2.0 &
                            + 0.25*( 3.0*v(i-1)-4.0*v(i  )+    v(i+1))**2.0, &
                 1.083333333333333*(     v(i-2)-2.0*v(i-1)+    v(i  ))**2.0 &
                            + 0.25*(     v(i-2)           -    v(i  ))**2.0, & 
                 1.083333333333333*(     v(i-3)-2.0*v(i-2)+    v(i-1))**2.0 &
                            + 0.25*(     v(i-3)-4.0*v(i-2)+3.0*v(i-1))**2.0 /)
  alpha(:,i) = 0.5 * ( ( d(1:k+1) + sign(1.,c(i)) * d(1:k+1) ) &
                     + ( d(k+1:1:-1) - sign(1.,c(i)) * d(k+1:1:-1) ) ) &
                    / (eps + beta(:,i)) ** p
  w(:,i) = alpha(:,i) / sum(alpha(:,i),1)

  v_weno(i) = w(1,i) * ( 1.833333333333333*v(i  )-1.166666666666667*v(i+1)+0.333333333333333*v(i+2)) &
            + w(2,i) * ( 0.333333333333333*v(i-1)+0.833333333333333*v(i  )-0.166666666666667*v(i+1)) &
            + w(3,i) * (-0.166666666666667*v(i-2)+0.833333333333333*v(i-1)+0.333333333333333*v(i  )) &
            + w(4,i) * ( 0.333333333333333*v(i-3)-1.166666666666667*v(i-2)+1.833333333333333*v(i-1))

enddo

! surface BC modification (reduced order)
do i=2,k
  if (c(k)>=0.) then
    if (i==k) then
      alpha(1:k-1,i) = (/ 2./3., 1./3. /) / (eps + (/ v(i)-v(i-1), v(i-1)-v(i-2) /)**2.) ** p
      w(1:k-1,i) = alpha(1:k,i) / sum(alpha(1:k,i),1)
      v_weno(i) = w(1,i) * ( 0.5*v(i-1)+0.5*v(i  )) &
                 +w(2,i) * (-0.5*v(i-2)+1.5*v(i-1))
    else
      v_weno(i) = v(i-1) 
    endif
  else
    beta(1:k,i) = (/ 1.083333333333333*(     v(i+2)-2.0*v(i+1)+    v(i  ))**2.0 &
                                + 0.25*(     v(i+2)-4.0*v(i+1)+3.0*v(i  ))**2.0, &
                     1.083333333333333*(     v(i-1)-2.0*v(i  )+    v(i+1))**2.0 &
                                + 0.25*( 3.0*v(i-1)-4.0*v(i  )+    v(i+1))**2.0, &
                     1.083333333333333*(     v(i-2)-2.0*v(i-1)+    v(i  ))**2.0 &
                                + 0.25*(     v(i-2)           -    v(i  ))**2.0 /)
    alpha(1:k,i) = d(k+1:2:-1) / (eps + beta(1:k,i)) ** p
    w(1:k,i) = alpha(1:k,i) / sum(alpha(1:k,i),1) 
    v_weno(i) = w(1,i) * ( 1.833333333333333*v(i  )-1.166666666666667*v(i+1)+0.333333333333333*v(i+2)) &
              + w(2,i) * ( 0.333333333333333*v(i-1)+0.833333333333333*v(i  )-0.166666666666667*v(i+1)) &
              + w(3,i) * (-0.166666666666667*v(i-2)+0.833333333333333*v(i-1)+0.333333333333333*v(i  )) 
  endif
enddo

else
  write(*,*) "k is", k, ". The choice of order is not supported yet." 
endif

end subroutine weno_vec


subroutine weno_up3(n,c,c_up3)
implicit none

! input/output variables
integer, intent(in) :: n                   ! n of array
real, dimension(n), intent(in) :: c        ! mass flux is to be interpolated to z+dz/2
real, dimension(n), intent(out) :: c_up3  ! estimated values

! local variables
integer :: i
real :: up3

c_up3 = 0.

do i=2,n-2
  up3 = 7. * ( c(i) + c(i+1) ) - c(i-1) - c(i+2)
  c_up3(i) =  up3 + sign(1.,up3) * ( 3. * ( c(i) - c(i+1) ) + c(i+2) - c(i-1) )
enddo

! surface BC modification
up3 = 8. * c(2) - c(3) 
c_up3(1) = up3 + sign(1.,up3) * ( c(3) - 2. * c(2) )

c_up3 = c_up3 / 12.

end subroutine weno_up3


! WENO scheme
function weno(n,q) result(flux)
implicit none

! input/output variables
integer, intent(in) :: n
real, dimension(2*n-1), intent(in) :: q
real :: flux

! local variables
integer :: i
real, dimension(n) :: wr, alphar, betar, dr
real, dimension(n) :: cij

call cal_dr(n,dr)
call cal_betar(n,q,betar)

alphar = dr / (betar + 1.e-10)**2.
wr = alphar / sum(alphar)

flux = 0.
do i=1,n
  call cal_cij(n,i-1,cij)
  flux = flux + wr(i) * sum(cij*q(n-i+1:2*n-i))
enddo

end function weno

subroutine cal_dr(n,dr)
implicit none

! input/output variables
integer, intent(in) :: n
real, dimension(n), intent(out) :: dr

if (n==2) then
  dr = (/ 2./3., 1./3. /)
elseif (n==3) then
  dr = (/ 3./10., 3./5., 1./10. /)
else
  write(*,*) "n should be 2"
endif

end subroutine  cal_dr

subroutine cal_betar(n,v,betar)
implicit none

! input/output variables
integer, intent(in) :: n
real, dimension(2*n-1), intent(in) :: v
real, dimension(n), intent(out) :: betar

if (n==2) then
  betar = (/ (v(n+1)-v(n))**2., (v(n)-v(n-1))**2. /)
elseif (n==3) then
  betar = (/ 13./12.*(v(n  )-2.*v(n+1)+   v(n+2))**2. &
            +0.25*(3.*v(n  )-4.*v(n+1)+   v(n+2))**2., &
             13./12.*(v(n-1)-2.*v(n  )+   v(n+1))**2. &
            +0.25*(   v(n-1)          -   v(n+1))**2., &
             13./12.*(v(n-2)-2.*v(n-1)+   v(n  ))**2. &
            +0.25*(   v(n-2)-4.*v(n-1)+3.*v(n  ))**2. &
              /)
else
  write(*,*) "n should be 2"
endif

end subroutine cal_betar

subroutine cal_cij(k,r,cij)
implicit none

! input/output variables
integer, intent(in) :: k, r
real, dimension(k), intent(out) :: cij

! local variables
integer :: j,m,l,q
real :: deno, nume, temp

cij = 0.
do j=0,k-1
  do m=j+1,k
    deno = 1.
    do l=0,k
      if (l/=m) deno = deno * (m-l)
    enddo
    nume = 0.
    do l=0,k
      if (l/=m) then
        temp = 1.
        do q=0,k
          if (q/=m .and. q/=l) temp = temp * real(r-q+1)
        enddo
        nume = nume + temp
      endif
    enddo
    cij(j+1) = cij(j+1) + nume/deno
  enddo
enddo

end subroutine cal_cij 
! WENO scheme 

! qv_sat from P3
 real function qv_sat(t_atm,p_atm,i_wrt)

!------------------------------------------------------------------------------------
! Calls polysvp1 to obtain the saturation vapor pressure, and then computes
! and returns the saturation mixing ratio, with respect to either liquid or ice,
! depending on value of 'i_wrt'
!------------------------------------------------------------------------------------

 implicit none

 !Calling parameters:
 real    :: t_atm  !temperature [K]
 real    :: p_atm  !pressure    [Pa]
 integer :: i_wrt  !index, 0 = w.r.t. liquid, 1 = w.r.t. ice

 !Local variables:
 real    :: e_pres         !saturation vapor pressure [Pa]

  e_pres = polysvp1(t_atm,i_wrt)
  qv_sat = 0.622*e_pres/max(1.e-3,(p_atm-e_pres))

 return
 end function qv_sat 

 real function polysvp1(T,i_type)

!-------------------------------------------
!  COMPUTE SATURATION VAPOR PRESSURE
!  POLYSVP1 RETURNED IN UNITS OF PA.
!  T IS INPUT IN UNITS OF K.
!  i_type REFERS TO SATURATION WITH RESPECT TO LIQUID (0) OR ICE (1)
!-------------------------------------------

      implicit none

      real    :: T
      integer :: i_type

! REPLACE GOFF-GRATCH WITH FASTER FORMULATION FROM FLATAU ET AL. 1992, TABLE 4 (RIGHT-HAND COLUMN)

! ice
      real a0i,a1i,a2i,a3i,a4i,a5i,a6i,a7i,a8i
      data a0i,a1i,a2i,a3i,a4i,a5i,a6i,a7i,a8i /&
        6.11147274, 0.503160820, 0.188439774e-1, &
        0.420895665e-3, 0.615021634e-5,0.602588177e-7, &
        0.385852041e-9, 0.146898966e-11, 0.252751365e-14/

! liquid
      real a0,a1,a2,a3,a4,a5,a6,a7,a8

! V1.7
      data a0,a1,a2,a3,a4,a5,a6,a7,a8 /&
        6.11239921, 0.443987641, 0.142986287e-1, &
        0.264847430e-3, 0.302950461e-5, 0.206739458e-7, &
        0.640689451e-10,-0.952447341e-13,-0.976195544e-15/
      real dt

!-------------------------------------------

      if (i_type.EQ.1 .and. T.lt.273.15) then
! ICE

! use Goff-Gratch for T < 195.8 K and Flatau et al. equal or above 195.8 K
         if (t.ge.195.8) then
            dt=t-273.15
            polysvp1 = a0i + dt*(a1i+dt*(a2i+dt*(a3i+dt*(a4i+dt*(a5i+dt*(a6i+dt*(a7i+a8i*dt)))))))
            polysvp1 = polysvp1*100.
         else
            polysvp1 = 10.**(-9.09718*(273.16/t-1.)-3.56654* &
                alog10(273.16/t)+0.876793*(1.-t/273.16)+ &
                alog10(6.1071))*100.
         end if

      elseif (i_type.EQ.0 .or. T.ge.273.15) then
! LIQUID

! use Goff-Gratch for T < 202.0 K and Flatau et al. equal or above 202.0 K
         if (t.ge.202.0) then
            dt = t-273.15
            polysvp1 = a0 + dt*(a1+dt*(a2+dt*(a3+dt*(a4+dt*(a5+dt*(a6+dt*(a7+a8*dt)))))))
            polysvp1 = polysvp1*100.
         else
! note: uncertain below -70 C, but produces physical values (non-negative) unlike flatau
            polysvp1 = 10.**(-7.90298*(373.16/t-1.)+ &
                5.02808*alog10(373.16/t)- &
                1.3816e-7*(10**(11.344*(1.-t/373.16))-1.)+ &
                8.1328e-3*(10**(-3.49149*(373.16/t-1.))-1.)+ &
                alog10(1013.246))*100.
         end if

         endif

 end function polysvp1
! qv_sat from P3


end module ace_module 
