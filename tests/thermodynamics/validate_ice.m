% Exactly 25 fixed cases and an independent ice-derivative check.
manifest=jsondecode(fileread('manifest.json'));
addpath(fullfile(manifest.root,'matlab','active','util_thermodynamics'));
addpath(pwd);
inputs=zeros(25,3); constructed=NaN(25,4); labels=cell(25,1);
deltas=[-1e-4,-1e-8,0,1e-8,1e-4];
for i=1:5
 inputs(i,:)=[282.02296733261414,3.3710674483252453e-6*(1+deltas(i)),30000];
 labels{i}=sprintf('original_ice_qt_delta_%g',deltas(i));
end
constructed(3,:)=[200,3.3710674483252453e-6,0,0];
% T(K), p(hPa), vapor fraction of dry ice saturation, ice(kg/kg).
states=[
 210 1100 0 0;
 220 900 0.5 0;
 230 800 0.99999999 0;
 240 700 1 1e-9;
 250 600 1 1e-4;
 260 500 0.2 0;
 265 600 1 1e-3;
 270 700 1 1e-8;
 250 400 1 0;
 260 500 1 2e-3;
 230 250 0.999999 0;
 240 300 1 5e-4;
 220 200 0.9 0;
 210 150 1 1e-3;
 200 100 1 1e-4;
 240 400 0.5 0;
 250 500 1 0;
 260 700 1 1e-4;
 270 900 1 1e-7;
 200 300 0.1 0];
for j=1:20
 i=j+5;T=states(j,1);p=100*states(j,2);ice=states(j,4);
 q=eval_qsi(T,p)*(1-ice)*states(j,3);
 te=eval_theta_e(T,q,0,ice,p);
 inputs(i,:)=[te,q+ice,p];constructed(i,:)=[T,q,0,ice];
 labels{i}=sprintf('extra_%02d_T%g_p%g_vapor%g_qi%g',j,T,p/100,states(j,3),ice);
 assert(eval_esi(T)<p);
end
assert(all(inputs(:,1)>=200 & inputs(:,1)<=400),'theta_e outside allowed range');
assert(all(inputs(:,2)>=0 & inputs(:,2)<=0.1));
assert(size(unique(inputs,'rows'),1)==25);
matlab=zeros(25,13);
for i=1:25
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
[exit_status,output]=system('./inversion_probe input.bin fortran.bin');assert(exit_status==0,output);
fid=fopen('fortran.bin','r','ieee-le');assert(fid>=0);
fortran=fread(fid,[25,13],'double');fclose(fid);assert(isequal(size(fortran),[25,13]));
finite_pair=matlab(:,12)==0 & fortran(:,12)==0;
absolute=abs(fortran(:,1:4)-matlab(:,1:4));
relative=absolute./abs(matlab(:,1:4));relative(matlab(:,1:4)==0)=NaN;
% Analytic H derivative, compared with finite differences for a condensate state.
Tcheck=250;pcheck=60000;icheck=1e-4;
qcheck=eval_qsi(Tcheck,pcheck)*(1-icheck);qt=qcheck+icheck;
CPL=1005.7+3184.3*qt;RE=287.04*(1-qt);chi=RE/CPL;
T0=273.1636783445389;dC=2083.900148084866;Lf=333700;
H=@(T) T*(RE+461.5*eval_qsi(T,pcheck,qt))^chi ...
 *(T0/T)^(dC*(qt-eval_qsi(T,pcheck,qt))/CPL) ...
 *exp((eval_qsi(T,pcheck,qt)*(lv(T)/T)-Lf/T0*(qt-eval_qsi(T,pcheck,qt)))/CPL);
D=@(T,A) H(T)*(1/T+((461.5*RE/(RE+461.5*eval_qsi(T,pcheck,qt))+lv(T)/T ...
 +dC*log(T/T0)+Lf/T0)*eval_dTqsi(T,pcheck,qt) ...
 -((A/T-dC)*eval_qsi(T,pcheck,qt)+dC*qt)/T)/CPL);
h=[0.1;0.01;0.001;0.0001];fd=zeros(4,3);
for i=1:4
 derivative=(H(Tcheck+h(i))-H(Tcheck-h(i)))/(2*h(i));
 fd(i,:)=[h(i),derivative,abs(derivative-D(Tcheck,3134708))/abs(D(Tcheck,3134708))];
end
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
 'forward_error_matlab',abs(matlab(:,1:4)-constructed), ...
 'forward_error_fortran',abs(fortran(:,1:4)-constructed), ...
 'derivative_check_state',[Tcheck,qt,pcheck], ...
 'old_derivative',D(Tcheck,1867292),'analytic_derivative',D(Tcheck,3134708), ...
 'finite_difference_columns',{{'h_K','dHdT','relative_difference_from_analytic'}}, ...
 'finite_difference',fd, ...
 'output_columns',{{'T','qv','ql','qi','imag_T','imag_qv','imag_ql','imag_qi','branch','n1','n2','status','initial_failure'}}, ...
 'matlab_version',version,'acceptance_tolerance','None; raw differences reported','manifest',manifest);
fid=fopen('results.json','w');assert(fid>=0);fprintf(fid,'%s',jsonencode(r));fclose(fid);
fprintf('25 cases; finite pairs %d; equal outputs %d; branch mismatches %d; iteration mismatches %d\n', ...
 r.finite_real_converged_pairs,r.exactly_equal_four_outputs,r.branch_mismatches,r.iteration_mismatches);
disp(r.max_absolute_difference);disp(r.max_relative_difference_nonzero_matlab);disp(fd);
