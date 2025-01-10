module ace_module
implicit none

private
public :: weno, weno_vec, inv_theta_e, pchip, theta_e, ace_driver, ace_initialization, eval_qs, condensation

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

integer :: coarse_nz
real, dimension(:), allocatable :: coarse_z, coarse_ze
real, dimension(:,:), allocatable :: coarse_F
real, dimension(:,:), allocatable :: dwdt
real*8, dimension(:,:,:,:), allocatable :: PMB
real, dimension(:,:), allocatable, save :: Ta, q, ql, qi

contains

subroutine ace_driver(ncols,nz,n_weno,n_prog,X,Ref,A,B,t,te,dt,B_forcing)
implicit none

! input/output variables
integer, intent(in) :: ncols,nz,n_weno,n_prog
real, dimension(ncols), intent(in) :: A, B
real, dimension(nz,7), intent(in) :: Ref
real, dimension(ncols+1,nz,n_prog), intent(inout) :: X
real, intent(inout) :: t
real, intent(in) :: te,dt
real, dimension(ncols,nz), intent(in) :: B_forcing

! local variables
real, dimension(ncols+1,nz,n_prog) :: yi
real, dimension(ncols,nz,n_prog) :: K1,K2,tmp
real :: dum1
integer :: i,k

yi = X

do while ( t < te)
  do i=1,ncols
  do k=1,nz
    dum1 = ( Ref(k,7) / 1.e5 ) ** ( 2. / 7. )
    Ta(i,k) = X(i,k,2) * dum1
    q(i,k) = X(i,k,3)
    ql(i,k) = X(i,k,4)
    qi(i,k) = X(i,k,5)
    call condensation(Ta(i,k),q(i,k),ql(i,k),qi(i,k),Ref(k,7))
    X(i,k,2) = Ta(i,k) / dum1
    X(i,k,3) = q(i,k)
    X(i,k,4) = ql(i,k)
    X(i,k,5) = qi(i,k)
  enddo
  enddo

  ! update ace tendency
  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,X,Ref,K1,1)
  yi(1:ncols,:,:) = X(1:ncols,:,:) + K1 * dt / 6.

  write(*,*) K1(1,1:15,1)

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,K2,2)
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,3)
  K2 = K2 + tmp
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,4)
  K2 = K2 + tmp
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,5)
  K2 = K2 + tmp
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 + K2 ) * dt / 6.

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,6)
  K2 = ( K2 + tmp ) / 15.
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt 

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,7)
  K1 = K1 + tmp 
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt 

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,8)
  K1 = K1 + tmp 
  yi(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt 

  call ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,yi,Ref,tmp,9)
  K1 = K1 + tmp

  X(1:ncols,:,:) = X(1:ncols,:,:) + ( K1 / 6. + K2 ) * dt

  ! call physics here
  call precip_sinks(ncols,nz,n_prog,Ref(1:nz,7),K1(:,:,1:2)) ! simplified precipitation
  X(1:ncols,:,2:n_prog) = X(1:ncols,:,2:n_prog) +  K1(:,:,1:2) * dt

  ! implicit damping 
  call ImDamp(ncols,nz,n_prog,X,Ref,dt)


  t = t + dt
enddo


endsubroutine ace_driver


subroutine ace_initialization(ncols,nz,nz_presolve,z_presolve,ze_presolve,fname)
implicit none

! input variables
integer, intent(in) :: ncols, nz, nz_presolve
real, dimension(nz_presolve) :: z_presolve
real, dimension(nz_presolve+1) :: ze_presolve
character(*), intent(in) :: fname

! local variables
integer :: i,j,k,n

coarse_nz=nz_presolve
allocate(coarse_z(coarse_nz),coarse_ze(coarse_nz+1))
allocate(coarse_F(ncols,coarse_nz))
allocate(PMB(ncols,ncols,coarse_nz,coarse_nz+1))
allocate(dwdt(ncols,coarse_nz+1))
allocate(Ta(ncols,nz),q(ncols,nz),ql(ncols,nz),qi(ncols,nz))


open(10,file=trim(fname),access="direct",recl=(coarse_nz+1)*2)
n=1
do k=1,ncols
do j=1,ncols
  do i=1,coarse_nz
    read(10,rec=n) PMB(k,j,i,:)
    n=n+1
  enddo
enddo
enddo
close(10)

coarse_z = z_presolve
coarse_ze = ze_presolve

end subroutine ace_initialization


subroutine ace_tendency(ncols,nz,n_weno,n_prog,dt,A,B,X,Ref,dXdt,rkstage)
implicit none

! input/output variables
integer, intent(in) :: ncols, nz, n_weno, n_prog, rkstage
real, intent(in) :: dt
real, dimension(ncols), intent(in) :: A, B ! ACE area and ACE outer perimeter [km^2, km]
real, dimension(nz,7), intent(in) :: Ref ! reference varaibles: rhoc, rhoz, z, zm, dz, dzm, p
real, dimension(ncols+1,nz,n_prog), intent(in) :: X ! MF, theta_e, qt
!real, dimension(ncols+1,nz,n_prog), intent(in) :: X ! MF, theta, qv, ql, qi
real, dimension(ncols,nz,n_prog), intent(out) :: dXdt 

! local variables
integer :: i,n,k,ks,ke
real :: dum1,dum2
real, dimension(ncols,nz,2) :: eps_tur
real, dimension(nz) :: rho0B, Tv, Tv0, T0, q0, ql0, qi0
real, dimension(ncols,nz,3) :: dXdz
real, dimension(ncols,nz,2:n_prog) :: Ci, rho0wC
real, dimension(ncols+1,nz) :: mfc, Wc
real, dimension(ncols,nz) ::Wi, Admfdz, ioflow, F


! initialization
do k=1,nz
  eps_tur(:      ,k,1) = nju*B/A
  eps_tur(2:ncols,k,2) = nju*B(1:ncols-1)/A(2:ncols)
  !call inv_theta_e(X(ncols+1,k,2),X(ncols+1,k,3),Ref(k,7),T0(k),q0(k),ql0(k),qi0(k))
  !Tv0(k) = T0(k) * ( 1. + 0.607789855072462 * q0(k) - ql0(k) - qi0(k) )
  Tv0(k) = X(ncols+1,k,2) * ( Ref(k,7) / 1.e5 ) ** ( 2. / 7. )  &
           * ( 1. + 0.607789855072462 * X(ncols+1,k,3) - X(ncols+1,k,4) - X(ncols+1,k,5) )
enddo

! fill with zeros
dXdt = 0.
mfc = 0.
Wc = 0.

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

do i=1,ncols
  do n=2,n_prog
    dXdt(i,1:nz  ,n) = 0.
    dXdt(i,1:nz-1,n) = - ( rho0wC(i,2:nz,n) - rho0wC(i,1:nz-1,n) ) / Ref(1:nz-1,5) / Ref(1:nz-1,1)  ! vertical flux convergence

    dXdt(i,1:nz-1,n) = dXdt(i,1:nz-1,n) - eps_tur(i,1:nz-1,1) * ( X(i,1:nz-1,n) - X(i+1,1:nz-1,n) )  ! interact outer
    if (i>1) &
    dXdt(i,1:nz-1,n) = dXdt(i,1:nz-1,n) - eps_tur(i,1:nz-1,2) * ( X(i,1:nz-1,n) - X(i-1,1:nz-1,n) )  ! interact inner

    dXdt(i,1:nz-1,n) = dXdt(i,1:nz-1,n) + 0.5 * &
                       ( ( ioflow(i  ,1:nz-1) + abs(ioflow(i  ,1:nz-1)) ) * X(i+1,1:nz-1,n) &
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

  !if (rkstage==1) then
  !  do k=1,nz
  !    !call inv_theta_e(X(i,k,2),X(i,k,3),Ref(k,7),Ta(i,k),q(i,k),ql(i,k),qi(i,k))
  !  enddo
  !endif

  Tv(1:nz) = Ta(i,1:nz) * ( 1. + 0.607789855072462 * q(i,1:nz) - ql(i,1:nz) - qi(i,1:nz) )
  if (i==1 .and. rkstage==1) then
    write(*,*) Ta(i,1:15)
    write(*,*) (Tv(1:15) - Tv0(1:15))*1e6
  endif
  rho0B(1:nz) = g * Ref(1:nz,1) * ( Tv(1:nz) - Tv0(1:nz) ) / Tv0(1:nz)

  F(i,1:nz) = F(i,1:nz) + rho0B(1:nz)

  !call pchip(nz,Ref(1:nz,4),F(i,1:nz),coarse_nz,coarse_z,coarse_F(i,1:coarse_nz),.True.)
  coarse_F(i,:) = sum(reshape(F(i,1:nz),(/4,nz/4/)),1)/4.
enddo

do i=1,ncols
  do k=1,coarse_nz+1
    dwdt(i,k) = sum( sum( PMB(i,:,:,k) * coarse_F(:,:) , 2 ), 1 )  
  enddo

  call pchip(coarse_nz+1,coarse_ze,dwdt(i,1:coarse_nz+1),nz,Ref(1:nz,4),dXdt(i,1:nz,1),.True.)
enddo  

! single ACE
dXdt(2:ncols,:,:)=0.

! model top 
dXdt(:,nz-10:nz,:)=0.


end subroutine ace_tendency

 
subroutine ImDamp(ncols,nz,n_prog,X,Ref,dt)
implicit none

! input/output variables
integer, intent(in) :: ncols,nz,n_prog
real, intent(in) :: dt
real, dimension(ncols+1,nz,n_prog), intent(inout) :: X
real, dimension(nz,7), intent(in) :: Ref

! local variable
integer :: i,k,n
real, dimension(:), allocatable, save :: damp
logical, save :: first = .True.

if (first) then
  allocate(damp(nz))
  do k=1,nz
    damp(k) = dt * exp( ( Ref(k,3) - Ref(nz,3) ) / SLD ) / SLTau
  enddo
  first = .False.
endif

do k=1,nz
  do i=1,ncols
    X(i,k,1) = X(i,k,1) / ( 1. + damp(k) / Ref(k,2) )
    do n=2,n_prog
      X(i,k,n) = ( X(i,k,n) + damp(k) * X(ncols+1,k,n) / Ref(k,1) ) / ( 1. + damp(k) / Ref(k,1) )
    enddo
  enddo
enddo

end subroutine ImDamp

subroutine precip_sinks(ncols,nz,n_prog,p,dXdt)
implicit none

! input/output variables
integer, intent(in) :: ncols,nz,n_prog
real, dimension(nz), intent(in) :: p
real, dimension(ncols,nz,n_prog-1), intent(inout) :: dXdt

! local variables
integer :: i,k
real :: qc, dql, dqi


do k=1,nz
do i=1,ncols
  qc = ql(i,k) + qi(i,k)
  !!!!dqt(i,k) = - ( qc_ramp / dqc / tau_pr ) * log( 1. + exp( dqc / qc_ramp * ( qc - qc_ramp ) ) ) ! should use -r8 to compile
  !dXdt(i,k,2) = - ( qc_ramp / dqc / tau_pr ) * max( dqc / qc_ramp * ( qc - qc_ramp ) , 0. ) 
  !dql = 1.e-8 * ql(i,k) / qc
  !dqi = 1.e-8 * qi(i,k) / qc
  !dXdt(i,k,1) = dXdt(i,k,2) * ( theta_e(Ta(i,k),q(i,k),ql(i,k)+dql,qi(i,k)+dqi,p(k)) &
  !                            - theta_e(Ta(i,k),q(i,k),ql(i,k),qi(i,k),p(k)) ) / 1.e-8

  dXdt(i,k,1) = 0.
  dXdt(i,k,2) = 0.
  dql = - ( qc_ramp / dqc / tau_pr ) * max( dqc / qc_ramp * ( qc - qc_ramp ) , 0. )
  dXdt(i,k,3) = dql * ql(i,k) / qc
  dXdt(i,k,4) = dql * qi(i,k) / qc
  if ( qc <= 0. ) then
    dXdt(i,k,:) = 0.
  endif 
enddo
enddo

end subroutine precip_sinks

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


subroutine condensation(T,q,ql,qi,p)
implicit none

! parameters
real, parameter :: Rd=287.04, Rv=461.5, Cpd=1005.7, Cl=4190., Cvd=719. &
                  ,Cvv=1410., Cpv=1870., Cpvmcl=Cl-Cpv, EPS=Rd/Rv
real, parameter :: Lv0=2.501e6, Ls=2.834e6, Lf=0.3337e6, T0=273.1636783445389, P0=1.e5 &
                  ,qT0=611.3902114165171, LvoT=9155.566660243245
real, parameter :: tol=1e-3

! input/output variables
real, intent(in) :: p
real, intent(inout) :: T,q,ql,qi

! local variables
integer :: ice
real :: Cpl,Re,chi,R,e,dT,qc,qt,the
real :: G0,qsat,qsi,qs,dC,HT0,GT0,tmp,G,H,es,esi,dTqs,dTqsi,dGdT,dHdT

qt = q + ql + qi
if ( qt < 0. ) then
  write(*,*) "nagative qt"
  stop
endif
the = theta_e(T,q,ql,qi,p)
q = qt

Cpl = Cpd + (Cl-CPd)*qt
Re = Rd*(1-qt)
chi = Re/Cpl
R = Re + Rv*qt

ice = 0
if (T<T0) ice = 1
!qsat = qv_sat(T,p,ice)*(1.-qt)
qsat = eval_qs(T,p,qt,ice)

if (q>qsat) then
  ! Step 2: determine condensate type(s) by comparing G(T0) & H(T0) to G0
  G0 = the * (p*Re/P0)**chi
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
    qi = ( Lv(T0)*q - T0*Cpl*log(the*tmp/T0) )/Lf
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

else

  q = qt
  ql = 0.
  qi = 0. 

endif

end subroutine condensation


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
