function run_benchmark
here=fileparts(mfilename('fullpath'));repo=fileparts(fileparts(here));
addpath(here,fullfile(repo,'matlab'));maxNumCompThreads(32);
outdir=fullfile(here,'results');assert(~isfolder(outdir));mkdir(outdir);
input_file=fullfile(repo,'data/input/goamazon314_88aces.nc');
t=tic;input=read_shared_input(input_file);load_seconds=toc(t);
P={input.PMB,input.PMDv,input.PMD};clear input
files=dir(fullfile(here,'capture','args_*.mat'));assert(numel(files)==9);
samples=cell(9,1);for k=1:9;samples{k}=load(fullfile(files(k).folder,files(k).name));end
s=samples{5};assert(s.coarse_z==2 && s.Ni==88);
original=@(x) Original(x.rho0B,x.F,x.dz2FH,x.DHh,x.Z,x.zm,x.coarse_z,x.Ni,P{1},P{2},P{3},x.Ai,x.zero_ref_buoyancy);
% Fixed matrix rows are (edge,response); columns are (operator,coarse,forcing).
t=tic;nr=numel(s.Z)*s.Ni;nc=size(P{1},2)*s.Ni;
fixed.matrix=zeros(nr,3*nc);
for op=1:3
    fixed.matrix(:,op:3:end)=reshape(permute(P{op},[1,4,2,3]),nr,nc);
end
fixed.area_weights=s.Ai'/sum(s.Ai);precompute_seconds=toc(t);
methods={original,@(x) Vectorized(x,P),@(x) LoopBased(x,P),@(x) Precomputed(x,fixed)};
names={'Original','Vectorized','Loop-based','Precomputed'};
% Error screening selected before observing results; not scientific acceptance.
absolute_limit=1e-9;relative_limit=1e-10;
max_error=zeros(1,4);relative_l2=zeros(1,4);passed=true(1,4);
for k=1:9
    reference=original(samples{k});
    for m=1:4
        result=methods{m}(samples{k});delta=result-reference;
        ae=max(abs(delta(:)));re=norm(delta(:))/max(norm(reference(:)),realmin);
        max_error(m)=max(max_error(m),ae);relative_l2(m)=max(relative_l2(m),re);
        passed(m)=passed(m) && all(isfinite(result(:))) && ae<=absolute_limit && re<=relative_limit;
    end
    fprintf('Validated captured stage %d/9\n',k);
end
seconds=zeros(3,4);
for round=1:3
    order=1:4;if mod(round,2)==0;order=4:-1:1;end
    for m=order
        f=@() methods{m}(s);seconds(round,m)=timeit(f);
        fprintf('timeit round %d %s %.3f ms\n',round,names{m},1000*seconds(round,m));
    end
    checkpoint=struct('names',{names},'seconds',seconds,'max_abs_error',max_error,'relative_l2',relative_l2);
    write_json(fullfile(outdir,'checkpoint.json'),checkpoint);
end
% Profile actual Original with 9 captured SSPRK stages, outside timeit timing.
profile clear;profile on;
for k=1:9;original(samples{k});end
profile off;profile_data=profile('info');save(fullfile(outdir,'profile.mat'),'profile_data');
write_json(fullfile(outdir,'profile.json'),profile_data.FunctionTable);
% Component timeit values include requested output to avoid discarded work.
rho=s.rho0B;if s.zero_ref_buoyancy;rho=rho-sum(rho.*fixed.area_weights,2);end
raw=rho(1:end-1,:)+s.F(1:end-1,:);
reshaped=reshape(raw,s.coarse_z,[],s.Ni);b=mean(reshaped);
v=mean(reshape(s.dz2FH,s.coarse_z,[],s.Ni));h=mean(reshape(s.DHh(1:end-1,:),s.coarse_z,[],s.Ni));
components.reshape=timeit(@() reshape(raw,s.coarse_z,[],s.Ni));
components.mean=timeit(@() mean(reshaped));
components.multiply_B=timeit(@() P{1}.*b);
components.multiply_v=timeit(@() P{2}.*v);
components.multiply_h=timeit(@() P{3}.*h);
terms=P{1}.*b+P{2}.*v+P{3}.*h;
components.sum_vertical=timeit(@() sum(terms,2));
vertical=sum(terms,2);components.sum_forcing=timeit(@() sum(vertical,3));
edge=squeeze(sum(vertical,3));components.interp1_makima=timeit(@() interp1(s.Z,edge,s.zm,'makima'));
med=median(seconds,1);speed=med(1)./med;
report=struct('names',{names},'seconds',seconds,'median_ms',med*1000,'speedup',speed, ...
    'max_abs_error',max_error,'relative_l2',relative_l2,'numeric_screen_passed',passed, ...
    'screen_abs_limit',absolute_limit,'screen_relative_limit',relative_limit, ...
    'basis_shape',size(P{1}),'coarse_z',s.coarse_z,'threads',maxNumCompThreads, ...
    'captured_input','actual native t=600 s state replay, all nine SSPRK stages; timing uses stage 5', ...
    'input_shape',struct('rho0B',size(s.rho0B),'F',size(s.F),'dz2FH',size(s.dz2FH),'DHh',size(s.DHh)), ...
    'components_seconds',components,'load_seconds',load_seconds,'precompute_seconds',precompute_seconds, ...
    'precomputed_matrix_bytes',numel(fixed.matrix)*8,'zero_ref_buoyancy',s.zero_ref_buoyancy, ...
    'limitations','timeit includes kernel temporaries/makima; excludes loading/packing; background validation may compete; changed reductions need trajectory review');
write_json(fullfile(outdir,'results.json'),report);
save(fullfile(outdir,'results.mat'),'report');
disp(table(string(names'),med'*1000,speed',max_error',relative_l2', ...
    'VariableNames',{'Version','Milliseconds','Speedup','MaxError','RelativeL2'}));
end
function write_json(path,value)
fid=fopen(path,'w');assert(fid>0);fwrite(fid,jsonencode(value),'char');fclose(fid);
end
