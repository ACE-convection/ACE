program components
use ace_module
use ace_input
implicit none
integer :: nc,nz,nb,i,k,u,n
real, allocatable :: profile(:,:),widths(:),cz(:),ce(:),area(:),perimeter(:),reference(:), &
                    ref(:,:),x(:,:,:),tendency(:,:,:),forcing(:,:),inputs(:,:),outputs(:,:)
real :: lx,ly,dz,temperature,vapor,liquid,ice,now,finish
real :: cases(8,5),sinks(1,8,2)
character(1024) :: input_file,work
character(64) :: geometry
call get_command_argument(1,input_file)
call get_command_argument(2,work)
call read_case_metadata(trim(input_file),nz,nc,nb,geometry)
allocate(profile(nz,12),widths(7),cz(nb),ce(nb+1),area(nc),perimeter(nc),reference(nz), &
         ref(nz,8),x(nc+1,nz,3),tendency(nc,nz,3),forcing(nc,nz))
call read_case_profile(trim(input_file),profile,widths,lx,ly,dz,cz,ce)
call read_case_geometry(trim(input_file),area,perimeter)
do k=1,nz
  ref(k,:)=[profile(k,11),profile(k,5),profile(k,12),profile(k,6),dz,dz,profile(k,10), &
            (profile(k,10)/1.e5)**(287.04/1005.7)]
  call inv_theta_e(profile(k,7),profile(k,8),profile(k,10),temperature,vapor,liquid,ice)
  reference(k)=temperature*(1.+0.607789855072462*vapor-liquid-ice)
enddo
call ace_initialization(nc,nz,nb,cz,ce,trim(input_file),reference,netcdf_input=.true.)
x=0.
x(nc+1,:,2)=profile(:,7);x(nc+1,:,3)=profile(:,8)
open(newunit=u,file=trim(work)//'/matlab_transport.bin',access='stream',form='unformatted',status='old')
read(u) x(1:nc,:,:)
close(u)
call ace_tendency(nc,nz,2,3,6.,area,perimeter,x,ref,tendency,1)
open(newunit=u,file=trim(work)//'/fortran_transport.bin',access='stream',form='unformatted',status='new')
write(u) x(1:nc,:,:),tendency
forcing=0.; now=0.; finish=6.
call ace_driver(nc,nz,2,3,x,ref,area,perimeter,now,finish,6.,forcing,precipitation_input=.false.)
write(u) x(1:nc,:,:)
close(u)
open(newunit=u,file=trim(work)//'/thermo_input.bin',access='stream',form='unformatted',status='old')
read(u) n
allocate(inputs(n,3),outputs(n,4))
read(u) inputs
close(u)
do i=1,n
  call inv_theta_e(inputs(i,1),inputs(i,2),inputs(i,3),outputs(i,1),outputs(i,2),outputs(i,3),outputs(i,4))
enddo
open(newunit=u,file=trim(work)//'/fortran_thermo.bin',access='stream',form='unformatted',status='new')
write(u) outputs
close(u)
open(newunit=u,file=trim(work)//'/precip_input.bin',access='stream',form='unformatted',status='old')
read(u) cases
close(u)
call set_probe_thermodynamics(cases(:,1),cases(:,2),cases(:,3),cases(:,4))
call precip_sinks(1,8,3,cases(:,5),sinks)
open(newunit=u,file=trim(work)//'/fortran_precip.bin',access='stream',form='unformatted',status='new')
write(u) sinks
close(u)
end program
