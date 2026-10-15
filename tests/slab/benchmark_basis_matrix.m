function benchmark_basis_matrix(input_file,report_dir)
% Test-only BLAS prototype. Reduction order changes; no production acceptance.
assert(~isfolder(report_dir));mkdir(report_dir);maxNumCompThreads(32);
repo=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(fullfile(repo,'matlab'));
input=read_shared_input(input_file);P={input.PMB,input.PMDv,input.PMD};clear input
nz=size(P{1},1);ni=size(P{1},4);ncoarse=size(P{1},2);
t=tic;M=cell(1,3);
for op=1:3
    M{op}=reshape(permute(P{op},[1,4,2,3]),nz*ni,ncoarse*ni);
end
packing=toc(t);[k,i]=ndgrid(1:ncoarse,1:ni);
seconds=zeros(8,2);errors=zeros(8,1);scales=zeros(8,1);
for trial=1:8
    c={reshape(sin(k/13+trial/37).*cos(i/7),1,[],ni), ...
        reshape(cos(k/17+trial/41).*sin(i/11),1,[],ni), ...
        reshape(sin(k/19+trial/43).*cos(i/5),1,[],ni)};
    order=1:2;if mod(trial,2)==0;order=2:-1:1;end
    outputs=cell(1,2);
    for method=order
        t=tic;
        if method==1
            out=squeeze(sum(sum(P{1}.*c{1}+P{2}.*c{2}+P{3}.*c{3},2),3));
        else
            out=reshape(M{1}*c{1}(:)+M{2}*c{2}(:)+M{3}*c{3}(:),nz,ni);
        end
        seconds(trial,method)=toc(t);outputs{method}=out;
    end
    errors(trial)=max(abs(outputs{1}(:)-outputs{2}(:)));
    scales(trial)=max(abs(outputs{1}(:)));
    assert(all(isfinite(outputs{2}(:))));
    fprintf('matrix %d: original %.4f, candidate %.4f s; error %.4g\n',trial,seconds(trial,:),errors(trial));
end
report=struct('seconds',seconds,'max_abs_error',errors,'reference_max_abs',scales, ...
    'packing_seconds',packing,'threads',32,'reduction_order_changed',true, ...
    'scientific_acceptance','pending: synthetic kernel only; trajectory validation required', ...
    'limitations','BLAS sums operators separately; rounding differs. Background CPU/memory competition.');
fid=fopen(fullfile(report_dir,'results.json'),'w');fwrite(fid,jsonencode(report),'char');fclose(fid);
end
