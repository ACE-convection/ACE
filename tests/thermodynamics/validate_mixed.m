% Twenty-five explicit interior, endpoint, low-condensate and near-T0 states.
manifest=jsondecode(fileread('manifest.json'));
addpath(fullfile(manifest.root,'matlab','util_thermodynamics'));addpath(pwd);
T0=273.1636783445389;
% Columns: p(hPa), T-T0(K), condensate(kg/kg), ice fraction.
states=[
 1100 0 1e-4 0.1;
 1100 0 1e-3 0.5;
 1100 0 5e-3 0.9;
 900 0 1e-4 0.1;
 900 0 1e-3 0.5;
 900 0 5e-3 0.9;
 700 0 1e-4 0.1;
 700 0 1e-3 0.5;
 700 0 5e-3 0.9;
 500 0 1e-4 0.1;
 500 0 1e-3 0.5;
 500 0 5e-3 0.9;
 400 0 1e-4 0.1;
 400 0 1e-3 0.5;
 400 0 5e-3 0.9;
 900 0 1e-3 0;
 900 0 1e-3 1;
 700 0 1e-3 0;
 700 0 1e-3 1;
 900 0 1e-9 0.5;
 700 0 1e-8 0.5;
 900 -1e-3 1e-3 1;
 900 -1e-6 1e-3 1;
 900 1e-6 1e-3 0;
 900 1e-3 1e-3 0];
inputs=zeros(25,3);constructed=zeros(25,4);labels=cell(25,1);
for i=1:25
 p=100*states(i,1);T=T0+states(i,2);qc=states(i,3);fraction=states(i,4);
 if states(i,2)==0
  % Solve q=0.5*(qs_liquid+qs_ice) with qt=q+qc, matching mixed branch.
  s=0.5*0.621971830985916*(eval_es(T)/(p-eval_es(T))+eval_esi(T)/(p-eval_esi(T)));
  q=s/(1+s)*(1-qc);
 elseif T<T0
  q=eval_qsi(T,p)*(1-qc);
 else
  q=eval_qs(T,p)*(1-qc);
 end
 ql=qc*(1-fraction);qi=qc*fraction;
 te=eval_theta_e(T,q,ql,qi,p);
 inputs(i,:)=[te,q+qc,p];constructed(i,:)=[T,q,ql,qi];
 labels{i}=sprintf('p%g_deltaT%g_qc%g_icefraction%g',p/100,states(i,2),qc,fraction);
 assert(max(eval_es(T),eval_esi(T))<p);
end
assert(all(inputs(:,1)>=200 & inputs(:,1)<=400),'theta_e outside allowed range');
assert(all(inputs(:,2)>=0 & inputs(:,2)<=0.1));assert(size(unique(inputs,'rows'),1)==25);
matlab=zeros(25,13);
for i=1:25
 fprintf('CASE %d\n',i);
 [~,es]=diagnostic_reference(inputs(i,1),inputs(i,2),inputs(i,3));
 assert(isreal(es) && isfinite(es) && es<inputs(i,3));
 [T,q,ql,qi,b,n1,n2,s,f]=reference_inversion(inputs(i,1),inputs(i,2),inputs(i,3));
 matlab(i,:)=[real([T,q,ql,qi]),imag([T,q,ql,qi]),b,n1,n2,s,f];
 if s==0
  [Ta,qa,qla,qia]=inv_T_from_theta_e(inputs(i,1),inputs(i,2),inputs(i,3));
  assert(isequal([Ta,qa,qla,qia],[T,q,ql,qi]));
 end
end
fid=fopen('input.bin','w','ieee-le');assert(fid>=0);
fwrite(fid,25,'int32');fwrite(fid,inputs,'double');fclose(fid);
[exit_status,output]=system('./inversion_probe input.bin fortran.bin > fortran_phase.log');assert(exit_status==0,output);
fid=fopen('fortran.bin','r','ieee-le');assert(fid>=0);
fortran=fread(fid,[25,13],'double');fclose(fid);assert(isequal(size(fortran),[25,13]));
finite_pair=matlab(:,12)==0 & fortran(:,12)==0;
absolute=abs(fortran(:,1:4)-matlab(:,1:4));
relative=absolute./abs(matlab(:,1:4));relative(matlab(:,1:4)==0)=NaN;
r=struct('labels',{labels},'states_p_hPa_deltaT_qc_icefraction',states, ...
 'inputs',inputs,'constructed_T_qv_ql_qi',constructed,'matlab',matlab,'fortran',fortran, ...
 'absolute_difference',absolute,'relative_difference_nonzero_matlab',relative, ...
 'finite_real_converged_pairs',sum(finite_pair), ...
 'exactly_equal_four_outputs',sum(all(matlab(:,1:4)==fortran(:,1:4),2)), ...
 'branch_mismatches',sum(matlab(:,9)~=fortran(:,9)), ...
 'iteration_mismatches',sum(any(matlab(:,10:11)~=fortran(:,10:11),2)), ...
 'status_mismatches',sum(matlab(:,12)~=fortran(:,12)), ...
 'max_absolute_difference',max(absolute(finite_pair,:),[],1), ...
 'max_relative_difference_nonzero_matlab',max(relative(finite_pair,:),[],1,'omitnan'), ...
 'forward_error_matlab',abs(matlab(:,1:4)-constructed), ...
 'forward_error_fortran',abs(fortran(:,1:4)-constructed), ...
 'water_closure_error_matlab',abs(sum(matlab(:,2:4),2)-inputs(:,2)), ...
 'water_closure_error_fortran',abs(sum(fortran(:,2:4),2)-inputs(:,2)), ...
 'matlab_version',version,'acceptance_tolerance','None; raw differences reported','manifest',manifest);
fid=fopen('results.json','w');assert(fid>=0);fprintf(fid,'%s',jsonencode(r));fclose(fid);
fprintf('25 cases; finite pairs %d; equal outputs %d; branch mismatches %d; iteration mismatches %d\n', ...
 r.finite_real_converged_pairs,r.exactly_equal_four_outputs,r.branch_mismatches,r.iteration_mismatches);
disp(r.max_absolute_difference);disp(r.max_relative_difference_nonzero_matlab);
