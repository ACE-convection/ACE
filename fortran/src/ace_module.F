module ace_module
use iso_fortran_env, only: real64
use ace_interpolation, only: interp1, pchip
implicit none

private
public :: weno, weno_vec, inv_theta_e, pchip, theta_e, ace_driver, ace_initialization, eval_qs, set_p3_lookup_directory
public :: ace_t, ace_response_t

! OOP-3a: the owning response context retains all existing kinds and layouts.
! This public opaque type permits the transitional callback to pass ownership
! explicitly; its components are private and no pointer aliases are exported.
type :: ace_response_t
  private
  integer :: coarse_nz, coarse_ratio
  real, allocatable :: coarse_z(:), coarse_ze(:), coarse_F(:,:), dwdt(:,:)
  ! All operators: (source level, forcing ACE, response edge, response ACE).
  ! Binary64 coefficients and vertical-then-forcing reduction are preserved.
  real*8, allocatable :: PMB(:,:,:,:), PMDv(:,:,:,:), PMD(:,:,:,:)
  logical :: slab_geometry=.false., zero_ref_buoyancy=.false., Wbar_eq_zero=.false.
  logical :: turn_off_DHv=.true., turn_off_DHh=.true.
end type ace_response_t

! Integration cache lifetime follows the original initialization/RK sequence.
type :: ace_thermal_t
  private
  real, allocatable :: reference_tv(:), Ta(:,:), q(:,:), ql(:,:), qi(:,:)
end type ace_thermal_t

! First-use damping cache retains the original kind, expression and timing.
type :: ace_damping_t
  private
  real, allocatable :: damp(:)
  logical :: first=.true.
end type ace_damping_t

! Wrapper ownership does not isolate the third-party process-wide P3 library.
type :: ace_p3_t
  private
  character(1024) :: directory="./input_data/"
  integer :: itt=1
  logical :: first=.true.
end type ace_p3_t

! Observational diagnostics are separate from initialization and RK caches.
type :: ace_diagnostics_t
  private
  real, allocatable :: Tr(:,:), q(:,:), ql(:,:), qi(:,:)
  real(kind=4), allocatable :: Xout(:,:,:), rh4(:,:), b4(:,:)
end type ace_diagnostics_t

! OOP-4b: the model owns observational diagnostics and normal output records.
! Components retain the existing model real kind and layouts.
type :: ace_t
  private
  type(ace_response_t) :: response
  type(ace_thermal_t) :: thermal
  type(ace_damping_t) :: damping
  type(ace_p3_t) :: p3
  type(ace_diagnostics_t) :: diagnostics
  integer :: output_unit, output_record=1
  logical :: output_open=.false.
  logical :: precipitation_enabled
  integer :: ncols, nz, n_prog, n_weno
  real :: dt, t
  real, allocatable :: X(:,:,:), Ref(:,:), A(:), B(:), forcing(:,:)
  real, allocatable :: Tv0(:),z(:),zm(:),rho_e(:),rho_zm(:),the_e(:),q_e(:),p_z(:)
  real, allocatable :: coarse_z(:),coarse_ze(:),Tr(:,:),q(:,:),ql(:,:),qi(:,:)
  real(real64), allocatable :: input_profile(:,:),diameters(:),input_area(:),input_perimeter(:)
  real(real64), allocatable :: input_coarse_z(:),input_coarse_ze(:),tmp(:)
contains
  procedure :: open_output => model_open_output
  procedure :: output => model_output
  procedure :: close_output => model_close_output
  procedure :: diagnose => model_diagnose
  procedure :: integrate => model_integrate
  procedure :: initialize => model_initialize
  procedure :: with_legacy_state => model_with_legacy_state
end type ace_t

! defien operator for grid interface

real, parameter :: pi = 4.*atan(1.)
real, parameter :: g = 9.80665 ! gravity constant 
real, parameter :: nju = 0.09 ! Morrison (2017)
! Spounge layer with Newtonian damping at domain top ztop
real, parameter :: SLD = 6e3  ! e-folding depth in m
real, parameter :: SLTau = 180 ! SL relaxation timescale in s
! coefficients for precipitation sinks
real, parameter :: qc_ramp = 0.5e-3 ! kg/kg; ramping for precip when qc>qc_ramp
real, parameter :: dqc = 20 ! kg/kg; transition for a smooth onset of precip ramp function
real, parameter :: tau_pr = 5*60 ! sec; relaxation timescale for precip

! Compatibility storage for the old procedural interfaces; never used by ace_t.
type(ace_response_t), save :: legacy_response
type(ace_thermal_t), save :: legacy_thermal
type(ace_damping_t), save :: legacy_damping
type(ace_p3_t), save :: legacy_p3
! No reset/release: p3_init and mutable library status persist for this process.
logical, save :: p3_context_claimed=.false.

contains

subroutine ace_driver(ncols,nz,n_weno,n_prog,X,Ref,A,B,t,te,dt,B_forcing,precipitation_input,response)
implicit none
! input/output variables
integer, intent(in) :: ncols,nz,n_weno,n_prog
real, dimension(ncols), intent(in) :: A, B
real, dimension(nz,8), intent(in) :: Ref
real, dimension(ncols+1,nz,n_prog), intent(inout) :: X
real, intent(inout) :: t
real, intent(in) :: te,dt
real, dimension(ncols,nz), intent(in) :: B_forcing
logical, intent(in), optional :: precipitation_input

type(ace_response_t), intent(inout), optional :: response
! Procedural callers use the legacy thermal cache and optional response context.
if (present(response)) then
  call ace_driver_context(response,legacy_thermal,legacy_damping,legacy_p3,ncols,nz,n_weno,n_prog,X,Ref,A,B,t,te,dt,B_forcing,precipitation_input)
else
  call ace_driver_context(legacy_response,legacy_thermal,legacy_damping,legacy_p3,ncols,nz,n_weno,n_prog,X,Ref,A,B,t,te,dt,B_forcing,precipitation_input)
endif
end subroutine ace_driver


subroutine ace_driver_context(response,thermal,damping,p3,ncols,nz,n_weno,n_prog,X,Ref,A,B,t,te,dt,B_forcing,precipitation_input)
implicit none
type(ace_response_t), intent(inout) :: response
type(ace_thermal_t), intent(inout) :: thermal
type(ace_damping_t), intent(inout) :: damping
type(ace_p3_t), intent(inout) :: p3

! input/output variables
integer, intent(in) :: ncols,nz,n_weno,n_prog
real, dimension(ncols), intent(in) :: A, B
real, dimension(nz,8), intent(in) :: Ref
real, dimension(ncols+1,nz,n_prog), intent(inout) :: X
real, intent(inout) :: t
real, intent(in) :: te,dt
real, dimension(ncols,nz), intent(in) :: B_forcing
logical, intent(in), optional :: precipitation_input

! local variables
real, dimension(ncols+1,nz,n_prog) :: yi
real, dimension(ncols,nz,n_prog) :: K1,K2,tmp
real :: dum1
real :: mean_mf(nz)
integer :: i,k

yi = X

do while ( t < te)
  ! update ace tendency
  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,X,Ref,K1,1)
  yi(1:ncols,:,:) = X(1:ncols,:,:) + K1 * dt / 6.

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,K2,2)
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,3)
  K2 = K2 + tmp
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,4)
  K2 = K2 + tmp
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,5)
  K2 = K2 + tmp
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,6)
  K2 = ( K2 + tmp ) / 15.
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt 

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,7)
  K1 = K1 + tmp 
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt 

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,8)
  K1 = K1 + tmp 
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt 

  call ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,9)
  K1 = K1 + tmp

  yi = X
  X(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt
  
  ! Match S20's end-of-SSPRK area-mean MF removal before physics/damping.
  if (response%Wbar_eq_zero) then
    do k=1,nz
      mean_mf(k)=sum(X(1:ncols,k,1)*(A/sum(A)))
    enddo
    do i=1,ncols
      X(i,:,1)=X(i,:,1)-mean_mf
    enddo
  endif

  ! call physics here
  if (n_prog==3) then
    ! KHN26 clips total water after SSPRK and recomputes physics from that state.
    X(1:ncols,:,3)=max(X(1:ncols,:,3),0.)
    if (.not.present(precipitation_input)) then
      call apply_native_precipitation()
    elseif (precipitation_input) then
      call apply_native_precipitation()
    endif
  elseif (n_prog==11) then
    call p3_wrapper_ace(p3,ncols,nz,n_prog,dt,yi,X,Ref)
  else
    write(*,*) "No suitable microphysics scheme"
    stop
  endif

  ! NaN check
  do k=1,nz
  do i=1,ncols
    if (X(i,k,2)/=X(i,k,2)) then
      write(*,*) i,k,Ref(k,7)
      write(*,*) yi(i,k,2:n_prog)
      write(*,*) X(i,k,2:n_prog)
      stop "check 2"
    endif    
  enddo
  enddo

  ! implicit damping 
  call ImDamp(damping,ncols,nz,n_prog,X,Ref,dt)


  t = t + dt
enddo


contains
subroutine apply_native_precipitation()
integer :: ii,kk
do kk=1,nz
  do ii=1,ncols
    call inv_theta_e(X(ii,kk,2),X(ii,kk,3),Ref(kk,7),thermal%Ta(ii,kk),thermal%q(ii,kk),thermal%ql(ii,kk),thermal%qi(ii,kk))
  enddo
enddo
call precip_sinks_context(thermal,ncols,nz,n_prog,Ref(:,7),K1(:,:,1:2))
X(1:ncols,:,2:3)=X(1:ncols,:,2:3)+K1(:,:,1:2)*dt
end subroutine
endsubroutine ace_driver_context


subroutine ace_initialization(ncols,nz,nz_presolve,z_presolve,ze_presolve,fname,environment_tv,netcdf_input, &
                              turn_off_DHv_input,turn_off_DHh_input,zero_ref_buoyancy_input,Wbar_eq_zero_input,response)
implicit none
! input variables
integer, intent(in) :: ncols, nz, nz_presolve
real, dimension(nz_presolve) :: z_presolve
real, dimension(nz_presolve+1) :: ze_presolve
character(*), intent(in) :: fname
real, intent(in) :: environment_tv(nz)
logical, intent(in), optional :: netcdf_input
logical, intent(in), optional :: turn_off_DHv_input,turn_off_DHh_input,zero_ref_buoyancy_input,Wbar_eq_zero_input

type(ace_response_t), intent(inout), optional :: response
! Procedural callers use the legacy thermal cache and optional response context.
if (present(response)) then
  call ace_initialization_context(response,legacy_thermal,ncols,nz,nz_presolve,z_presolve,ze_presolve,fname,environment_tv,netcdf_input, &
                              turn_off_DHv_input,turn_off_DHh_input,zero_ref_buoyancy_input,Wbar_eq_zero_input)
else
  call ace_initialization_context(legacy_response,legacy_thermal,ncols,nz,nz_presolve,z_presolve,ze_presolve,fname,environment_tv,netcdf_input, &
                              turn_off_DHv_input,turn_off_DHh_input,zero_ref_buoyancy_input,Wbar_eq_zero_input)
endif
end subroutine ace_initialization


subroutine ace_initialization_context(response,thermal,ncols,nz,nz_presolve,z_presolve,ze_presolve,fname,environment_tv,netcdf_input, &
                              turn_off_DHv_input,turn_off_DHh_input,zero_ref_buoyancy_input,Wbar_eq_zero_input)
use ace_input, only: read_case_basis, read_case_metadata, basis_available
use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
implicit none
type(ace_response_t), intent(inout) :: response
type(ace_thermal_t), intent(inout) :: thermal

! input variables
integer, intent(in) :: ncols, nz, nz_presolve
real, dimension(nz_presolve) :: z_presolve
real, dimension(nz_presolve+1) :: ze_presolve
character(*), intent(in) :: fname
real, intent(in) :: environment_tv(nz)
logical, intent(in), optional :: netcdf_input
logical, intent(in), optional :: turn_off_DHv_input,turn_off_DHh_input,zero_ref_buoyancy_input,Wbar_eq_zero_input

! local variables
integer :: i,j,k,n,record_length,input_nz,input_cols,input_coarse
logical :: shared
real*8, allocatable :: packed_pmb(:,:,:,:)
character(64) :: geometry

if (.not.all(ieee_is_finite(environment_tv)) .or. any(environment_tv<=0.)) &
  error stop 'Invalid environmental density temperature'
allocate(thermal%reference_tv(nz))
thermal%reference_tv=environment_tv
response%slab_geometry=.false.
response%turn_off_DHv=.true.; response%turn_off_DHh=.true.
if (present(turn_off_DHv_input)) response%turn_off_DHv=turn_off_DHv_input
if (present(turn_off_DHh_input)) response%turn_off_DHh=turn_off_DHh_input
response%coarse_nz=nz_presolve
if (response%coarse_nz<1) error stop 'Invalid coarse basis size'
if (mod(nz-1,response%coarse_nz)/=0) error stop 'Fine grid does not partition into coarse layers'
response%coarse_ratio=(nz-1)/response%coarse_nz
shared=.false.
if (present(netcdf_input)) shared=netcdf_input
allocate(response%coarse_z(response%coarse_nz),response%coarse_ze(response%coarse_nz+1))
allocate(response%coarse_F(ncols,response%coarse_nz))
allocate(response%PMB(ncols,ncols,response%coarse_nz,response%coarse_nz+1))
allocate(response%dwdt(ncols,response%coarse_nz+1))
allocate(thermal%Ta(ncols,nz),thermal%q(ncols,nz),thermal%ql(ncols,nz),thermal%qi(ncols,nz))


if (shared) then
  call read_case_metadata(fname,input_nz,input_cols,input_coarse,geometry)
  if (input_nz/=nz .or. input_cols/=ncols .or. input_coarse/=response%coarse_nz) &
    error stop 'Basis metadata disagrees with initialized model'
  call read_case_basis(fname,'PMB',response%PMB)
  response%slab_geometry=trim(geometry)=='slab'
  if (response%slab_geometry) then
    allocate(response%PMDv(ncols,ncols,response%coarse_nz,response%coarse_nz+1),response%PMD(ncols,ncols,response%coarse_nz,response%coarse_nz+1))
    if (.not.response%turn_off_DHv .and. .not.basis_available(fname,'PMDv')) &
      error stop 'Cannot activate unavailable PMDv'
    if (.not.response%turn_off_DHh .and. .not.basis_available(fname,'PMD')) &
      error stop 'Cannot activate unavailable PMD'
    call read_case_basis(fname,'PMDv',response%PMDv)
    call read_case_basis(fname,'PMD',response%PMD)
  endif
else
  inquire(iolength=record_length) response%PMB(1,1,1,:)
  open(10,file=trim(fname),access="direct",recl=record_length)
  n=1
  do k=1,ncols
    do j=1,ncols
      do i=1,response%coarse_nz
        read(10,rec=n) response%PMB(k,j,i,:)
        n=n+1
      enddo
    enddo
  enddo
  close(10)
endif

! Pack once; release the input layout before time integration.
allocate(packed_pmb(response%coarse_nz,ncols,response%coarse_nz+1,ncols))
do i=1,ncols
  do k=1,response%coarse_nz+1
    packed_pmb(:,:,k,i)=transpose(response%PMB(i,:,:,k))
  enddo
enddo
call move_alloc(packed_pmb,response%PMB)
if (allocated(response%PMDv)) call pack_momentum_basis(response%PMDv)
if (allocated(response%PMD)) call pack_momentum_basis(response%PMD)

response%Wbar_eq_zero=response%slab_geometry
if (present(Wbar_eq_zero_input)) response%Wbar_eq_zero=Wbar_eq_zero_input
response%zero_ref_buoyancy=response%slab_geometry
if (present(zero_ref_buoyancy_input)) response%zero_ref_buoyancy=zero_ref_buoyancy_input
if ((.not.response%turn_off_DHv .or. .not.response%turn_off_DHh) .and. .not.response%slab_geometry) &
  error stop 'Momentum response requires schema 2 slab operators'
response%coarse_z = z_presolve
response%coarse_ze = ze_presolve

end subroutine ace_initialization_context

subroutine pack_momentum_basis(basis)
! Pure permutation: input (response,forcing,source,edge) to contiguous source.
! Use one temporary operator at a time; retain every binary64 coefficient.
real*8, allocatable, intent(inout) :: basis(:,:,:,:)
real*8, allocatable :: packed(:,:,:,:)
integer :: i,k
allocate(packed(size(basis,3),size(basis,2),size(basis,4),size(basis,1)))
do i=1,size(basis,1)
  do k=1,size(basis,4)
    packed(:,:,k,i)=transpose(basis(i,:,:,k))
  enddo
enddo
call move_alloc(packed,basis)
end subroutine pack_momentum_basis


subroutine ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,X,Ref,dXdt,rkstage,response)
implicit none
! input/output variables
integer, intent(in) :: ncols, nz, n_weno, n_prog, rkstage
real, intent(in) :: dt
real, dimension(ncols), intent(in) :: A, B ! ACE area/perimeter in SI [m^2, m]
real, dimension(nz,8), intent(in) :: Ref ! reference varaibles: rhoc, rhoz, z, zm, dz, dzm, p, pi
! n_prog=3: MF/theta_e/qt; n_prog=11: MF/theta/qv/qc/nc/qr/nr/qi/ni/qrim/brim.
real, dimension(ncols+1,nz,n_prog), intent(in) :: X
real, dimension(ncols,nz,n_prog), intent(out) :: dXdt

type(ace_response_t), intent(inout), optional :: response
! Procedural callers use the legacy thermal cache and optional response context.
if (present(response)) then
  call ace_tendency_context(response,legacy_thermal,ncols,nz,n_weno,n_prog,dt,A,B,X,Ref,dXdt,rkstage)
else
  call ace_tendency_context(legacy_response,legacy_thermal,ncols,nz,n_weno,n_prog,dt,A,B,X,Ref,dXdt,rkstage)
endif
end subroutine ace_tendency


subroutine ace_tendency_context(response,thermal,ncols,nz,n_weno,n_prog,dt,A,B,X,Ref,dXdt,rkstage)
implicit none
type(ace_response_t), intent(inout) :: response
type(ace_thermal_t), intent(inout) :: thermal

! input/output variables
integer, intent(in) :: ncols, nz, n_weno, n_prog, rkstage
real, intent(in) :: dt
real, dimension(ncols), intent(in) :: A, B ! ACE area/perimeter in SI [m^2, m]
real, dimension(nz,8), intent(in) :: Ref ! reference varaibles: rhoc, rhoz, z, zm, dz, dzm, p, pi
! n_prog=3: MF/theta_e/qt; n_prog=11: MF/theta/qv/qc/nc/qr/nr/qi/ni/qrim/brim.
real, dimension(ncols+1,nz,n_prog), intent(in) :: X
real, dimension(ncols,nz,n_prog), intent(out) :: dXdt

! local variables
integer :: i,j,l,n,k,ks,ke,outer
real :: dum1,dum2
real*8 :: partial,value
real :: packed_F(response%coarse_nz,ncols)
real :: packed_DHv(response%coarse_nz,ncols),packed_DHh(response%coarse_nz,ncols)
real, dimension(ncols,nz,2) :: eps_tur
real, dimension(nz) :: Tv, mean_rho0B
real, dimension(ncols,nz) :: rho0B, FH, dz2FH, DHh
real, dimension(ncols,response%coarse_nz) :: coarse_DHv, coarse_DHh
real, dimension(ncols,nz,3) :: dXdz
real, dimension(ncols,nz,2:n_prog) :: Ci, rho0wC
real, dimension(ncols+1,nz) :: mfc, Wc
real, dimension(ncols,nz) ::Wi, Admfdz, ioflow, F


! initialization
do k=1,nz
  eps_tur(:      ,k,1) = nju*B/A
  eps_tur(2:ncols,k,2) = nju*B(1:ncols-1)/A(2:ncols)
enddo

! fill with zeros
dXdt = 0.
mfc = 0.
Wc = 0.
FH = 0.; dz2FH = 0.; DHh = 0.

! Compute tracer values Ci(zi) at interface points from C(zc=zi+dz/2)
do i=1,ncols
  do n=2,n_prog
    call weno_vec(n_weno,nz,X(i,:,n),X(i,:,1),rho0wC(i,:,n))
    rho0wC(i,:,n) = X(i,:,1) * rho0wC(i,:,n)
    rho0wC(i,1,n) = 0. ! set surface fluxes to zero
  enddo

  ! Vertical velocity w(zi) (mass flux already at zi)
  Wi(i,:) = X(i,:,1) / Ref(:,2)

  ! Vertical mass flux & velocity at zc=zi+dz/2
  call weno_up3(nz,X(i,:,1),mfc(i,:))
  Wc(i,:) = mfc(i,:) / Ref(:,1)

  ! Admfdz = (ACE area)*dmfdz for dynamic inflow/outflow at zc=zi+dz/2
  Admfdz(i,nz) = 0.
  Admfdz(i,1:nz-1) = A(i) * ( X(i,2:nz,1) - X(i,1:nz-1,1) ) / Ref(2:nz,6)

  ! ioflow = -Bi*rho_0*u_n (minus h. mass flux * lateral boundary length)
  ioflow(i,:) = sum(Admfdz(1:i,:),1)
enddo
! MATLAB S20 uses the outermost ACE itself for outer momentum exchange.
! Annular input keeps its existing zero-MF environment.
if (response%slab_geometry) then
  mfc(ncols+1,:)=mfc(ncols,:)
  Wc(ncols+1,:)=Wc(ncols,:)
endif

do i=1,ncols
  outer=i+1
  if (response%slab_geometry) outer=min(outer,ncols)
  do n=2,n_prog
    dXdt(i,1:nz  ,n) = 0.
    dXdt(i,1:nz-1,n) = - ( rho0wC(i,2:nz,n) - rho0wC(i,1:nz-1,n) ) / Ref(1:nz-1,5) / Ref(1:nz-1,1)  ! vertical flux convergence

    dXdt(i,1:nz-1,n) = dXdt(i,1:nz-1,n) - eps_tur(i,1:nz-1,1) * ( X(i,1:nz-1,n) - X(outer,1:nz-1,n) )  ! interact outer
    if (i>1) &
    dXdt(i,1:nz-1,n) = dXdt(i,1:nz-1,n) - eps_tur(i,1:nz-1,2) * ( X(i,1:nz-1,n) - X(i-1,1:nz-1,n) )  ! interact inner

    dXdt(i,1:nz-1,n) = dXdt(i,1:nz-1,n) + 0.5 * &
                       ( ( ioflow(i  ,1:nz-1) + abs(ioflow(i  ,1:nz-1)) ) * X(outer,1:nz-1,n) &
                       + ( ioflow(i  ,1:nz-1) - abs(ioflow(i  ,1:nz-1)) ) * X(i  ,1:nz-1,n) ) &
                        / A(i) / Ref(1:nz-1,1)  ! inflow from outer
    if (i>1) &
    dXdt(i,1:nz-1,n) = dXdt(i,1:nz-1,n) - 0.5 * &
                       ( ( ioflow(i-1,1:nz-1) + abs(ioflow(i-1,1:nz-1)) ) * X(i  ,1:nz-1,n) &
                       + ( ioflow(i-1,1:nz-1) - abs(ioflow(i-1,1:nz-1)) ) * X(i-1,1:nz-1,n) ) &
                        / A(i) / Ref(1:nz-1,1)  ! inflow from inner
  enddo

  F(i,1:nz  ) = 0.
  F(i,1:nz-1) = - ( X(i,2:nz,1) * Wi(i,2:nz) - X(i,1:nz-1,1) * Wi(i,1:nz-1) ) / Ref(1:nz-1,5)  ! vertical flux convergence
  F(i,1:nz-1) = F(i,1:nz-1) - eps_tur(i,1,1) * ( mfc(i,1:nz-1) - mfc(i+1,1:nz-1) )  ! interact outer
  if (i>1) &
  F(i,1:nz-1) = F(i,1:nz-1) - eps_tur(i,1,2) * ( mfc(i,1:nz-1) - mfc(i-1,1:nz-1) )  ! interact inner
  F(i,1:nz-1) = F(i,1:nz-1) + 0.5 * &
                     ( ( ioflow(i  ,1:nz-1) + abs(ioflow(i  ,1:nz-1)) ) * Wc(i+1,1:nz-1) &
                     + ( ioflow(i  ,1:nz-1) - abs(ioflow(i  ,1:nz-1)) ) * Wc(i  ,1:nz-1) ) / A(i)  ! inflow from outer
  if (i>1) &
  F(i,1:nz-1) = F(i,1:nz-1) - 0.5 * &
                     ( ( ioflow(i-1,1:nz-1) + abs(ioflow(i-1,1:nz-1)) ) * Wc(i  ,1:nz-1) &
                     + ( ioflow(i-1,1:nz-1) - abs(ioflow(i-1,1:nz-1)) ) * Wc(i-1,1:nz-1) ) / A(i)  ! inflow from inner

  if (.not.response%turn_off_DHv) then
    FH(i,1:nz-1) = -eps_tur(i,1,1)*(mfc(i,1:nz-1)-mfc(i+1,1:nz-1))
    if (i>1) FH(i,1:nz-1)=FH(i,1:nz-1)-eps_tur(i,1,2)*(mfc(i,1:nz-1)-mfc(i-1,1:nz-1))
    FH(i,1:nz-1)=FH(i,1:nz-1)+0.5*( &
      (ioflow(i,1:nz-1)+abs(ioflow(i,1:nz-1)))*Wc(i+1,1:nz-1) &
      +(ioflow(i,1:nz-1)-abs(ioflow(i,1:nz-1)))*Wc(i,1:nz-1))/A(i)
    if (i>1) FH(i,1:nz-1)=FH(i,1:nz-1)-0.5*( &
      (ioflow(i-1,1:nz-1)+abs(ioflow(i-1,1:nz-1)))*Wc(i,1:nz-1) &
      +(ioflow(i-1,1:nz-1)-abs(ioflow(i-1,1:nz-1)))*Wc(i-1,1:nz-1))/A(i)
    ! MATLAB lower ghost=-FH(1), upper ghost=0; uniform shared input dz.
    dz2FH(i,1)=(-3.*FH(i,1)+FH(i,2))/Ref(1,5)**2
    do k=2,nz-1
      dz2FH(i,k)=(FH(i,k-1)-2.*FH(i,k)+FH(i,k+1))/Ref(k,5)**2
    enddo
  endif
  if (.not.response%turn_off_DHh) then
    DHh(i,1:nz-1)=ioflow(i,1:nz-1)**2
    if (i>1) DHh(i,1:nz-1)=DHh(i,1:nz-1)-ioflow(i-1,1:nz-1)**2
    DHh(i,1:nz-1)=DHh(i,1:nz-1)/Ref(1:nz-1,1)/A(i)
    ! Supplied slab PMD uses MATLAB's Ai in km^2, whereas A here is m^2.
    ! ioflow^2/A scales with area: restore the native-basis forcing units.
    DHh(i,1:nz-1)=DHh(i,1:nz-1)/1.e6
  endif

  if (rkstage==1) then
    do k=1,nz
      if (n_prog==3) then
        call inv_theta_e(X(i,k,2),X(i,k,3),Ref(k,7),thermal%Ta(i,k),thermal%q(i,k),thermal%ql(i,k),thermal%qi(i,k))
      elseif (n_prog==11) then
        thermal%Ta(i,:) = X(i,:,2) * Ref(:,8)
        thermal%q(i,:)  = X(i,:,3)
        thermal%ql(i,:) = X(i,:,4) + X(i,:,6)
        thermal%qi(i,:) = X(i,:,8)
      endif
    enddo 
  endif

  Tv(1:nz) = thermal%Ta(i,1:nz) * ( 1. + 0.607789855072462 * thermal%q(i,1:nz) - thermal%ql(i,1:nz) - thermal%qi(i,1:nz) )
  rho0B(i,:) = g * Ref(:,1) * (Tv-thermal%reference_tv) / thermal%reference_tv
enddo

! MATLAB S20 removes the area-weighted mean buoyancy before nonlocal response.
if (response%zero_ref_buoyancy) then
  do k=1,nz
    mean_rho0B(k)=sum(rho0B(:,k)*(A/sum(A)))
  enddo
  do i=1,ncols
    rho0B(i,:)=rho0B(i,:)-mean_rho0B
  enddo
endif

do i=1,ncols
  F(i,:)=F(i,:)+rho0B(i,:)
  response%coarse_F(i,:)=sum(reshape(F(i,1:nz-1),[response%coarse_ratio,response%coarse_nz]),1)/real(response%coarse_ratio)
  if (.not.response%turn_off_DHv) &
    coarse_DHv(i,:)=-sum(reshape(dz2FH(i,1:nz-1),[response%coarse_ratio,response%coarse_nz]),1)/real(response%coarse_ratio)
  if (.not.response%turn_off_DHh) &
    coarse_DHh(i,:)=sum(reshape(DHh(i,1:nz-1),[response%coarse_ratio,response%coarse_nz]),1)/real(response%coarse_ratio)
enddo

packed_F=transpose(response%coarse_F)
if (.not.response%turn_off_DHv) packed_DHv=transpose(coarse_DHv)
if (.not.response%turn_off_DHh) packed_DHh=transpose(coarse_DHh)
! Each output keeps the legacy vertical-then-forcing reduction order.
! Without -fopenmp these directives leave the same serial kernel.
!$omp parallel do collapse(2) default(none) schedule(static) &
!$omp shared(ncols,response,packed_F,packed_DHv,packed_DHh) private(i,k,j,l,partial,value)
do i=1,ncols
  do k=1,response%coarse_nz+1
    value=0.
    do j=1,ncols
      partial=0.
      do l=1,response%coarse_nz
        partial=partial+response%PMB(l,j,k,i)*packed_F(l,j)
      enddo
      value=value+partial
    enddo
    response%dwdt(i,k)=value
    ! Retain separate PMB + PMDv + PMD additions; do not combine reductions.
    if (.not.response%turn_off_DHv) then
      value=0.
      do j=1,ncols
        partial=0.
        do l=1,response%coarse_nz
          partial=partial+response%PMDv(l,j,k,i)*packed_DHv(l,j)
        enddo
        value=value+partial
      enddo
      response%dwdt(i,k)=response%dwdt(i,k)+value
    endif
    if (.not.response%turn_off_DHh) then
      value=0.
      do j=1,ncols
        partial=0.
        do l=1,response%coarse_nz
          partial=partial+response%PMD(l,j,k,i)*packed_DHh(l,j)
        enddo
        value=value+partial
      enddo
      response%dwdt(i,k)=response%dwdt(i,k)+value
    endif
  enddo
enddo
!$omp end parallel do

do i=1,ncols
  if (response%slab_geometry) then
    if (response%coarse_ratio==1) then
      ! Schema 2 basis edges coincide with MF levels, as in S20's direct branch.
      dXdt(i,:,1)=response%dwdt(i,:)
    else
      call interp1(response%coarse_nz+1,response%coarse_ze,response%dwdt(i,:),nz,Ref(:,4),dXdt(i,:,1),'makima',extrap=.true.)
    endif
  else
    call interp1(response%coarse_nz+1,response%coarse_ze,response%dwdt(i,:),nz,Ref(:,4),dXdt(i,:,1),'pchip',extrap=.true.)
  endif
enddo  

! single ACE
!dXdt(2:ncols,:,:)=0.

! model top 
dXdt(:,nz-10:nz,:)=0.


end subroutine ace_tendency_context

 
subroutine ImDamp(damping,ncols,nz,n_prog,X,Ref,dt)
implicit none
type(ace_damping_t), intent(inout) :: damping

! input/output variables
integer, intent(in) :: ncols,nz,n_prog
real, intent(in) :: dt
real, dimension(ncols+1,nz,n_prog), intent(inout) :: X
real, dimension(nz,7), intent(in) :: Ref

! local variable
integer :: i,k,n

if (damping%first) then
  allocate(damping%damp(nz))
  do k=1,nz
    damping%damp(k) = dt * exp( ( Ref(k,3) - Ref(nz,3) ) / SLD ) / SLTau
  enddo
  damping%first = .False.
endif

do k=1,nz
  do i=1,ncols
    X(i,k,1) = X(i,k,1) / ( 1. + damping%damp(k) / Ref(k,2) )
    do n=2,n_prog
      X(i,k,n) = ( X(i,k,n) + damping%damp(k) * X(ncols+1,k,n) / Ref(k,1) ) / ( 1. + damping%damp(k) / Ref(k,1) )
    enddo
  enddo
enddo

end subroutine ImDamp

subroutine precip_sinks(ncols,nz,n_prog,p,dXdt)
implicit none
integer, intent(in) :: ncols,nz,n_prog
real, intent(in) :: p(nz)
real, intent(inout) :: dXdt(ncols,nz,n_prog-1)
call precip_sinks_context(legacy_thermal,ncols,nz,n_prog,p,dXdt)
end subroutine precip_sinks

subroutine precip_sinks_context(thermal,ncols,nz,n_prog,p,dXdt)
implicit none
type(ace_thermal_t), intent(in) :: thermal

! input/output variables
integer, intent(in) :: ncols,nz,n_prog
real, dimension(nz), intent(in) :: p
real, dimension(ncols,nz,n_prog-1), intent(inout) :: dXdt

! local variables
integer :: i,k
real :: qc, dql, dqi, ramp


do k=1,nz
do i=1,ncols
  qc = thermal%ql(i,k) + thermal%qi(i,k)
  dXdt(i,k,:)=0.
  if (qc<=0.) cycle
  ramp=dqc/qc_ramp*(qc-qc_ramp)
  ! Follow MATLAB's expression while exp(ramp) is representable.
  if (ramp<=log(huge(ramp))) then
    dXdt(i,k,2)=-(qc_ramp/dqc/tau_pr)*log(1.+exp(ramp))
  else
    ! Preserve the finite sink for extreme inputs that overflow MATLAB exp.
    dXdt(i,k,2)=-(qc_ramp/dqc/tau_pr)*(max(ramp,0.)+log(1.+exp(-abs(ramp))))
  endif
  dql = 1.e-8 * thermal%ql(i,k) / qc
  dqi = 1.e-8 * thermal%qi(i,k) / qc
  dXdt(i,k,1) = dXdt(i,k,2) * ( theta_e(thermal%Ta(i,k),thermal%q(i,k),thermal%ql(i,k)+dql,thermal%qi(i,k)+dqi,p(k)) &
                              - theta_e(thermal%Ta(i,k),thermal%q(i,k),thermal%ql(i,k),thermal%qi(i,k),p(k)) ) / 1.e-8
enddo
enddo

end subroutine precip_sinks_context


subroutine set_p3_lookup_directory(directory)
character(*), intent(in) :: directory
call set_p3_context_directory(legacy_p3,directory)
end subroutine

subroutine set_p3_context_directory(p3,directory)
type(ace_p3_t), intent(inout) :: p3
character(*), intent(in) :: directory
if (len_trim(directory)==0 .or. len_trim(directory)>len(p3%directory)) &
  error stop 'Invalid P3 lookup directory'
p3%directory=directory
end subroutine

subroutine p3_wrapper_ace(p3,ncols,nz,n_prog,dt,X_old,X,Ref)
use microphy_p3
implicit none
type(ace_p3_t), intent(inout) :: p3

! input/output variables
integer, intent(in) :: ncols, nz, n_prog
real, intent(in) :: dt
real, dimension(nz,8), intent(in) :: Ref ! reference varaibles: rhoc, rhoz, z, zm, dz, dzm, p, pi
real, dimension(ncols+1,nz,n_prog), intent(in) :: X_old 
real, dimension(ncols+1,nz,n_prog), intent(inout) :: X ! mf, th, qv, qc, nc, qr, nr, qi, ni, qrim, brim

! local variables
integer, parameter :: nCat = 1 ,&                ! the number of ice categories
                      n_diag_2d = 1 ,&           ! size of 2d diagnostic array
                      n_diag_3d = 1              ! size of 3d diagnostic array
logical, parameter :: log_predictNc = .True.  ,& ! predict cloud droplet number or not
                      typeDiags_ON  = .False. ,& ! diagnose ice types or not
                      debug_on      = .False. ,& ! debug mode
                      scpf_on       = .False. ,& ! cloud fraction version not used
                      trplMomI      = .False. ,& ! triple moment ice
                      liqfrac       = .False. ,& ! liquid fraction ice
                      abort_on_err  = .False.  ,& ! program aborts when encountering error
                      dowr          = .True.     ! print message or not
real, parameter :: scpf_pfrac    = 0. ,&   ! dummy variable (not used), set to 0
                   scpf_resfact  = 0. ,&   ! dummy variable (not used), set to 0
                   clbfact_dep   = 1. ,&   ! calibration for deposition
                   clbfact_sub   = 1.      ! calibration for sublimation
character(3), parameter :: model = "ACE"
integer :: i,j,k,stat
real, dimension(ncols,nz) :: qc,nc,qr,nr,th_old,th,qv_old,qv, &
                             qitot,qirim,qiliq,ni,birim,zi,ssat,w,p,dz, &
                             diag_ze,diag_effc,diag_effi,diag_vmi,diag_di,diag_rhoi,cldfrac
real, dimension(ncols,n_diag_2d) :: diag_2d
real, dimension(ncols,nz,n_diag_3d) :: diag_3d
real, dimension(ncols) :: precip_liq,precip_sol

if (p3%first) then
  if (p3_context_claimed) error stop 'Only one P3 context per fresh process is supported'
  call p3_init(trim(p3%directory),ncat,trplMomI,liqfrac,trim(model),stat,abort_on_err,dowr)
  if (stat/=0) stop "Failure of p3 initialization"
  p3%first = .False.
  p3_context_claimed=.true.
endif

th_old = X_old(1:ncols,:,2)
qv_old = X_old(1:ncols,:,3)

th    = X(1:ncols,:,2)
qv    = X(1:ncols,:,3)
qc    = X(1:ncols,:,4)
nc    = X(1:ncols,:,5)
qr    = X(1:ncols,:,6)
nr    = X(1:ncols,:,7)
qitot = X(1:ncols,:,8)
ni    = X(1:ncols,:,9)
qirim = X(1:ncols,:,10)
birim = X(1:ncols,:,11)

do k=1,nz
  dz(:,k)   = Ref(k,5)
  p(:,k)    = Ref(k,7)
enddo

zi    = 0.
ssat  = 0.
w     = 0.
qiliq = 0.

call p3_main(qc,nc,qr,nr,th_old,th,qv_old,qv,dt, &
             qitot,qirim,qiliq,ni,birim,zi,ssat,w, &
             p,dz,p3%itt,precip_liq,precip_sol, &
             1,ncols,1,nz,nCat, &
             diag_ze,diag_effc,diag_effi,diag_vmi,diag_di,diag_rhoi, &
             n_diag_2d,diag_2d,n_diag_3d,diag_3d,log_predictNc,trim(model), &
             clbfact_dep,clbfact_sub, &
             debug_on,scpf_on,scpf_pfrac,scpf_resfact,cldfrac,     &
             trplMomI,liqfrac)


if (global_status == -1) stop "p3 stop"

X(1:ncols,:,2)  = th
X(1:ncols,:,3)  = qv
X(1:ncols,:,4)  = qc
X(1:ncols,:,5)  = nc
X(1:ncols,:,6)  = qr
X(1:ncols,:,7)  = nr
X(1:ncols,:,8)  = qitot
X(1:ncols,:,9)  = ni
X(1:ncols,:,10) = qirim
X(1:ncols,:,11) = birim

p3%itt = p3%itt + 1

end subroutine p3_wrapper_ace


function theta_e(T,q,ql,qi,p)
implicit none

real, parameter :: Rd=287.04, Rv=461.5, Cpd=1005.7, Cl=4190., Cvd=719. &
                  ,Cvv=1410., Cpv=1870., Cpvmcl=Cl-Cpv, EPS=0.621971830985916
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

Cpl = 1005.7 + qt*3184.3;

chi = Re/Cpl;
gamma = Rv*q / Cpl;
gammi = (Cl-Ci(T0)) * qi /Cpl;

theta_e = T * (P0*R/p/Re)**chi * (es/e)**gamma * (T0/T)**gammi * exp( (q*Lv(T)/T - Lf*qi/T0)/Cpl )

end function theta_e

 
subroutine inv_theta_e(theta_e,qt,p,T,q,ql,qi)
implicit none

! parameters
real, parameter :: Rd=287.04, Rv=461.5, Cpd=1005.7, Cl=4190., Cvd=719. &
                  ,Cvv=1410., Cpv=1870., Cpvmcl=Cl-Cpv, EPS=0.621971830985916
real, parameter :: Lv0=2.501e6, Ls=2.834e6, Lf=0.3337e6, T0=273.1636783445389, P0=1.e5 &
                  ,qT0=611.3902114165171, LvoT=9155.566660243245
real, parameter :: tol=1e-3

! input/output variables 
real, intent(in) :: theta_e,qt,p
real, intent(out) :: T,q,ql,qi

! local variables
integer :: ice
real :: Cpl,Re,chi,F0,FT0,F,dFdT,R,e,gamma,dT,qc
real :: G0,qsat,qsi,qs,dC,HT0,GT0,tmp,G,H,es,esi,dTqs,dTqsi,dGdT,dHdT,lv_over_t

Cpl = 1005.7 + 3184.3*qt
Re = Rd*(1-qt)
chi = Re/Cpl

! Step 1: solve assuming no condensate & check consistency
R = Re + Rv*qt
gamma = Rv*qt / Cpl
e = p*qt / (0.621971830985916+0.378028169014084*qt)

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
  F = T * eval_es(T,ice) **gamma * exp(qt/Cpl*Lv(T)/T)
  if (ice==0) then
    dFdT = ( 1. - CPVMCL*qt/CPL)/T
  else
    dFdT = ( 1. - 300708.*qt/CPL/T )/T
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
  HT0 = T0 * (RE+RV*qsi)**chi * exp( (qsi*2.500968266240670e6-Lf*(qt-qsi))/Cpl/T0 )
  !qs = qv_sat(T0,p,0) * ( 1. - qt )
  qs = eval_qs(T0,p,qt,0)
  GT0 = T0 * (RE+RV*qs)**chi * exp(qs*9155.566660243245/CPL)

  ! 3 cases: liquid-only, ice-only, co-existing
  if (G0>GT0 .and. G0>HT0) then ! liquid-only
    ! estimate initial T
    tmp = log(qt*p) - 5.939876353793538
    T = 237.3*tmp/(17.27-tmp) + 273.15

    dT = 9999.
    do while (abs(dT)>tol)
      !qs = qv_sat(T,p,0)*(1.-qt)
      qs = eval_qs(T,p,qt,0)
      R = Re + Rv*qs
      lv_over_t = Lv(T)/T
      G = T * R**chi *exp(qs*lv_over_t/Cpl)
      !es = polysvp1(T,0)
      es = eval_es(T,0)
      dTqs = EPS*p*(1.-qt)/(p-es)**2.*(6743.769/T-4.8451)*es/T
      dGdT = 1./T + ( (Rv*Re/R+lv_over_t)*dTqs - 1867292.*qs/T**2. )/Cpl
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
    tmp = log(qt*p) - 5.939876353793538
    T = 265.5*tmp/(21.875-tmp) + 273.16

    dT = 9999.
    do while (abs(dT)>tol)
      !qsi = qv_sat(T,p,1)*(1.-qt)
      qsi = eval_qs(T,p,qt,1)
      R = Re + Rv*qsi
      qi = qt-qsi
      lv_over_t = Lv(T)/T
      H = T * R**chi * (T0/T)**(dC*qi/Cpl) * exp((qsi*lv_over_t - Lf/T0*qi)/Cpl)
      !esi = polysvp1(T,1)
      esi = eval_es(T,1)
      dTqsi = EPS*p*(1.-qt)/(p-esi)**2.*(6111.72784/T+0.15215)*esi/T
      dHdT = 1./T + ( ( Rv*Re/R + lv_over_t + dC*log(T/T0) + 1221.611899584641 )*dTqsi &
                     - ( (1867292./T-dC)*qsi + dC*qt )/T )/Cpl
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

! Ice heat-capacity fit is referenced to 0 deg C, as in MATLAB ci(T).
real, parameter :: T0=273.15
real, intent(in) :: T
real :: Ci

Ci = 2106 + 7.3*(T - T0)

end function


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
integer :: i,ip,im,imm
real, dimension(k+1,n) :: beta, alpha, w
real, dimension(k+1) :: d,weights

v_weno=0.
if (k==2) then

! Match MATLAB reconstruction_weno_vec's written weights and grouping.
d = (/ 0., 0.666666666666667, 0.333333333333333 /)

do i=1,n
  ip=modulo(i,n)+1; im=modulo(i-2,n)+1; imm=modulo(i-3,n)+1
  beta(:,i) = (/ v(ip)-v(i), v(i)-v(im), v(im)-v(imm) /) ** 2.
  weights=d
  if (c(i)<0.) weights=d(3:1:-1)
  alpha(:,i) = weights / (eps + beta(:,i)) ** p
  w(:,i) = alpha(:,i) / sum(alpha(:,i),1)

  v_weno(i) = w(1,i) * ( 1.5*v(i)-0.5*v(ip)) &
             +w(2,i) * ( 0.5*(v(im)+v(i)) ) &
             +w(3,i) * (-0.5*v(imm)+1.5*v(im))
enddo

! MATLAB retains the circular reconstruction for negative flow at level 2.
! Positive/zero flow uses the first scalar value; surface flux is zeroed later.
i=k
if (c(i)>=0.) v_weno(i) = v(i-1)

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
  c_up3(i) =  up3 + merge(sign(1.,up3),0.,up3/=0.) * ( 3. * ( c(i) - c(i+1) ) + c(i+2) - c(i-1) )
enddo

do i=n-1,n
  up3=7.*(c(i)+c(modulo(i,n)+1))-c(i-1)-c(modulo(i+1,n)+1)
  c_up3(i)=up3+merge(sign(1.,up3),0.,up3/=0.)*(3.*(c(i)-c(modulo(i,n)+1))+c(modulo(i+1,n)+1)-c(i-1))
enddo

! surface BC modification
up3 = 8. * c(2) - c(3) 
c_up3(1) = up3 + merge(sign(1.,up3),0.,up3/=0.) * ( c(3) - 2. * c(2) )

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


subroutine model_initialize(self,shared_input,input_file,p3_directory,n_weno,physics,dt,intervals,intervals_set, &
                            ncols,nz,ncoarse,n_prog,khn26_case,precipitation_enabled,turn_off_DHv_input,turn_off_DHh_input)
use ace_input, only: read_case_metadata, read_case_profile, read_case_geometry
use iso_fortran_env, only: real64
class(ace_t), intent(inout) :: self
logical, intent(in) :: shared_input, intervals_set
character(*), intent(in) :: input_file,p3_directory
integer, intent(in) :: n_weno
character(*), intent(inout) :: physics
real, intent(inout) :: dt
integer, intent(inout) :: intervals
integer, intent(out) :: ncols,nz,ncoarse,n_prog
logical, intent(out) :: khn26_case,precipitation_enabled
logical, intent(in), optional :: turn_off_DHv_input,turn_off_DHh_input
real, parameter :: Rd=287.04, Cp=1005.7, g=9.80665, p0=1.e5
integer :: i,k,record_length,io_status
real :: dz,dum1
real(real64) :: input_lx,input_ly,input_dz
character(64) :: geometry
! Each object is initialized once; its damping cache is built on first use.
! P3 wrapper options/clock are local; the library permits one context per process.
if (shared_input) then
  call read_case_metadata(trim(input_file),nz,ncols,ncoarse,geometry)
else
  nz=801; ncols=8; ncoarse=200; geometry='annular'
endif
khn26_case=shared_input .and. trim(geometry)=='slab'
if (len_trim(physics)==0) then
  physics='p3'
  if (khn26_case) physics='native'
endif
if (physics/='native' .and. physics/='none' .and. physics/='p3') error stop 'Invalid --physics'
n_prog=3
if (physics=='p3') n_prog=11
precipitation_enabled=physics/='none'
if (dt==0.) then
  dt=2.
  if (khn26_case) dt=6.
endif
if (khn26_case .and. .not.intervals_set) intervals=480
allocate(self%input_profile(nz,12),self%diameters(7),self%input_area(ncols),self%input_perimeter(ncols))
allocate(self%input_coarse_z(ncoarse),self%input_coarse_ze(ncoarse+1),self%tmp(nz))
if (shared_input) then
  call read_case_profile(trim(input_file),self%input_profile,self%diameters,input_lx,input_ly,input_dz, &
                         self%input_coarse_z,self%input_coarse_ze)
  call read_case_geometry(trim(input_file),self%input_area,self%input_perimeter)
else
  self%input_profile=0.
  inquire(iolength=record_length) self%tmp
  open(20,file='./input_data/ini_manus_208.dat',access='direct',recl=record_length,status='old',iostat=io_status)
  if (io_status/=0) error stop 'Cannot open legacy initial profile'
  do k=5,12
    read(20,rec=k,iostat=io_status) self%input_profile(:,k)
    if (io_status/=0) error stop 'Cannot read legacy initial profile'
  enddo
  close(20)
  input_dz=50.; input_lx=64000.; input_ly=64000.
  self%diameters=[5000.d0,10000.d0,15000.d0,25000.d0,35000.d0,45000.d0,55000.d0]
  self%input_area(1:7)=self%diameters
  self%input_perimeter(1:7)=4*atan(1.d0)*self%diameters
  self%input_perimeter(8)=2*(input_lx+input_ly)
  self%input_area(8)=input_lx*input_ly-atan(1.d0)*self%diameters(7)**2
  do i=7,2,-1
    self%input_area(i)=atan(1.d0)*(self%diameters(i)**2-self%diameters(i-1)**2)
  enddo
  self%input_area(1)=atan(1.d0)*self%diameters(1)**2
  do k=1,ncoarse
    self%input_coarse_z(k)=self%input_profile((k-1)*4+1,6)
    self%input_coarse_ze(k)=self%input_coarse_z(k)
  enddo
  self%input_coarse_ze(ncoarse+1)=40000.
endif

allocate(self%X(ncols+1,nz,n_prog),self%Ref(nz,8),self%forcing(ncols,nz))
allocate(self%Tr(ncols,nz),self%q(ncols,nz),self%ql(ncols,nz),self%qi(ncols,nz))
allocate(self%A(ncols+1),self%B(ncols+1),self%Tv0(nz),self%z(nz),self%zm(nz),self%rho_e(nz),self%rho_zm(nz),self%the_e(nz),self%q_e(nz),self%p_z(nz))
allocate(self%coarse_z(ncoarse),self%coarse_ze(ncoarse+1))
self%A(1:ncols)=real(self%input_area,kind(self%A)); self%B(1:ncols)=real(self%input_perimeter,kind(self%B))
self%A(ncols+1)=self%A(ncols); self%B(ncols+1)=self%B(ncols)
dz=real(input_dz,kind(dz))
self%rho_zm=real(self%input_profile(:,5),kind(self%rho_zm)); self%zm=real(self%input_profile(:,6),kind(self%zm))
self%the_e=real(self%input_profile(:,7),kind(self%the_e)); self%q_e=real(self%input_profile(:,8),kind(self%q_e))
self%p_z=real(self%input_profile(:,10),kind(self%p_z)); self%rho_e=real(self%input_profile(:,11),kind(self%rho_e))
self%z=real(self%input_profile(:,12),kind(self%z))
self%coarse_z=real(self%input_coarse_z,kind(self%coarse_z)); self%coarse_ze=real(self%input_coarse_ze,kind(self%coarse_ze))
self%forcing=0.
self%X=0.
! Convert shared theta_e/qt input once; the P3 state stores th and qv.
do k=1,nz
  self%Ref(k,1)=self%rho_e(k); self%Ref(k,2)=self%rho_zm(k)
  self%Ref(k,3)=self%z(k); self%Ref(k,4)=self%zm(k)
  self%Ref(k,5)=dz; self%Ref(k,6)=dz; self%Ref(k,7)=self%p_z(k)
  self%Ref(k,8)=(self%p_z(k)/p0)**(Rd/Cp)
  call inv_theta_e(self%the_e(k),self%q_e(k),self%Ref(k,7),self%Tr(1,k),self%q(1,k),self%ql(1,k),self%qi(1,k))
  self%Tv0(k)=real(self%input_profile(k,9),kind(self%Tv0))
  if (khn26_case) self%Tv0(k)=self%Tr(1,k)*(1.+0.607789855072462*self%q(1,k)-self%ql(1,k)-self%qi(1,k))
  if (n_prog==3) then
    self%X(:,k,2)=self%the_e(k); self%X(:,k,3)=self%q_e(k)
  else
    self%X(:,k,2)=self%Tr(1,k)/self%Ref(k,8); self%X(:,k,3)=self%q(1,k)
    ! Preserve reconstructed total water when mapping the environment to P3.
    self%X(:,k,4)=self%ql(1,k); self%X(:,k,8)=self%qi(1,k)
  endif
enddo
if (khn26_case) then
  ! KHN26 +0.25 K saturated bubble in ACE 1, one-based levels 11..51.
  do k=11,min(51,nz)
    dum1=self%Tr(1,k)+0.25
    self%q(1,k)=eval_qs(dum1,self%p_z(k),0.,merge(1,0,dum1<273.1636783445389))
    self%q(1,k)=self%q(1,k)/(1.+self%q(1,k)) ! condensate-free saturation specific humidity
    if (n_prog==3) then
      self%X(1,k,2)=theta_e(dum1,self%q(1,k),0.,0.,self%p_z(k)); self%X(1,k,3)=self%q(1,k)
    else
      self%X(1,k,2)=dum1/self%Ref(k,8); self%X(1,k,3)=self%q(1,k)
      self%X(1,k,4)=0.; self%X(1,k,8)=0.
    endif
  enddo
else
  do k=1,nz
    if (self%zm(k)<=1000.) self%X(1,k,1)=0.3*sin(4.*atan(1.)*self%zm(k)/1000.)
  enddo
endif
call set_p3_context_directory(self%p3,trim(p3_directory))
if (shared_input) then
  call ace_initialization_context(self%response,self%thermal,ncols,nz,ncoarse,self%coarse_z,self%coarse_ze,trim(input_file),self%Tv0,netcdf_input=.true., &
       turn_off_DHv_input=turn_off_DHv_input,turn_off_DHh_input=turn_off_DHh_input)
else
  call ace_initialization_context(self%response,self%thermal,ncols,nz,ncoarse,self%coarse_z,self%coarse_ze,'./input_data/PMB.dat',self%Tv0)
endif

self%ncols=ncols; self%nz=nz; self%n_prog=n_prog; self%n_weno=n_weno
self%dt=dt; self%t=0.
self%precipitation_enabled=precipitation_enabled
end subroutine model_initialize

subroutine model_integrate(self,te,reset_clock_to_target)
class(ace_t), intent(inout) :: self
real, intent(in) :: te
logical, intent(in), optional :: reset_clock_to_target
call ace_driver_context(self%response,self%thermal,self%damping,self%p3,self%ncols,self%nz,self%n_weno,self%n_prog, &
                        self%X,self%Ref,self%A,self%B,self%t,te,self%dt,self%forcing,self%precipitation_enabled)
! Preserve the historical interval driver's explicit ts=te assignment.
! Standalone integration retains its full-dt clock, including target overshoot.
if (present(reset_clock_to_target)) then
  if (reset_clock_to_target) self%t=te
endif
end subroutine model_integrate

! Allocate buffers without calculating diagnostics or touching model state.
subroutine model_prepare_diagnostics(self)
class(ace_t), intent(inout) :: self
if (.not.allocated(self%diagnostics%Xout)) then
  allocate(self%diagnostics%Xout(self%ncols+1,self%nz,11))
  allocate(self%diagnostics%Tr(self%ncols,self%nz),self%diagnostics%q(self%ncols,self%nz), &
           self%diagnostics%ql(self%ncols,self%nz),self%diagnostics%qi(self%ncols,self%nz), &
           self%diagnostics%rh4(self%ncols,self%nz),self%diagnostics%b4(self%ncols,self%nz))
endif
end subroutine model_prepare_diagnostics

subroutine model_open_output(self,filename)
class(ace_t), intent(inout) :: self
character(*), intent(in) :: filename
integer :: record_length,io_status
if (self%output_open) error stop 'Model output is already open'
call model_prepare_diagnostics(self)
! Preserve the nine-field real32 layout and compiler-independent record sizing.
inquire(iolength=record_length) self%diagnostics%Xout(1:self%ncols,:,1:3),self%diagnostics%Xout(1:self%ncols,:,4), &
                              self%diagnostics%Xout(1:self%ncols,:,6),self%diagnostics%Xout(1:self%ncols,:,8), &
                              self%diagnostics%Xout(1:self%ncols,:,10),self%diagnostics%rh4,self%diagnostics%b4
open(newunit=self%output_unit,file=trim(filename),access='direct',form='unformatted',status='new',recl=record_length,iostat=io_status)
if (io_status/=0) error stop 'Cannot open model output; provide an existing output directory'
self%output_record=1
self%output_open=.true.
end subroutine model_open_output

subroutine model_output(self)
class(ace_t), intent(inout) :: self
if (.not.self%output_open) error stop 'Model output is not open'
call self%diagnose()
write(self%output_unit,rec=self%output_record) self%diagnostics%Xout(1:self%ncols,:,1:3),self%diagnostics%Xout(1:self%ncols,:,4), &
                 self%diagnostics%Xout(1:self%ncols,:,6),self%diagnostics%Xout(1:self%ncols,:,8), &
                 self%diagnostics%Xout(1:self%ncols,:,10),self%diagnostics%rh4,self%diagnostics%b4
self%output_record=self%output_record+1
end subroutine model_output

subroutine model_close_output(self)
class(ace_t), intent(inout) :: self
if (.not.self%output_open) error stop 'Model output is not open'
close(self%output_unit)
self%output_open=.false.
end subroutine model_close_output

subroutine model_diagnose(self,Xout,rh4,b4)
class(ace_t), intent(inout) :: self
! Optional diagnostic copies remain available; no aliases escape.
real(kind=4), intent(out), optional :: Xout(:,:,:),rh4(:,:),b4(:,:)
integer :: i,k
real :: dum1
call model_prepare_diagnostics(self)
self%diagnostics%Xout=0.
self%diagnostics%Xout(:,:,1:self%n_prog)=self%X
do k=1,self%nz
  do i=1,self%ncols
    if (self%n_prog==3) then
      call inv_theta_e(self%X(i,k,2),self%X(i,k,3),self%Ref(k,7),self%diagnostics%Tr(i,k),self%diagnostics%q(i,k),self%diagnostics%ql(i,k),self%diagnostics%qi(i,k))
      self%diagnostics%Xout(i,k,4)=self%diagnostics%ql(i,k); self%diagnostics%Xout(i,k,8)=self%diagnostics%qi(i,k)
    else
      self%diagnostics%Tr(i,k)=self%X(i,k,2)*self%Ref(k,8)
      self%diagnostics%q(i,k)=self%X(i,k,3); self%diagnostics%ql(i,k)=self%X(i,k,4)+self%X(i,k,6); self%diagnostics%qi(i,k)=self%X(i,k,8)
    endif
    self%diagnostics%rh4(i,k)=self%diagnostics%q(i,k)/eval_qs(self%diagnostics%Tr(i,k),self%Ref(k,7),self%diagnostics%q(i,k)+self%diagnostics%ql(i,k)+self%diagnostics%qi(i,k),merge(1,0,self%diagnostics%Tr(i,k)<273.1636783445389))
    dum1=self%diagnostics%Tr(i,k)*(1.+0.607789855072462*self%diagnostics%q(i,k)-self%diagnostics%ql(i,k)-self%diagnostics%qi(i,k))
    self%diagnostics%b4(i,k)=g*(dum1-self%Tv0(k))/self%Tv0(k)
  enddo
enddo
if (present(Xout)) Xout=self%diagnostics%Xout
if (present(rh4)) rh4=self%diagnostics%rh4
if (present(b4)) b4=self%diagnostics%b4
end subroutine model_diagnose

subroutine model_with_legacy_state(self,action)
class(ace_t), intent(inout) :: self
interface
  subroutine action(X,Ref,A,B,forcing,Tv0,input_coarse_z,input_coarse_ze,response)
    use iso_fortran_env, only: real64
    import ace_response_t
    type(ace_response_t), intent(inout) :: response
    real, intent(inout) :: X(:,:,:),forcing(:,:)
    real, intent(in) :: Ref(:,:),A(:),B(:),Tv0(:)
    real(real64), intent(in) :: input_coarse_z(:),input_coarse_ze(:)
  end subroutine action
end interface
! Synchronous bridge for validation/serialization until output extraction.
! Integration calls occur outside the callback; no pointers or state copies escape.
call action(self%X,self%Ref,self%A,self%B,self%forcing,self%Tv0,self%input_coarse_z,self%input_coarse_ze,self%response)
end subroutine model_with_legacy_state

end module ace_module 
