function benchmark_basis_packed(input_file, report_dir)
% Paired prototype validation with alternate timing order and unchanged sums.
assert(~isfolder(report_dir));mkdir(report_dir);maxNumCompThreads(32);
repo=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(fullfile(repo,'matlab'));
input=read_shared_input(input_file);P={input.PMB,input.PMDv,input.PMD};clear input
ni=size(P{1},4);nz=size(P{1},1);starts=1:16:ni;packed=cell(numel(starts),3);
t=tic;
for j=1:numel(starts)
    ids=starts(j):min(ni,starts(j)+15);
    for op=1:3;packed{j,op}=P{op}(:,:,:,ids);end
end
pack_seconds=toc(t);
[k,i]=ndgrid(1:size(P{1},2),1:ni);times=zeros(8,2);
for trial=1:8
    c={reshape(sin(k/13+trial/37).*cos(i/7),1,[],ni), ...
        reshape(cos(k/17+trial/41).*sin(i/11),1,[],ni), ...
        reshape(sin(k/19+trial/43).*cos(i/5),1,[],ni)};
    order=1:2;if mod(trial,2)==0;order=2:-1:1;end
    outputs=cell(1,2);
    for method=order
        t=tic;
        if method==1
            out=contract(P,c);
        else
            out=zeros(nz,ni);
            for j=1:numel(starts)
                ids=starts(j):min(ni,starts(j)+15);
                out(:,ids)=contract(packed(j,:),c);
            end
        end
        times(trial,method)=toc(t);outputs{method}=out;
    end
    assert(isequal(outputs{1},outputs{2}),'Changed numerical output');
    fprintf('paired %d: original %.4f, packed %.4f s, exact\n',trial,times(trial,:));
end
r=struct('seconds',times,'columns',{{'original','packed16'}},'block',16, ...
    'packing_seconds',pack_seconds,'all_bitwise_equal',true,'threads',32, ...
    'limitation','Synthetic forcings; alternating order; background models running; allocation/JIT effects included');
fid=fopen(fullfile(report_dir,'results.json'),'w');fwrite(fid,jsonencode(r),'char');fclose(fid);
end
function out=contract(P,c)
out=squeeze(sum(sum(P{1}.*c{1}+P{2}.*c{2}+P{3}.*c{3},2),3));
end
