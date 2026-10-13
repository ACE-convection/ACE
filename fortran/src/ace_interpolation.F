module ace_interpolation
implicit none
private
public :: interp1, pchip, makima
contains

! Unified ACE vector interpolation. Only pchip and makima are supported.
! Default endpoint policy is cubic extrapolation, as for MATLAB interp1
! with these methods. extrap=.false. holds the nearest endpoint value.
subroutine interp1(n,x,y,n_i,x_i,y_i,method,extrap)
integer, intent(in) :: n,n_i
real, intent(in) :: x(n),y(n),x_i(n_i)
real, intent(out) :: y_i(n_i)
character(*), intent(in) :: method
logical, intent(in), optional :: extrap
logical :: extend
extend=.true.
if (present(extrap)) extend=extrap
select case(trim(method))
case('pchip')
  call pchip(n,x,y,n_i,x_i,y_i,extend)
case('makima')
  call makima(n,x,y,n_i,x_i,y_i,extrap=extend)
case default
  error stop 'interp1 supports only pchip and makima'
end select
end subroutine interp1


! Real vector/query interface for MATLAB-compatible modified Akima.
! All real arguments use the model's default real kind (real32 or real64
! according to compiler flags). No MATLAB runtime or external library needed.
subroutine makima(n,x,y,n_i,x_i,y_i,extrap)
implicit none
integer, intent(in) :: n,n_i
real, intent(in) :: x(n),y(n),x_i(n_i)
real, intent(out) :: y_i(n_i)
logical, intent(in), optional :: extrap
logical :: extend
real :: secant(-1:n+1),slope(n),left_weight,right_weight,weight_sum
real :: width,offset,quadratic,cubic
integer :: i,j,low,high,middle

! Modified Akima weights and quadratic endpoint secant extension follow
! MATLAB R2023b makima; evaluation uses cubic Hermite polynomials.
extend=.true.
if (present(extrap)) extend=extrap
if (n<2) error stop 'Makima requires at least two sample points'
if (any(x(2:n)<=x(1:n-1))) error stop 'Makima requires increasing coordinates'
do i=1,n-1
  secant(i)=(y(i+1)-y(i))/(x(i+1)-x(i))
enddo
if (n==2) then
  slope=secant(1)
else
  secant(0)=2.*secant(1)-secant(2)
  secant(-1)=2.*secant(0)-secant(1)
  secant(n)=2.*secant(n-1)-secant(n-2)
  secant(n+1)=2.*secant(n)-secant(n-1)
  do i=1,n
    left_weight=abs(secant(i-1)-secant(i-2))+abs(secant(i-1)/2.+secant(i-2)/2.)
    right_weight=abs(secant(i+1)-secant(i))+abs(secant(i+1)/2.+secant(i)/2.)
    weight_sum=left_weight+right_weight
    slope(i)=0.
    if (weight_sum>0.) slope(i)=(right_weight/weight_sum)*secant(i-1) &
                              +(left_weight/weight_sum)*secant(i)
  enddo
endif

do i=1,n_i
  if (.not.extend) then
    if (x_i(i)<x(1)) then
      y_i(i)=y(1)
      cycle
    elseif (x_i(i)>x(n)) then
      y_i(i)=y(n)
      cycle
    endif
  endif
  ! Endpoint intervals also give cubic extrapolation, matching interp1 makima.
  if (x_i(i)<=x(1)) then
    j=1
  elseif (x_i(i)>=x(n)) then
    j=n-1
  else
    low=1; high=n
    do while (high-low>1)
      middle=(low+high)/2
      if (x_i(i)<x(middle)) then
        high=middle
      else
        low=middle
      endif
    enddo
    j=low
  endif
  width=x(j+1)-x(j)
  quadratic=(3.*secant(j)-2.*slope(j)-slope(j+1))/width
  cubic=(slope(j)+slope(j+1)-2.*secant(j))/width**2
  offset=x_i(i)-x(j)
  y_i(i)=y(j)+offset*(slope(j)+offset*(quadratic+offset*cubic))
enddo
end subroutine makima

subroutine pchip(n,x,y,n_i,x_i,y_i,extrap)
implicit none

! input/output variables
integer, intent(in) :: n, n_i
real, dimension(n), intent(in) :: x, y  ! input should be monotonic increase.
real, dimension(n_i), intent(in) :: x_i
real, dimension(n_i), intent(out) :: y_i
logical, intent(in) :: extrap

! local variables
integer :: i, j, lo, hi, mid
real :: dxs,w1,w2,dmax,dmin
real :: a,b,c,h
real, dimension(n) :: d, m, dx

if (n<2) error stop 'Pchip requires at least two sample points'
if (any(x(2:n)<=x(1:n-1))) error stop 'Pchip requires increasing coordinates'
! calculate slope
d = 0.
do i=1,n-1
  dx(i) = x(i+1) - x(i)
  d(i) = ( y(i+1) - y(i) ) / dx(i)
enddo

if (n==2) then
  m=d(1) ! Two points define a line, as in MATLAB pchip.
else
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

endif

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

  ! Find the same interval without scanning from the first knot for each query.
  ! Queries need not be sorted; interpolation arithmetic is unchanged.
  lo=1
  hi=n-1
  do while (lo<hi)
    mid=(lo+hi+1)/2
    if (x(mid)<=x_i(i)) then
      lo=mid
    else
      hi=mid-1
    endif
  enddo
  j=lo
    if ( x(j)<=x_i(i) .and. x_i(i)<x(j+1) ) then
      h = x(j+1) - x(j)
      a = ( ( m(j+1) - d(j) ) / h - ( d(j) - m(j) ) / h ) / h
      b = 2. * ( d(j) - m(j) ) / h - ( m(j+1) - d(j) ) / h 
      c = m(j)

      h = x_i(i) - x(j)
      y_i(i) = a * h**3. + b * h**2. + c * h + y(j)
      goto 987
    endif
  987 continue
enddo

end subroutine pchip

end module ace_interpolation
