program guard
use ace_module, only: ace_initialization
implicit none
character(1024) :: input_file, operator
real :: z(3), ze(4), tv(13)
call get_command_argument(1,input_file)
call get_command_argument(2,operator)
z=[0.,4.,8.]; ze=[0.,4.,8.,12.]; tv=300.
call ace_initialization(2,13,3,z,ze,trim(input_file),tv,netcdf_input=.true., &
  turn_off_DHv_input=trim(operator)/='PMDv',turn_off_DHh_input=trim(operator)/='PMD')
error stop 'Guard failed to reject a disabled placeholder'
end program
