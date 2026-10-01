program fortran_mixed_replay
use ace_module, only: ace_initialization, ace_driver, ace_tendency, set_alignment_single, &
                     precip_sinks, theta_e, T, q, ql, qi, replay_unit
use ace_input, only: read_case_profile
implicit none
integer, parameter :: nz=801
real :: X(9,nz,10),base(9,nz,10),A(9),B(9),tv(nz),cz(200),ce(201)
real :: profile(nz,12),diameters(7),lx,ly,dz,forcing(8,nz),now
real :: tendency(8,nz,3),sink(8,nz,2),forward(8,nz,2),shared(8,nz,4)
real :: states(8,nz,3,60),thermo(8,nz,4,60),qc,dql,dqi
character(500) :: initial_file,input_file,state_file,thermo_file,output_file
integer :: u,s,k,i
call get_command_argument(1,initial_file)
call get_command_argument(2,input_file)
call get_command_argument(3,state_file)
call get_command_argument(4,thermo_file)
call get_command_argument(5,output_file)
open(newunit=u,file=trim(initial_file),access='stream',form='unformatted',status='old')
read(u) base,A,B,tv,cz,ce
close(u)
call read_case_profile(trim(input_file),profile,diameters,lx,ly,dz,cz,ce)
tv=profile(:,9)
call ace_initialization(8,nz,200,cz,ce,trim(input_file),tv,netcdf_input=.true.)
call set_alignment_single(.true.)
open(newunit=u,file=trim(state_file),access='stream',form='unformatted',status='old')
read(u) states
close(u)
open(newunit=u,file=trim(thermo_file),access='stream',form='unformatted',status='old')
read(u) thermo
close(u)
open(newunit=replay_unit,file=trim(output_file),access='stream',form='unformatted',status='replace')
forcing=0.
do s=1,60
 X=base; X(1:8,:,1:3)=states(:,:,:,s)
 call ace_tendency(8,nz,2,A(1:8),B(1:8),X,tendency,1)
 write(replay_unit) tendency,T,q,ql,qi
 call precip_sinks(8,nz,X(1:8,:,10),sink(:,:,1),sink(:,:,2))
 call forward_values()
 write(replay_unit) sink,forward
 ! Diagnose forward/sink evaluation on exactly the MATLAB thermodynamic cache.
 shared=thermo(:,:,:,s)
 T=shared(:,:,1); q=shared(:,:,2); ql=shared(:,:,3); qi=shared(:,:,4)
 call precip_sinks(8,nz,X(1:8,:,10),sink(:,:,1),sink(:,:,2))
 call forward_values()
 write(replay_unit) sink,forward
 now=0.
 ! Temporary module instrumentation writes dynamics and pre-damping states.
 call ace_driver(8,nz,2,X,A(1:8),B(1:8),now,4.,4.,forcing)
 write(replay_unit) X(1:8,:,1:3)
enddo
close(replay_unit)
contains
subroutine forward_values()
do k=1,nz
 do i=1,8
  qc=ql(i,k)+qi(i,k); dql=0.; dqi=0.
  if (qc>0.) then
   dql=1.e-8*ql(i,k)/qc; dqi=1.e-8*qi(i,k)/qc
  endif
  forward(i,k,1)=theta_e(T(i,k),q(i,k),ql(i,k),qi(i,k),X(i,k,10))
  forward(i,k,2)=theta_e(T(i,k),q(i,k),ql(i,k)+dql,qi(i,k)+dqi,X(i,k,10))
 enddo
enddo
end subroutine
end program
