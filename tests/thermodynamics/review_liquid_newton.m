function review_liquid_newton(output_file)
% Diagnose one liquid boundary; hypothetical derivative changes are test-only.
if nargin==0, output_file='liquid_newton_review.json'; end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab','active','util_thermodynamics'));
Tref=280; p=90000;
qt=eval_qs(Tref,p);
te=eval_theta_e(Tref,qt,0,0,p);
CPL=1005.7+3184.3*qt;
RE=287.04*(1-qt);
chi=RE/CPL;
G0=te*(p*RE/1e5)^chi;
G=@(T) T*(RE+461.5*eval_qs(T,p,qt))^chi*exp(eval_qs(T,p,qt)*lv(T)/T/CPL);
D=@(T,c) G(T)*(1/T+((461.5*RE/(RE+461.5*eval_qs(T,p,qt))+lv(T)/T)*eval_dTqs(T,p,qt)-c*eval_qs(T,p,qt)/T^2)/CPL);
old_coefficient=1867292;
correct_coefficient=2501000+2320*273.15;
LOG=log(p*qt)-5.939876353793538;
Tinitial=237.3*LOG/(17.27-LOG)+273.15;
steps=[0.1;0.01;0.001;0.0001];
finite_difference=zeros(numel(steps),3);
for i=1:numel(steps)
  h=steps(i);
  fd=(G(Tref+h)-G(Tref-h))/(2*h);
  finite_difference(i,:)=[h,fd,abs(fd-D(Tref,correct_coefficient))/abs(D(Tref,correct_coefficient))];
end
[current,final_current]=trace(Tinitial,G,G0,D,old_coefficient);
[hypothetical,final_hypothetical]=trace(Tinitial,G,G0,D,correct_coefficient);
% Test-only extra iterations after the original stopping decision.
continuation=zeros(4,5); T=final_current;
for i=1:4
  residual=G(T)-G0; derivative=D(T,old_coefficient);
  dT=-residual/derivative;
  continuation(i,:)=[T,residual,derivative,dT,T+dT];
  T=T+dT;
end
[Tactual,qactual,qlactual,qiactual]=inv_T_from_theta_e(te,qt,p);
assert(Tactual==final_hypothetical,'Analytic trace differs from corrected active production output');
r=struct('input',[te,qt,p],'forward_temperature_K',Tref, ...
 'original_coefficient',old_coefficient,'analytic_coefficient',correct_coefficient, ...
 'current_derivative_at_280',D(Tref,old_coefficient), ...
 'analytic_derivative_at_280',D(Tref,correct_coefficient), ...
 'relative_derivative_error_at_280',(D(Tref,old_coefficient)-D(Tref,correct_coefficient))/D(Tref,correct_coefficient), ...
 'finite_difference_columns',{{'h_K','dGdT','relative_difference_from_analytic'}}, ...
 'finite_difference',finite_difference, ...
 'trace_columns',{{'T_before','G_minus_G0','derivative','dT','T_after'}}, ...
 'current_trace',current,'current_extra_iterations_test_only',continuation, ...
 'hypothetical_correct_derivative_trace',hypothetical, ...
 'active_output',[Tactual,qactual,qlactual,qiactual], ...
 'current_T_error_K',final_current-Tref, ...
 'hypothetical_T_error_K',final_hypothetical-Tref, ...
 'G_residual_at_280',G(Tref)-G0, ...
 'G_residual_at_current_final',G(final_current)-G0, ...
 'G_residual_at_hypothetical_final',G(final_hypothetical)-G0, ...
 'existing_Newton_stop_K',1e-3,'active_derivative_coefficient',correct_coefficient,'production_modified_by_diagnostic',false);
fid=fopen(output_file,'w'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(r));
fprintf('Pre-fix derivative %.17g; analytic %.17g; relative error %.17g\n',r.current_derivative_at_280,r.analytic_derivative_at_280,r.relative_derivative_error_at_280);
fprintf('Pre-fix T error %.17g K; hypothetical T error %.17g K\n',r.current_T_error_K,r.hypothetical_T_error_K);
disp(current); disp(hypothetical); disp(finite_difference);
end

function [history,T]=trace(T,G,G0,D,coefficient)
history=zeros(0,5); dT=9999;
while abs(dT)>1e-3
  assert(size(history,1)<20,'Test-only iteration guard reached');
  residual=G(T)-G0; derivative=D(T,coefficient);
  dT=-residual/derivative;
  history(end+1,:)=[T,residual,derivative,dT,T+dT];
  T=T+dT;
end
end
