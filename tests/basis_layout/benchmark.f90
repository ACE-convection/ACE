program benchmark
use kernels
use ace_input,only:read_case_metadata,read_case_basis
use iso_fortran_env,only:real64,int64
use omp_lib
implicit none
real(real64),allocatable :: p(:,:,:,:),f(:,:),source(:),y(:,:),reference(:,:),bound(:,:)
real(real64),allocatable,target :: q(:,:,:,:)
real(real64),pointer,contiguous :: matrix(:,:)
integer :: nc,nz,nb,ne,u,i,j,l,k,kind,mode,method,rep,repeats,nout,header(2),threads,first_method
integer(int64) :: tick,rate,finish
real(real64) :: elapsed,pack_time,absolute_error,scaled_error
character(1024) :: input_file,forcing_file,outdir,arg,filename
character(64) :: geometry
character(20),parameter :: names(6)=[character(20)::'legacy','streamed','packed_grouped','packed_dot','packed_blas','packed_openmp']
call get_command_argument(1,input_file);call get_command_argument(2,forcing_file)
call get_command_argument(3,outdir);call get_command_argument(4,arg);read(arg,*) repeats
call get_command_argument(5,arg);read(arg,*) threads
first_method=1
call get_command_argument(6,arg)
if (trim(arg)=='omp-only') first_method=6
call omp_set_num_threads(threads)
call read_case_metadata(trim(input_file),nz,nc,nb,geometry);ne=nb+1
allocate(p(nc,nc,nb,ne),f(nc,nb),source(nc*nb),q(nb,nc,ne,nc))
call system_clock(tick,rate)
call read_case_basis(trim(input_file),'PMB',p)
call system_clock(finish)
write(*,'(a,es20.11)') 'basis_read_seconds,',real(finish-tick,real64)/rate
call system_clock(tick)
do i=1,nc
  do k=1,ne
    q(:,:,k,i)=transpose(p(i,:,:,k))
  enddo
enddo
call system_clock(finish);pack_time=real(finish-tick,real64)/rate
write(*,'(a,es20.11)') 'packing_seconds,',pack_time
matrix(1:nb*nc,1:ne*nc)=>q
open(newunit=u,file=trim(forcing_file),access='stream',form='unformatted',status='old')
read(u) header
if (any(header/=[nc,nb])) error stop 'Forcing header mismatch'
read(u) f;close(u)
do kind=1,2
  if (kind==2) then
    filename=trim(outdir)//'/../forcing_stress.bin'
    open(newunit=u,file=trim(filename),access='stream',form='unformatted',status='old')
    read(u) header
    if (any(header/=[nc,nb])) error stop 'Stress forcing header mismatch'
    read(u) f;close(u)
  endif
  source=reshape(transpose(f),[nc*nb])
  do mode=1,2
    nout=nc
    if (mode==2) nout=1
    allocate(y(nout,ne),reference(nout,ne),bound(nout,ne))
    call legacy(p,f,reference)
    do k=1,ne
      do i=1,nout
        bound(i,k)=max(tiny(1._real64),128*epsilon(1._real64)*sum(abs(p(i,:,:,k)*f)))
      enddo
    enddo
    write(filename,'(a,a,i0,a,i0,a)') trim(outdir),'/case',kind,'_responses',nout,'_bound.bin'
    open(newunit=u,file=trim(filename),access='stream',form='unformatted',status='new')
    write(u) bound;close(u)
    do method=first_method,6
      ! Warmup plus repeated wall-clock timings. Write results to prevent dead work.
      do rep=0,repeats
        call system_clock(tick)
        select case(method)
        case(1);call legacy(p,f,y)
        case(2);call streamed(p,f,y)
        case(3);call grouped(q,f,y)
        case(4);call dot_columns(matrix,source,y)
        case(5);call blas_columns(matrix,source,y)
        case(6);call grouped_omp(q,f,y)
        end select
        call system_clock(finish);elapsed=real(finish-tick,real64)/rate
        absolute_error=maxval(abs(y-reference));scaled_error=maxval(abs(y-reference)/bound)
        if (.not.all(abs(y-reference)<=bound)) error stop 'Kernel exceeds roundoff bound'
        if (rep>0) write(*,'(a,5(a,i0),3(a,es20.11),a,l1)') trim(names(method)), &
          ',kind=',kind,',responses=',nout,',threads=',threads,',rep=',rep,',method=',method, &
          ',seconds=',elapsed,',max_abs_error=',absolute_error,',scaled_error=',scaled_error, &
          ',exact=',all(y==reference)
      enddo
      write(filename,'(a,a,i0,a,i0,a,a,a)') trim(outdir),'/case',kind,'_responses',nout,'_',trim(names(method)),'.bin'
      open(newunit=u,file=trim(filename),access='stream',form='unformatted',status='new')
      write(u) y;close(u)
    enddo
    deallocate(y,reference,bound)
  enddo
enddo
end program
