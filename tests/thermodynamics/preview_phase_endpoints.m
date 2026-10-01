% Preview ONLY: temporary inverse copies carry the proposed endpoint rule.
manifest=jsondecode(fileread('manifest.json'));
addpath(fullfile(manifest.root,'matlab','active','util_thermodynamics'));addpath(pwd);
fid=fopen('input.bin','r','ieee-le');assert(fid>=0);
n=fread(fid,1,'int32');inputs=fread(fid,[n,3],'double');fclose(fid);
matlab=zeros(n,13);
for i=1:n
 [T,q,ql,qi,b,n1,n2,s,f]=reference_inversion(inputs(i,1),inputs(i,2),inputs(i,3));
 matlab(i,:)=[real([T,q,ql,qi]),imag([T,q,ql,qi]),b,n1,n2,s,f];
end
fid=fopen('fortran.bin','r','ieee-le');assert(fid>=0);
fortran=fread(fid,[n,13],'double');fclose(fid);assert(isequal(size(fortran),[n,13]));
finite=matlab(:,12)==0 & fortran(:,12)==0;
absolute=abs(matlab(:,1:4)-fortran(:,1:4));
relative=absolute./abs(matlab(:,1:4));relative(matlab(:,1:4)==0)=NaN;
r=struct('inputs',inputs,'matlab',matlab,'fortran',fortran,'absolute_difference',absolute, ...
 'relative_difference_nonzero_matlab',relative,'finite_pairs',sum(finite), ...
 'branch_mismatches',sum(matlab(:,9)~=fortran(:,9)), ...
 'iteration_mismatches',sum(any(matlab(:,10:11)~=fortran(:,10:11),2)), ...
 'status_mismatches',sum(matlab(:,12)~=fortran(:,12)), ...
 'max_abs',max(absolute(finite,:),[],1),'max_rel',max(relative(finite,:),[],1,'omitnan'), ...
 'manifest',manifest);
fid=fopen('results.json','w');assert(fid>=0);fprintf(fid,'%s',jsonencode(r));fclose(fid);
fprintf('Preview %d cases; finite %d; branch/iteration/status mismatches %d/%d/%d\n', ...
 n,r.finite_pairs,r.branch_mismatches,r.iteration_mismatches,r.status_mismatches);
disp(r.max_abs);
