program test
use ace_module
use iso_fortran_env, only: real64
implicit none

integer, parameter :: n_weno=2
integer :: n_prog=11, steps=0, state_unit
logical :: khn26_case, precipitation_enabled, intervals_set=.false.
character(16) :: physics
character(1024) :: state_output
! P3 prognostics: MF, th, qv, qc, nc, qr, nr, qi, ni, qrim, brim.
! Shared theta_e/qt profiles are input metadata, converted once before integration.
integer :: i,n,t,ncols,nz,ncoarse,ndt,argument,parse_status,record_length,io_status
integer :: intervals
real :: ts,te,dt,start,finish
type(ace_t) :: model
real(kind=4), allocatable :: Xout(:,:,:),rh4(:,:),b4(:,:)
logical :: shared_input
character(1024) :: input_file,output_file,validation_file,arg,p3_directory

shared_input=.true.
input_file='../data/input/manaus1342_khn26.nc'
output_file='./ace_state.dat'
validation_file=''
p3_directory='./input_data/'
intervals=60*24*100 ! historical run length; select explicitly with --intervals
physics=''; state_output=''; dt=0.
argument=1
do while (argument<=command_argument_count())
  call get_command_argument(argument,arg)
  select case(trim(arg))
  case('--legacy-input')
    shared_input=.false.
  case('--input','--output','--validate-input','--p3-lookup-directory','--intervals','--physics','--steps','--state-output','--dt')
    block
      character(1024) :: option,value
      option=arg
      argument=argument+1
      if (argument>command_argument_count()) error stop 'Missing command argument value'
      call get_command_argument(argument,value)
      if (len_trim(value)==0) error stop 'Empty command argument value'
      select case(trim(option))
      case('--physics'); physics=value
      case('--state-output'); state_output=value
      case('--steps')
        read(value,*,iostat=parse_status) steps
        if (parse_status/=0 .or. steps<1) error stop 'Invalid --steps value'
      case('--dt')
        read(value,*,iostat=parse_status) dt
        if (parse_status/=0 .or. dt<=0.) error stop 'Invalid --dt value'
      case('--input'); input_file=value
      case('--output'); output_file=value
      case('--validate-input'); validation_file=value
      case('--p3-lookup-directory'); p3_directory=value
      case('--intervals')
        intervals_set=.true.
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

call model%initialize(shared_input,input_file,p3_directory,n_weno,physics,dt,intervals,intervals_set, &
                      ncols,nz,ncoarse,n_prog,khn26_case,precipitation_enabled)
allocate(Xout(ncols+1,nz,11))
allocate(rh4(ncols,nz),b4(ncols,nz))

if (len_trim(validation_file)>0) then
  call model%with_legacy_state(validate_model)
  stop
endif

ts=0.; ndt=nint(60./dt); te=ts+dt*real(ndt)
if (steps==0 .and. abs(dt*ndt-60.)>64*epsilon(dt)*60.) error stop 'dt must divide 60 s'
if (len_trim(state_output)>0) then
  open(newunit=state_unit,file=trim(state_output),access='stream',form='unformatted',status='new')
  write(state_unit) ncols,nz,n_prog
  call model%with_legacy_state(write_initial_state)
endif
if (steps>0) then
  do i=1,steps
    te=ts+dt
    call model%integrate(te)
    if (len_trim(state_output)>0) call model%with_legacy_state(write_saved_state)
    ts=te
  enddo
  if (len_trim(state_output)>0) close(state_unit)
  stop
endif
call cpu_time(start)
! Retain the historical nine-field real32 output, using compiler-independent record sizing.
inquire(iolength=record_length) Xout(1:ncols,:,1:3),Xout(1:ncols,:,4),Xout(1:ncols,:,6), &
                              Xout(1:ncols,:,8),Xout(1:ncols,:,10),rh4,b4
open(10,file=trim(output_file),access='direct',form='unformatted',status='new',recl=record_length,iostat=io_status)
if (io_status/=0) error stop 'Cannot open model output; provide an existing output directory'
n=1
do t=1,intervals
  call write_state()
  call model%integrate(te,reset_clock_to_target=.true.)
  if (len_trim(state_output)>0) call model%with_legacy_state(write_saved_state)
  ts=te; te=ts+dt*real(ndt)
enddo
call write_state()
close(10)
if (len_trim(state_output)>0) close(state_unit)
call cpu_time(finish)
write(*,*) 'time cost =',finish-start

contains
subroutine validate_model(X,Ref,A,B,forcing,Tv0,input_coarse_z,input_coarse_ze,response)
type(ace_response_t), intent(inout) :: response
real, intent(inout) :: X(:,:,:),forcing(:,:)
real, intent(in) :: Ref(:,:),A(:),B(:),Tv0(:)
real(real64), intent(in) :: input_coarse_z(:),input_coarse_ze(:)
if (len_trim(validation_file)>0) then
  open(30,file=trim(validation_file),access='stream',form='unformatted',status='replace')
  write(30) ncols,nz,n_prog,ncoarse
  write(30) real(X,real64),real(Ref,real64),real(A,real64),real(B,real64),real(Tv0,real64), &
            input_coarse_z,input_coarse_ze
  close(30)
endif

end subroutine validate_model

subroutine write_initial_state(X,Ref,A,B,forcing,Tv0,input_coarse_z,input_coarse_ze,response)
type(ace_response_t), intent(inout) :: response
real, intent(inout) :: X(:,:,:),forcing(:,:)
real, intent(in) :: Ref(:,:),A(:),B(:),Tv0(:)
real(real64), intent(in) :: input_coarse_z(:),input_coarse_ze(:)
write(state_unit) real(X,real64),real(Tv0,real64)
end subroutine write_initial_state

subroutine write_saved_state(X,Ref,A,B,forcing,Tv0,input_coarse_z,input_coarse_ze,response)
type(ace_response_t), intent(inout) :: response
real, intent(inout) :: X(:,:,:),forcing(:,:)
real, intent(in) :: Ref(:,:),A(:),B(:),Tv0(:)
real(real64), intent(in) :: input_coarse_z(:),input_coarse_ze(:)
write(state_unit) real(X,real64)
end subroutine write_saved_state

subroutine write_state()
call model%diagnose(Xout,rh4,b4)
write(10,rec=n) Xout(1:ncols,:,1:3),Xout(1:ncols,:,4),Xout(1:ncols,:,6), &
                 Xout(1:ncols,:,8),Xout(1:ncols,:,10),rh4,b4
n=n+1
end subroutine
end program test
