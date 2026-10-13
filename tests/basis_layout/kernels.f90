module kernels
use iso_fortran_env, only: real64
implicit none
contains
subroutine legacy(p,f,y)
real(real64),intent(in) :: p(:,:,:,:),f(:,:)
real(real64),intent(out) :: y(:,:)
integer :: i,k
do i=1,size(y,1)
  do k=1,size(y,2)
    y(i,k)=sum(sum(p(i,:,:,k)*f,2),1)
  enddo
enddo
end subroutine

! Preserve the vertical-then-forcing-ACE grouping while streaming output i.
subroutine streamed(p,f,y)
real(real64),intent(in) :: p(:,:,:,:),f(:,:)
real(real64),intent(out) :: y(:,:)
real(real64) :: partial(size(y,1))
integer :: i,j,l,k
y=0
do k=1,size(y,2)
  do j=1,size(f,1)
    partial=0
    do l=1,size(f,2)
      do i=1,size(y,1)
        partial(i)=partial(i)+p(i,j,l,k)*f(j,l)
      enddo
    enddo
    y(:,k)=y(:,k)+partial
  enddo
enddo
end subroutine

! q(vertical source, forcing ACE, edge response, response ACE).
subroutine grouped(q,f,y)
real(real64),intent(in) :: q(:,:,:,:),f(:,:)
real(real64),intent(out) :: y(:,:)
real(real64) :: partial
integer :: i,j,l,k
do i=1,size(y,1)
  do k=1,size(y,2)
    y(i,k)=0
    do j=1,size(f,1)
      partial=0
      do l=1,size(f,2)
        partial=partial+q(l,j,k,i)*f(j,l)
      enddo
      y(i,k)=y(i,k)+partial
    enddo
  enddo
enddo
end subroutine

! Each thread owns an entire independent output column and its local partial.
subroutine grouped_omp(q,f,y)
real(real64),intent(in) :: q(:,:,:,:),f(:,:)
real(real64),intent(out) :: y(:,:)
real(real64) :: partial,value
integer :: i,j,l,k
!$omp parallel do collapse(2) default(none) shared(q,f,y) private(i,k,j,l,partial,value) schedule(static)
do i=1,size(y,1)
  do k=1,size(y,2)
    value=0
    do j=1,size(f,1)
      partial=0
      do l=1,size(f,2)
        partial=partial+q(l,j,k,i)*f(j,l)
      enddo
      value=value+partial
    enddo
    y(i,k)=value
  enddo
enddo
!$omp end parallel do
end subroutine

subroutine dot_columns(matrix,source,y)
real(real64),intent(in) :: matrix(:,:),source(:)
real(real64),intent(out) :: y(:,:)
integer :: i,k,col
do i=1,size(y,1)
  do k=1,size(y,2)
    col=(i-1)*size(y,2)+k
    y(i,k)=dot_product(matrix(:,col),source)
  enddo
enddo
end subroutine

subroutine blas_columns(matrix,source,y)
real(real64),intent(in),contiguous :: matrix(:,:),source(:)
real(real64),intent(out) :: y(:,:)
real(real64) :: output(size(y))
integer :: outputs
interface
  subroutine dgemv(trans,m,n,alpha,a,lda,x,incx,beta,y,incy)
    import real64
    character,intent(in) :: trans
    integer,intent(in) :: m,n,lda,incx,incy
    real(real64),intent(in) :: alpha,beta,a(lda,*),x(*)
    real(real64),intent(inout) :: y(*)
  end subroutine
end interface
outputs=size(y)
call dgemv('T',size(matrix,1),outputs,1._real64,matrix,size(matrix,1),source,1,0._real64,output,1)
y=transpose(reshape(output,[size(y,2),size(y,1)]))
end subroutine
end module
