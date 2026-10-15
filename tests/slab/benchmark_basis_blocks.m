function benchmark_basis_blocks(input_file, report_dir)
% Prototype only: split independent response ACEs, retaining reduction axes.
assert(~isfolder(report_dir),'Use a fresh directory');mkdir(report_dir);
maxNumCompThreads(32);
repo=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repo,'matlab'));
input=read_shared_input(input_file);
P={input.PMB,input.PMDv,input.PMD};clear input
[k,i]=ndgrid(1:size(P{1},2),1:size(P{1},3));
ni=size(P{1},4);nz=size(P{1},1);
reference=cell(3,1);coeff=cell(3,3);baseline=zeros(3,1);
for trial=1:3
    coeff(trial,:)={reshape(sin(k/13+trial/37).*cos(i/7),1,[],ni), ...
        reshape(cos(k/17+trial/41).*sin(i/11),1,[],ni), ...
        reshape(sin(k/19+trial/43).*cos(i/5),1,[],ni)};
    t=tic;reference{trial}=contract(P,coeff(trial,:));baseline(trial)=toc(t);
end
results=struct([]);
for block=[1,4,8,16]
    starts=1:block:ni;
    % Response slices contain no shared reductions; packing copies values only.
    t=tic;packed=cell(numel(starts),3);
    for j=1:numel(starts)
        ids=starts(j):min(ni,starts(j)+block-1);
        for op=1:3;packed{j,op}=P{op}(:,:,:,ids);end
    end
    pack_seconds=toc(t);
    for mode={'slice','packed'}
        times=zeros(3,1);errors=zeros(3,1);
        for trial=1:3
            c=coeff(trial,:);t=tic;out=zeros(nz,ni);
            for j=1:numel(starts)
                ids=starts(j):min(ni,starts(j)+block-1);
                if strcmp(mode{1},'slice')
                    q={P{1}(:,:,:,ids),P{2}(:,:,:,ids),P{3}(:,:,:,ids)};
                else
                    q=packed(j,:);
                end
                out(:,ids)=contract(q,c);
            end
            times(trial)=toc(t);
            errors(trial)=max(abs(out(:)-reference{trial}(:)));
            assert(isequal(out,reference{trial}),'Block contraction changed results');
        end
        r=struct('block',block,'mode',mode{1},'seconds',times, ...
            'max_abs_error',errors,'packing_seconds',pack_seconds);
        results=[results;r]; %#ok<AGROW>
        fprintf('block %d %s: median %.4f s, exact match\n',block,mode{1},median(times));
    end
    clear packed q
end
report=struct('baseline_seconds',baseline,'candidates',results,'threads',32, ...
    'scope','Synthetic nonzero forcings; only response ACEs are partitioned; model unchanged', ...
    'limitation','Background model processes compete for resources; timings include allocation; fixed order');
fid=fopen(fullfile(report_dir,'results.json'),'w');fwrite(fid,jsonencode(report),'char');fclose(fid);
save(fullfile(report_dir,'results.mat'),'report','reference');
end

function result=contract(P,c)
result=squeeze(sum(sum(P{1}.*c{1}+P{2}.*c{2}+P{3}.*c{3},2),3));
end
