function benchmark_basis(input_file, report_dir, threads)
% Isolated fixture; optional thread override applies only to this benchmark.
assert(~isfolder(report_dir),'Use a fresh report directory');
mkdir(report_dir);
policy='inherited unchanged; no thread-control setter calls';
if nargin==3
    maxNumCompThreads(threads);
    policy=sprintf('isolated benchmark override: %d threads',threads);
end
reported_threads=maxNumCompThreads;
repo=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repo,'matlab'));
input=read_shared_input(input_file);
PMB=input.PMB; PMDv=input.PMDv; PMD=input.PMD;
clear input
nz=size(PMB,2); ni=size(PMB,3);
% Nonzero synthetic coarse forcings exercise every operator. Not a trajectory.
[k,i]=ndgrid(1:nz,1:ni);
b=reshape(sin(k/13).*cos(i/7),1,nz,ni);
v=reshape(cos(k/17).*sin(i/11),1,nz,ni);
h=reshape(sin(k/19).*cos(i/5),1,nz,ni);
labels={'compound','multiply_B','multiply_v','multiply_h', ...
        'add_B_v','add_h','sum_vertical','sum_forcing'};
timings=zeros(3,numel(labels)); errors=zeros(3,1);
for trial=1:3
    % Vary operands outside timers to avoid timing invariant products alone.
    b=reshape(sin(k/13+trial/37).*cos(i/7),1,nz,ni);
    v=reshape(cos(k/17+trial/41).*sin(i/11),1,nz,ni);
    h=reshape(sin(k/19+trial/43).*cos(i/5),1,nz,ni);
    t=tic;
    reference=squeeze(sum(sum(PMB.*b+PMDv.*v+PMD.*h,2),3));
    timings(trial,1)=toc(t);
    t=tic; B=PMB.*b; timings(trial,2)=toc(t);
    t=tic; V=PMDv.*v; timings(trial,3)=toc(t);
    t=tic; H=PMD.*h; timings(trial,4)=toc(t);
    t=tic; S=B+V; timings(trial,5)=toc(t); clear B V
    t=tic; S=S+H; timings(trial,6)=toc(t); clear H
    t=tic; R=sum(S,2); timings(trial,7)=toc(t); clear S
    t=tic; result=squeeze(sum(R,3)); timings(trial,8)=toc(t); clear R
    errors(trial)=max(abs(reference(:)-result(:)));
    assert(isequal(reference,result),'Split expression changed results');
    fid=fopen(fullfile(report_dir,sprintf('result_%d.bin',trial)),'w');assert(fid>0);
    fwrite(fid,result,'double');fclose(fid);
    fprintf('Trial %d: compound %.4f s; split %.4f s; exact match\n', ...
        trial,timings(trial,1),sum(timings(trial,2:end)));
end
report=struct('fixture','nonzero synthetic coarse forcing; no integration', ...
    'thread_policy',policy,'reported_threads',reported_threads, ...
    'operator_shape',size(PMB),'operator_bytes',numel(PMB)*8, ...
    'labels',{labels},'seconds',timings,'max_abs_error',errors, ...
    'limitations','Split intermediates change allocation/JIT behavior; timings do not isolate NUMA or synchronization. First trial may include warmup.');
fid=fopen(fullfile(report_dir,'results.json'),'w');assert(fid>0);
fwrite(fid,jsonencode(report),'char');fclose(fid);
save(fullfile(report_dir,'results.mat'),'report','reference','result');
end
