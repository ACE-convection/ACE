function reference(work,input_file,repeats)
% Same reduction as KHN26, with disabled PMDv/PMD omitted as exact zero terms.
fid=fopen(fullfile(work,'forcing.bin'),'r','ieee-le');
header=fread(fid,2,'int32');nc=header(1);nb=header(2);
actual=fread(fid,[nc,nb],'double');fclose(fid);
read_timer=tic;P=ncread(input_file,'PMB');read_seconds=toc(read_timer);
ne=nb+1;assert(isequal(size(P),[ne,nb,nc,nc]));
pack_timer=tic;matrix=reshape(permute(P,[2,3,1,4]),[nb*nc,ne*nc]);packing_seconds=toc(pack_timer);
report=struct('matlab_version',version,'basis_read_seconds',read_seconds,...
    'packing_seconds',packing_seconds,'max_threads_setting',maxNumCompThreads,'cases',[]);
for kind=1:2
    if kind==1
        F=actual;
    else
        fid=fopen(fullfile(work,'forcing_stress.bin'),'r','ieee-le');
        stress_header=fread(fid,2,'int32');assert(isequal(stress_header,[nc;nb]));
        F=fread(fid,[nc,nb],'double');fclose(fid);
    end
    source=reshape(F.',[],1);
    for responses=[nc,1]
        for method={'original','matrix'}
            times=zeros(1,repeats);
            for rep=0:repeats
                timer=tic;
                if strcmp(method{1},'original')
                    Y=reshape(sum(sum(P(:,:,:,1:responses).*reshape(F.',[1,nb,nc]),2),3),[ne,responses]).';
                else
                    Y=reshape(matrix(:,1:ne*responses).'*source,[ne,responses]).';
                end
                elapsed=toc(timer);
                if rep>0,times(rep)=elapsed;end
            end
            assert(all(isfinite(Y),'all'));
            name=sprintf('matlab_case%d_responses%d_%s.bin',kind,responses,method{1});
            fid=fopen(fullfile(work,name),'w','ieee-le');fwrite(fid,Y,'double');fclose(fid);
            entry=struct('kind',kind,'responses',responses,'method',method{1},'seconds',times);
            report.cases=[report.cases,entry];
        end
    end
end
fid=fopen(fullfile(work,'matlab_results.json'),'w');fprintf(fid,'%s\n',jsonencode(report));fclose(fid);
end
