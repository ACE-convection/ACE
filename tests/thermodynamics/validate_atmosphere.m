% Reproducible stratified atmospheric validation; no source mutation or sweep.
manifest=jsondecode(fileread('manifest.json'));
addpath(fullfile(manifest.root,'matlab','active','util_thermodynamics'));addpath(pwd);
rng(manifest.seed,'twister');T0=273.1636783445389;
% Paired p(hPa)/T(K) envelopes: surface to upper troposphere/tropopause.
levels=[900 1050 255 310;700 900 245 295;500 700 235 285; ...
        300 500 215 270;150 300 195 240;100 150 195 225];
quotas=[300 250 250 200 200];
category_names={'unsaturated','liquid','ice','mixed_T0','near_boundary'};
inputs=zeros(1200,3);constructed=NaN(1200,4);physical=zeros(1200,4);
category=zeros(1200,1);subtype=cell(1200,1);level_index=zeros(1200,1);
rejections=zeros(5,1);attempts=zeros(5,1);row=0;
deltas=[-1e-6 -1e-8 -1e-12 0 1e-12 1e-8 1e-6];
for group=1:5
 accepted=0;
 while accepted<quotas(group)
  attempts(group)=attempts(group)+1;assert(attempts(group)<=50000,'Generation guard');
  if group==2
   layer=randi(3);
  elseif group==4 || (group==5 && accepted>=100)
   layer=randi(3);
  else
   layer=randi(6);
  end
  p=100*(levels(layer,1)+rand*(levels(layer,2)-levels(layer,1)));
  T=levels(layer,3)+rand*(levels(layer,4)-levels(layer,3));
  qc=0;fraction=0;perturb=false;tag=category_names{group};
  if group==2
   if T<=T0, rejections(group)=rejections(group)+1;continue;end
   qc=10^(-9+rand*(log10(0.003)+9));fraction=0;
  elseif group==3
   if T>=T0, rejections(group)=rejections(group)+1;continue;end
   qc=10^(-9+rand*6);fraction=1;
  elseif group==4
   if T0<levels(layer,3) || T0>levels(layer,4),rejections(group)=rejections(group)+1;continue;end
   T=T0;qc=10^(-9+rand*(log10(0.002)+9));fraction=0.05+0.9*rand;
  elseif group==5 && accepted>=100
   phase_id=mod(accepted-100,5);
   offsets=[0 -1e-6 1e-6 -1e-3 1e-3];T=T0+offsets(phase_id+1);
   qc=10^(-9+rand*6);
   if phase_id==0, fraction=mod(floor((accepted-100)/5),2);
   elseif T<T0, fraction=1;else,fraction=0;end
   tag=sprintf('T0_endpoint_or_offset_%g',T-T0);
  end
  if max(eval_es(T),eval_esi(T))>=p,rejections(group)=rejections(group)+1;continue;end
  if T==T0 && qc>0
   S=0.5*0.621971830985916*(eval_es(T)/(p-eval_es(T))+eval_esi(T)/(p-eval_esi(T)));
   q=S/(1+S)*(1-qc);
  elseif T<T0
   q=eval_qsi(T,p)*(1-qc);
  else
   q=eval_qs(T,p)*(1-qc);
  end
  if group==1
   humidity=0.02+0.96*rand;
   if mod(accepted,25)==0,humidity=0;end
   q=q*humidity;tag=sprintf('unsaturated_vapor_fraction_%g',humidity);
  end
  ql=qc*(1-fraction);qi=qc*fraction;
  te=eval_theta_e(T,q,ql,qi,p);qt=q+qc;
  if group==5 && accepted<100
   delta=deltas(mod(accepted,numel(deltas))+1);
   qt=qt*(1+delta);perturb=(delta~=0);
   tag=sprintf('saturation_qt_delta_%g',delta);
  end
  if ~isreal(te) || ~isfinite(te) || te<200 || te>400 || qt<0 || qt>0.04
   rejections(group)=rejections(group)+1;continue;
  end
  [trialT,trialEs]=diagnostic_reference(te,qt,p);
  if ~isreal(trialT) || ~isfinite(trialT) || ~isreal(trialEs) || ~isfinite(trialEs) || trialEs>p
   rejections(group)=rejections(group)+1;continue;
  end
  row=row+1;accepted=accepted+1;
  inputs(row,:)=[te,qt,p];physical(row,:)=[T,q,ql,qi];category(row)=group;
  subtype{row}=tag;level_index(row)=layer;
  if ~perturb,constructed(row,:)=[T,q,ql,qi];end
 end
end
assert(row==1200 && size(unique(inputs,'rows'),1)==1200);
matlab=zeros(1200,13);direct_matlab_checks=0;
for i=1:1200
 [T,q,ql,qi,b,n1,n2,s,f]=reference_inversion(inputs(i,1),inputs(i,2),inputs(i,3));
 matlab(i,:)=[real([T,q,ql,qi]),imag([T,q,ql,qi]),b,n1,n2,s,f];
 if s==0
  [Ta,qa,qla,qia]=inv_T_from_theta_e(inputs(i,1),inputs(i,2),inputs(i,3));
  assert(isequal([Ta,qa,qla,qia],[T,q,ql,qi]),'Instrumented/active MATLAB difference');
  direct_matlab_checks=direct_matlab_checks+1;
 end
end
fid=fopen('input.bin','w','ieee-le');assert(fid>=0);fwrite(fid,1200,'int32');fwrite(fid,inputs,'double');fclose(fid);
[exit_status,output]=system('./inversion_probe input.bin fortran.bin');assert(exit_status==0,output);
fid=fopen('fortran.bin','r','ieee-le');assert(fid>=0);fortran=fread(fid,[1200,13],'double');fclose(fid);
assert(isequal(size(fortran),[1200,13]));
finite_pair=matlab(:,12)==0 & fortran(:,12)==0;
absolute=abs(fortran(:,1:4)-matlab(:,1:4));
relative=absolute./abs(matlab(:,1:4));relative(matlab(:,1:4)==0)=NaN;
% Uncapped production comparison only for calls already observed to converge.
keep=find(fortran(:,12)==0);prod_inputs=inputs(keep,:);
fid=fopen('production_input.bin','w','ieee-le');assert(fid>=0);
fwrite(fid,numel(keep),'int32');fwrite(fid,prod_inputs,'double');fclose(fid);
[exit_status,output]=system('./production/production_probe production_input.bin production_output.bin');assert(exit_status==0,output);
fid=fopen('production_output.bin','r','ieee-le');assert(fid>=0);
production=fread(fid,[numel(keep),4],'double');fclose(fid);
assert(isequal(production,fortran(keep,1:4)),'Instrumented/active Fortran difference');
branch_mismatch=matlab(:,9)~=fortran(:,9);
iteration_mismatch=any(matlab(:,10:11)~=fortran(:,10:11),2);
status_mismatch=matlab(:,12)~=fortran(:,12);
by_category=cell(5,1);
for g=1:5
 k=category==g;valid=k & finite_pair;
 by_category{g}=struct('name',category_names{g},'cases',sum(k),'finite_pairs',sum(valid), ...
  'exact_outputs',sum(k & all(matlab(:,1:4)==fortran(:,1:4),2)), ...
  'branch_mismatches',sum(k & branch_mismatch),'iteration_mismatches',sum(k & iteration_mismatch), ...
  'status_mismatches',sum(k & status_mismatch),'max_abs',max(absolute(valid,:),[],1));
end
r=struct('case_count',1200,'seed',manifest.seed,'category_names',{category_names}, ...
 'category',category,'subtype',{subtype},'layer',level_index,'layer_envelopes',levels, ...
 'inputs',inputs,'physical_construction_T_qv_ql_qi',physical,'roundtrip_reference',constructed, ...
 'matlab',matlab,'fortran',fortran,'absolute_difference',absolute, ...
 'relative_difference_nonzero_matlab',relative,'category_summaries',{by_category}, ...
 'finite_real_converged_pairs',sum(finite_pair),'exactly_equal_four_outputs',sum(all(matlab(:,1:4)==fortran(:,1:4),2)), ...
 'branch_mismatches',sum(branch_mismatch),'iteration_mismatches',sum(iteration_mismatch),'status_mismatches',sum(status_mismatch), ...
 'decision_mismatch_indices',find(branch_mismatch|iteration_mismatch|status_mismatch), ...
 'max_absolute_difference',max(absolute(finite_pair,:),[],1), ...
 'max_relative_difference_nonzero_matlab',max(relative(finite_pair,:),[],1,'omitnan'), ...
 'water_closure_error_matlab',abs(sum(matlab(:,2:4),2)-inputs(:,2)), ...
 'water_closure_error_fortran',abs(sum(fortran(:,2:4),2)-inputs(:,2)), ...
 'forward_error_matlab',abs(matlab(:,1:4)-constructed),'forward_error_fortran',abs(fortran(:,1:4)-constructed), ...
 'generation_attempts',attempts,'generation_rejections',rejections, ...
 'direct_matlab_checks',direct_matlab_checks,'direct_fortran_checks',numel(keep), ...
 'matlab_version',version,'acceptance_tolerance','None; raw differences reported','manifest',manifest);
fid=fopen('results.json','w');assert(fid>=0);fprintf(fid,'%s',jsonencode(r));fclose(fid);
fprintf('Cases 1200; finite pairs %d; exact outputs %d; branch/iteration/status mismatches %d/%d/%d\n', ...
 r.finite_real_converged_pairs,r.exactly_equal_four_outputs,r.branch_mismatches,r.iteration_mismatches,r.status_mismatches);
disp(r.max_absolute_difference);disp(r.max_relative_difference_nonzero_matlab);
