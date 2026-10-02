% Exactly five original liquid-boundary cases plus twenty explicit states.
manifest=jsondecode(fileread('manifest.json'));
addpath(fullfile(manifest.root,'matlab','util_thermodynamics'));
addpath(pwd);
T0=280; p0=90000; qt0=eval_qs(T0,p0);
te0=eval_theta_e(T0,qt0,0,0,p0);
inputs=zeros(25,3); constructed=NaN(25,4); labels=cell(25,1);
deltas=[-1e-4,-1e-8,0,1e-8,1e-4];
for i=1:5
  inputs(i,:)=[te0,qt0*(1+deltas(i)),p0];
  labels{i}=sprintf('original_liquid_qt_delta_%g',deltas(i));
end
constructed(3,:)=[T0,qt0,0,0];
% Columns: T(K), p(hPa), vapor fraction of dry saturation, liquid(kg/kg).
% Saturated liquid construction: q = qs_no_cond*(1-ql).
states=[
 274 1100 0 0;
 288 1100 0.5 0;
 275 1000 0.99999999 0;
 275 1000 1 1e-9;
 285 1000 1 1e-4;
 280 950 0.2 0;
 295 950 1 1e-3;
 274 900 1 1e-8;
 290 850 1 0;
 300 850 1 2e-3;
 278 800 0.999999 0;
 288 800 1 5e-4;
 283 750 0.9 0;
 275 700 1 1e-3;
 285 650 1 1e-4;
 280 600 0.5 0;
 275 550 1 0;
 278 500 1 1e-4;
 274 400 1 1e-7;
 274 300 0.1 0];
for j=1:20
  i=j+5; T=states(j,1); p=100*states(j,2); liquid=states(j,4);
  q=eval_qs(T,p)*(1-liquid)*states(j,3);
  te=eval_theta_e(T,q,liquid,0,p);
  inputs(i,:)=[te,q+liquid,p];
  constructed(i,:)=[T,q,liquid,0];
  labels{i}=sprintf('extra_%02d_T%g_p%g_vapor%g_ql%g',j,T,p/100,states(j,3),liquid);
  assert(eval_es(T)<p,'es>p excluded');
end
assert(all(inputs(:,1)>=200 & inputs(:,1)<=400),'theta_e outside allowed range');
assert(all(inputs(:,2)>=0 & inputs(:,2)<=0.1),'qt outside allowed range');
assert(size(unique(inputs,'rows'),1)==25,'Inputs must be distinct');
matlab=zeros(25,13);
for i=1:25
  % Exclude es>p according to the agreed no-condensate reference trial.
  [~,es]=diagnostic_reference(inputs(i,1),inputs(i,2),inputs(i,3));
  assert(isreal(es) && isfinite(es) && es<inputs(i,3),'Invalid or es>p trial');
  [T,q,ql,qi,b,n1,n2,s,f]=reference_inversion(inputs(i,1),inputs(i,2),inputs(i,3));
  matlab(i,:)=[real([T,q,ql,qi]),imag([T,q,ql,qi]),b,n1,n2,s,f];
  if s==0
    [Ta,qa,qla,qia]=inv_T_from_theta_e(inputs(i,1),inputs(i,2),inputs(i,3));
    assert(isequal([Ta,qa,qla,qia],[T,q,ql,qi]),'Instrumented versus active MATLAB difference');
  end
end
fid=fopen('input.bin','w','ieee-le'); assert(fid>=0);
fwrite(fid,25,'int32'); fwrite(fid,inputs,'double'); fclose(fid);
[exit_status,output]=system('./inversion_probe input.bin fortran.bin');
assert(exit_status==0,output);
fid=fopen('fortran.bin','r','ieee-le'); assert(fid>=0);
fortran=fread(fid,[25,13],'double'); fclose(fid);
assert(isequal(size(fortran),[25,13]));
finite_pair=matlab(:,12)==0 & fortran(:,12)==0;
absolute=abs(fortran(:,1:4)-matlab(:,1:4));
relative=absolute./abs(matlab(:,1:4)); relative(matlab(:,1:4)==0)=NaN;
forward_error_matlab=abs(matlab(:,1:4)-constructed);
forward_error_fortran=abs(fortran(:,1:4)-constructed);
r=struct('labels',{labels},'inputs',inputs,'constructed_T_qv_ql_qi',constructed, ...
 'matlab',matlab,'fortran',fortran,'absolute_difference',absolute, ...
 'relative_difference_nonzero_matlab',relative, ...
 'finite_real_converged_pairs',sum(finite_pair), ...
 'exactly_equal_four_outputs',sum(all(matlab(:,1:4)==fortran(:,1:4),2)), ...
 'branch_mismatches',sum(matlab(:,9)~=fortran(:,9)), ...
 'iteration_mismatches',sum(any(matlab(:,10:11)~=fortran(:,10:11),2)), ...
 'status_mismatches',sum(matlab(:,12)~=fortran(:,12)), ...
 'max_absolute_difference',max(absolute(finite_pair,:),[],1), ...
 'max_relative_difference_nonzero_matlab',max(relative(finite_pair,:),[],1,'omitnan'), ...
 'forward_error_matlab',forward_error_matlab,'forward_error_fortran',forward_error_fortran, ...
 'original_boundary_T_error_K',matlab(3,1)-T0, ...
 'output_columns',{{'T','qv','ql','qi','imag_T','imag_qv','imag_ql','imag_qi','branch','n1','n2','status','initial_failure'}}, ...
 'matlab_version',version,'acceptance_tolerance','None; raw differences reported', ...
 'manifest',manifest);
fid=fopen('results.json','w'); assert(fid>=0); fprintf(fid,'%s',jsonencode(r)); fclose(fid);
fprintf('Cases 25; finite pairs %d; equal outputs %d; branches mismatched %d; iterations mismatched %d\n', ...
 r.finite_real_converged_pairs,r.exactly_equal_four_outputs,r.branch_mismatches,r.iteration_mismatches);
disp(r.max_absolute_difference); disp(r.max_relative_difference_nonzero_matlab);
fprintf('Original boundary T error %.17g K\n',r.original_boundary_T_error_K);
