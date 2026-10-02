function make_liquid_boundary(output_file)
% One targeted saturation input, using the active MATLAB forward reference.
if nargin==0, output_file='liquid_base_input.json'; end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab','util_thermodynamics'));
T=280;
p=90000;
qt=eval_qs(T,p);
theta_e=eval_theta_e(T,qt,0,0,p);
assert(theta_e>=200 && theta_e<=400);
assert(eval_es(T)<p);
fid=fopen(output_file,'w');
assert(fid>=0,'Cannot open output file');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode([theta_e,qt,p]));
end
